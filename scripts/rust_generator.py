# --------------------------------------------------------------------------------------------------
# Custom hdl-registers code generator that emits a Rust module for register access.
#
# It produces, for a register list:
#   * Per-register `*_INDEX`, `*_ADDR`, `*_DEFAULT_VALUE` constants.
#   * Per-field `*_SHIFT`, `*_WIDTH`, `*_MASK`, `*_DEFAULT_VALUE` constants.
#   * A native `Value` struct per register holding the decoded field values.
#   * A thin accessor struct (`CanFdFi`-like) over a raw `*mut u32` base pointer that uses
#     volatile reads/writes. The application is responsible for memory-mapping the IP core
#     base address (e.g. via /dev/mem or UIO) and passing the base pointer.
#
# Modelled on the bundled C header generator
# (hdl_registers/generator/c/header.py) and C++ implementation generator.
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from hdl_registers.field.bit import Bit
from hdl_registers.field.bit_vector import BitVector
from hdl_registers.field.enumeration import Enumeration
from hdl_registers.field.integer import Integer
from hdl_registers.generator.register_code_generator import RegisterCodeGenerator
from hdl_registers.register import Register

if TYPE_CHECKING:
    from pathlib import Path

    from hdl_registers.field.register_field import RegisterField
    from hdl_registers.register_array import RegisterArray


# A subset of Rust 2021 reserved keywords that could realistically collide with register or
# field names. Identifiers that clash are suffixed with an underscore.
RUST_RESERVED_KEYWORDS = {
    "as", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false",
    "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub",
    "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true", "type",
    "unsafe", "use", "where", "while", "async", "await", "abstract", "become", "box", "do",
    "final", "macro", "override", "priv", "typeof", "unsized", "virtual", "yield", "union",
}


def _ident(name: str) -> str:
    """Make a snake_case identifier safe to use as a Rust identifier."""
    return f"{name}_" if name in RUST_RESERVED_KEYWORDS else name


