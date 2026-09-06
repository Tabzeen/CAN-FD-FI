//! Command-line CLI tool for the `can_fd_fi` IP core.
//!
//! Accesses the IP core through a **UIO device** (`uio_pdrv_genirq`, `compatible = "generic-uio"`
//!
//! For Usage run: `rust_can_fd_fi_test --help`

use clap::Parser;
use std::io;
use uio::UioDevice;

mod cli;
mod generated;

use cli::{dispatch_command, Cli};
use generated::can_fd_fi::CanFdFi;

const CAN_FI_DT_NODE: &str = "can_fi_axi_top_bd_wrap";
const MAX_UIO_INDEX: usize = 15;

// -----------------------------------------------------------------------------
// MAIN EXECUTION
// -----------------------------------------------------------------------------
fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("error: {err}");
            std::process::ExitCode::FAILURE
        }
    }
}

fn run() -> io::Result<()> {
    let cli = Cli::parse();

    // Dynamically find and map the UIO device based on the CLI device selector
    let dev = find_uio(&cli.device)?;
    let name = dev.get_name().unwrap_or_else(|_| "<unknown>".to_string());
    let addr = dev.map_addr(0).map_err(to_io_error)?;
    let size = dev.map_size(0).map_err(to_io_error)?;

    println!(
        "Attached to /dev/uio{} '{}': phys {:#x}, size {:#x}",
        dev.get_num(),
        name,
        addr,
        size,
    );

    // Map the register block. UIO map0 starts at the (page-aligned) physical base.
    let base = dev.map_mapping(0).map_err(to_io_error)? as *mut u32;

    // SAFETY: `base` points at the UIO mapping of the register block.
    let regs = unsafe { CanFdFi::new(base) };

    //NOTE Tests are now silent, for status run with "status" arg

    // Verify core magic number before proceeding
    let magic = regs.get_core_info_info_t();
    assert_eq!(magic, 0x4A4E_4943, "unexpected core magic number");

    let ver = regs.get_core_version();
    assert_eq!(ver.magic_valid, 0xAA, "CORE_VERSION magic byte invalid");
    // major/minor/patch are informational (printed above); no exact-value assert so the app
    // does not need editing on every version bump.

    // ---- Read/write register round-trip ----
    let cfg_save = regs.get_global_config();

    regs.set_global_config_cfg_en(true);
    regs.set_global_config_cfg_brp_nomi(16);

    let cfg = regs.get_global_config();
    assert!(cfg.cfg_en, "cfg_en did not stick");
    assert_eq!(cfg.cfg_brp_nomi, 16, "cfg_brp_nomi did not stick");

    // Restore clobbered registers
    regs.set_global_config(cfg_save);

    if magic != 0x4A4E_4943 {
        return Err(io::Error::other(format!(
            "Hardware initialization failed. Unexpected core magic number: {magic:#010x}"
        )));
    }

    println!("Checks OK");

    // Delegate CLI subcommands to the CLI module
    dispatch_command(regs, cli.command);

    Ok(())
}

// -----------------------------------------------------------------------------
// UIO Discovery Logic 
// -----------------------------------------------------------------------------

fn find_uio(selector: &str) -> io::Result<UioDevice> {
    if let Some(num) = selector.strip_prefix("uio").and_then(|n| n.parse::<usize>().ok()) {
        return UioDevice::try_new(num)
            .map_err(|e| io::Error::other(format!("cannot open /dev/uio{num}: {e}")));
    }

    let Some(num) = selector.strip_prefix("can") else {
        return Err(io::Error::other(format!(
            "unknown device selector '{selector}' (expected canN or uioN)"
        )));
    };

    let index = match num.parse::<usize>() {
        Ok(num) => num - 1,
        Err(_err) => {
            return Err(io::Error::other(format!(
                "unknown device selector '{selector}' (expected canN or uioN)"
            )));
        }
    };

    let mut instances: Vec<(usize, usize)> = Vec::new();
    for num in 0..=MAX_UIO_INDEX {
        let Ok(dev) = UioDevice::try_new(num) else { continue };
        let Some(node) = uio_dt_node(num) else { continue };
        if node.split('@').next() != Some(CAN_FI_DT_NODE) {
            continue;
        }
        let Ok(addr) = dev.map_addr(0) else { continue };
        instances.push((addr, num));
    }
    instances.sort_unstable();

    let Some(&(_, num)) = instances.get(index) else {
        return Err(io::Error::other(format!(
            "'{selector}' requested but only {} '{CAN_FI_DT_NODE}' UIO instance(s) found",
            instances.len()
        )));
    };

    UioDevice::try_new(num)
        .map_err(|e| io::Error::other(format!("cannot open /dev/uio{num}: {e}")))
}