class RustRegisterGenerator(RegisterCodeGenerator):
    """
    Generate a Rust module with register definitions and a volatile-access accessor struct.
    See the module docstring for details on the generated artifact.
    """

    __version__ = "1.0.0"

    SHORT_DESCRIPTION = "Rust module"

    COMMENT_START = "//"

    DEFAULT_INDENTATION_LEVEL = 0

    @property
    def output_file(self) -> Path:
        """Result will be placed in this file."""
        return self.output_folder / f"{self.name}.rs"

    @property
    def _accessor_type(self) -> str:
        """Name of the generated accessor struct, e.g. 'CanFdFi'."""
        return self.to_pascal_case(self.name)

    def get_code(self, **kwargs: Any) -> str:  # noqa: ANN401, ARG002
        """Get the complete Rust module."""
        self._fail_on_unsupported()

        return f"""\
#![allow(dead_code, non_upper_case_globals, clippy::all)]
{self.comment("Generated register definitions and accessor for the "
              f"'{self.name}' register list.")}
{self._number_of_registers()}
{self._register_constants()}
{self._value_structs()}
{self._accessor()}"""

    def _fail_on_unsupported(self) -> None:
        """
        This generator currently supports plain registers with bit / bit_vector / integer fields,
        which covers the can_fd_fi core. Fail loudly (rather than emit wrong code) on anything else.
        """
        for register, register_array in self.iterate_registers():
            if register_array is not None:
                raise NotImplementedError(
                    "The Rust generator does not yet support register arrays "
                    f"(array '{register_array.name}')."
                )
            for field in register.fields:
                if isinstance(field, Enumeration):
                    raise NotImplementedError(
                        "The Rust generator does not yet support enumeration fields "
                        f"(field '{register.name}.{field.name}')."
                    )

    # ----------------------------------------------------------------------------------------------
    # Constants.

    def _number_of_registers(self) -> str:
        num_regs = 0
        if self.register_list.register_objects:
            num_regs = self.register_list.register_objects[-1].index + 1

        code = self.comment("Number of 32-bit registers within this register list.")
        code += f"pub const NUM_REGS: usize = {num_regs};\n"
        return code

    def _register_constants(self) -> str:
        code = ""
        for register in self.iterate_plain_registers():
            reg_name = register.name.upper()
            description = self.register_description(register=register)

            code += self.comment_block(
                [f"Constants for the {description}.", f"Mode '{register.mode.name}'."]
            )
            code += f"pub const {reg_name}_INDEX: usize = {register.index};\n"
            code += f"pub const {reg_name}_ADDR: usize = 4 * {reg_name}_INDEX;\n"
            code += (
                f"pub const {reg_name}_DEFAULT_VALUE: u32 = "
                f"0x{self.register_default_value_uint(register):08x};\n"
            )

            for field in register.fields:
                code += self._field_constants(register, field)

            code += "\n"

        return code

    def _field_constants(self, register: Register, field: RegisterField) -> str:
        name = self.qualified_field_name(register=register, field=field).upper()
        # Note: 'qualified_field_name' is "<list>_<register>_<field>". Strip the list prefix so the
        # constant reads "<REGISTER>_<FIELD>_*", matching the register constants above.
        name = name[len(self.name) + 1 :]

        shift = field.base_index
        mask = ((1 << field.width) - 1) << shift

        code = self.comment(f"Field '{field.name}'.")
        code += f"pub const {name}_SHIFT: u32 = {shift};\n"
        code += f"pub const {name}_WIDTH: u32 = {field.width};\n"
        code += f"pub const {name}_MASK: u32 = 0x{mask:08x};\n"
        code += f"pub const {name}_DEFAULT_VALUE: u32 = 0x{field.default_value_uint:x};\n"
        return code

    # ----------------------------------------------------------------------------------------------
    # Per-register native value structs.

    def _value_structs(self) -> str:
        code = ""
        for register in self.iterate_plain_registers():
            if not register.fields:
                continue

            struct_name = self.to_pascal_case(register.name)
            code += self.comment(
                f"Decoded field values of the '{register.name}' register."
            )
            code += "#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]\n"
            code += f"pub struct {struct_name} {{\n"
            for field in register.fields:
                code += f"    pub {_ident(field.name)}: {self._native_type(field)},\n"
            code += "}\n\n"

        return code

    @staticmethod
    def _native_type(field: RegisterField) -> str:
        if isinstance(field, Bit):
            return "bool"
        if isinstance(field, Integer):
            return "i32" if field.is_signed else "u32"
        if isinstance(field, BitVector):
            return "u32"
        raise TypeError(f"Unsupported field type: {field}")

    # ----------------------------------------------------------------------------------------------
    # Accessor struct.

    def _accessor(self) -> str:
        accessor = self._accessor_type

        code = self.comment_block(
            [
                f"Memory-mapped accessor for the '{self.name}' register list.",
                "",
                "Wraps a raw pointer to the register block base address. The caller is",
                "responsible for mapping the IP core into the process address space (e.g. via",
                "/dev/mem or a UIO device) and passing the resulting base pointer to `new`.",
            ]
        )
        code += f"pub struct {accessor} {{\n    base: *mut u32,\n}}\n\n"

        code += f"impl {accessor} {{\n"
        code += self._accessor_new()
        code += self._accessor_raw_helpers()
        for register in self.iterate_plain_registers():
            code += self._register_methods(register)
        code += "}\n"

        return code

    def _accessor_new(self) -> str:
        return (
            "    /// Create an accessor from a base pointer to the register block.\n"
            "    ///\n"
            "    /// # Safety\n"
            "    /// `base` must point to a valid, correctly-aligned mapping of the register\n"
            "    /// block that stays alive for the lifetime of the returned accessor.\n"
            "    #[inline]\n"
            "    pub unsafe fn new(base: *mut u32) -> Self {\n"
            "        Self { base }\n"
            "    }\n\n"
        )

    def _accessor_raw_helpers(self) -> str:
        return (
            "    #[inline]\n"
            "    fn read_index(&self, index: usize) -> u32 {\n"
            "        unsafe { self.base.add(index).read_volatile() }\n"
            "    }\n\n"
            "    #[inline]\n"
            "    fn write_index(&self, index: usize, value: u32) {\n"
            "        unsafe { self.base.add(index).write_volatile(value) }\n"
            "    }\n\n"
        )

    def _register_methods(self, register: Register) -> str:
        reg_lower = _ident(register.name.lower())
        reg_upper = register.name.upper()
        struct_name = self.to_pascal_case(register.name)
        readable = register.mode.software_can_read
        writeable = register.mode.software_can_write
        has_fields = bool(register.fields)

        code = self.get_separator_line()
        code += self.comment(f"'{register.name}' register. Mode '{register.mode.name}'.")

        if readable:
            code += (
                f"    #[inline]\n"
                f"    pub fn get_{reg_lower}_raw(&self) -> u32 {{\n"
                f"        self.read_index({reg_upper}_INDEX)\n"
                f"    }}\n\n"
            )
        if writeable:
            code += (
                f"    #[inline]\n"
                f"    pub fn set_{reg_lower}_raw(&self, value: u32) {{\n"
                f"        self.write_index({reg_upper}_INDEX, value);\n"
                f"    }}\n\n"
            )

        if not has_fields:
            return code

        if readable:
            code += self._register_struct_getter(register, reg_lower, struct_name)
        if writeable:
            code += self._register_struct_setter(register, reg_lower, struct_name)

        for field in register.fields:
            if readable:
                code += self._field_getter(register, field, reg_lower)
            if writeable:
                code += self._field_setter(register, field, reg_lower)

        return code

    def _register_struct_getter(
        self, register: Register, reg_lower: str, struct_name: str
    ) -> str:
        code = (
            f"    /// Read the register and decode all fields.\n"
            f"    pub fn get_{reg_lower}(&self) -> {struct_name} {{\n"
            f"        let raw = self.get_{reg_lower}_raw();\n"
            f"        {struct_name} {{\n"
        )
        for field in register.fields:
            code += f"            {_ident(field.name)}: {self._decode_expr(register, field)},\n"
        code += "        }\n    }\n\n"
        return code

    def _register_struct_setter(
        self, register: Register, reg_lower: str, struct_name: str
    ) -> str:
        code = (
            f"    /// Encode all fields and write the register.\n"
            f"    pub fn set_{reg_lower}(&self, value: {struct_name}) {{\n"
            f"        let mut raw: u32 = 0;\n"
        )
        for field in register.fields:
            code += f"        raw |= {self._encode_expr(register, field, member=True)};\n"
        code += f"        self.set_{reg_lower}_raw(raw);\n    }}\n\n"
        return code

    def _field_getter(self, register: Register, field: RegisterField, reg_lower: str) -> str:
        return (
            f"    #[inline]\n"
            f"    pub fn get_{reg_lower}_{_ident(field.name)}(&self) -> {self._native_type(field)} {{\n"
            f"        let raw = self.get_{reg_lower}_raw();\n"
            f"        {self._decode_expr(register, field)}\n"
            f"    }}\n\n"
        )

    def _field_setter(self, register: Register, field: RegisterField, reg_lower: str) -> str:
        const = self._field_const_prefix(register, field)
        if self.field_setter_should_read_modify_write(register):
            base = f"self.get_{reg_lower}_raw()"
        else:
            base = f"{register.name.upper()}_DEFAULT_VALUE"

        return (
            f"    #[inline]\n"
            f"    pub fn set_{reg_lower}_{_ident(field.name)}"
            f"(&self, value: {self._native_type(field)}) {{\n"
            f"        let base = {base};\n"
            f"        let value_bits = {self._encode_expr(register, field, member=False)};\n"
            f"        self.set_{reg_lower}_raw((base & !{const}_MASK) | value_bits);\n"
            f"    }}\n\n"
        )

    # ----------------------------------------------------------------------------------------------
    # Field encode/decode expression helpers.

    def _field_const_prefix(self, register: Register, field: RegisterField) -> str:
        return f"{register.name}_{field.name}".upper()

    def _decode_expr(self, register: Register, field: RegisterField) -> str:
        """Rust expression decoding `field` from a local `raw: u32`."""
        const = self._field_const_prefix(register, field)
        if isinstance(field, Bit):
            return f"(raw & {const}_MASK) != 0"
        if isinstance(field, Integer) and field.is_signed:
            # Sign-extend the field to a full i32.
            return (
                f"((((raw & {const}_MASK) >> {const}_SHIFT) << (32 - {const}_WIDTH)) as i32) "
                f">> (32 - {const}_WIDTH)"
            )
        # Unsigned integer and bit_vector.
        return f"(raw & {const}_MASK) >> {const}_SHIFT"

    def _encode_expr(self, register: Register, field: RegisterField, member: bool) -> str:
        """
        Rust expression producing the masked, shifted bits for `field`.
        `member` selects the value source: `value.<field>` (struct setter) or `value` (field setter).
        """
        const = self._field_const_prefix(register, field)
        source = f"value.{_ident(field.name)}" if member else "value"
        return f"(({source} as u32) << {const}_SHIFT) & {const}_MASK"