/// Read the device-tree node name backing `/dev/uioN`.
fn uio_dt_node(num: usize) -> Option<String> {
    let target = std::fs::read_link(format!("/sys/class/uio/uio{num}/device/of_node")).ok()?;
    Some(target.file_name()?.to_string_lossy().into_owned())
}

fn to_io_error(e: uio::UioError) -> io::Error {
    io::Error::other(format!("{e:?}"))
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------
#[cfg(test)]
mod tests {
    use super::generated::can_fd_fi::{
        CanFdFi, GlobalConfig, CORE_INFO_INDEX, CORE_VERSION_INDEX,
        GLOBAL_CONFIG_CFG_BRP_NOMI_MASK, GLOBAL_CONFIG_CFG_BRP_NOMI_SHIFT,
        GLOBAL_CONFIG_CFG_EN_MASK, GLOBAL_CONFIG_INDEX, ID_MEM0_MATCH_IDM0_MATCH_MASK,
        ID_MEM0_MATCH_INDEX, NUM_REGS,
    };

    #[test]
    fn decode_read_only_register() {
        let mut mem = [0u32; NUM_REGS];
        mem[CORE_INFO_INDEX] = 0x4A4E_4943;

        let regs = unsafe { CanFdFi::new(mem.as_mut_ptr()) };
        assert_eq!(regs.get_core_info_info_t(), 0x4A4E_4943);
    }

    #[test]
    fn decode_core_version_fields() {
        let mut mem = [0u32; NUM_REGS];
        mem[CORE_VERSION_INDEX] = 0x0102_03AA;

        let regs = unsafe { CanFdFi::new(mem.as_mut_ptr()) };
        let ver = regs.get_core_version();
        assert_eq!(ver.major, 1);
        assert_eq!(ver.minor, 2);
        assert_eq!(ver.patch, 3);
        assert_eq!(ver.magic_valid, 0xAA);
    }

    #[test]
    fn field_setters_read_modify_write() {
        let mut mem = [0u32; NUM_REGS];
        let regs = unsafe { CanFdFi::new(mem.as_mut_ptr()) };

        regs.set_global_config_cfg_en(true);
        regs.set_global_config_cfg_brp_nomi(16);
        regs.set_global_config_cfg_brp_data(8);

        let v = regs.get_global_config();
        assert!(v.cfg_en);
        assert_eq!(v.cfg_brp_nomi, 16);
        assert_eq!(v.cfg_brp_data, 8);

        regs.set_global_config_cfg_ssp(5);
        let v2 = regs.get_global_config();
        assert_eq!(v2.cfg_brp_nomi, 16, "RMW clobbered an unrelated field");
        assert_eq!(v2.cfg_brp_data, 8, "RMW clobbered an unrelated field");
        assert_eq!(v2.cfg_ssp, 5);

        assert_eq!(mem[GLOBAL_CONFIG_INDEX] & GLOBAL_CONFIG_CFG_EN_MASK, 1);
        assert_eq!(
            (mem[GLOBAL_CONFIG_INDEX] & GLOBAL_CONFIG_CFG_BRP_NOMI_MASK)
                >> GLOBAL_CONFIG_CFG_BRP_NOMI_SHIFT,
            16
        );
    }

    #[test]
    fn struct_setter_then_getter() {
        let mut mem = [0u32; NUM_REGS];
        let regs = unsafe { CanFdFi::new(mem.as_mut_ptr()) };

        let want = GlobalConfig {
            cfg_en: true,
            interrupt_ack: false,
            cfg_brp_nomi: 12,
            cfg_brp_data: 20,
            cfg_td_en: false,
            cfg_ssp: 100,
        };
        regs.set_global_config(want);
        assert_eq!(regs.get_global_config(), want);
    }

    #[test]
    fn write_only_register_uses_defaults() {
        let mut mem = [0u32; NUM_REGS];
        let regs = unsafe { CanFdFi::new(mem.as_mut_ptr()) };

        regs.set_id_mem0_match_idm0_match(0x1234_5678 & 0x1FFF_FFFF);
        assert_eq!(
            mem[ID_MEM0_MATCH_INDEX] & ID_MEM0_MATCH_IDM0_MATCH_MASK,
            0x1234_5678 & 0x1FFF_FFFF
        );
    }
}