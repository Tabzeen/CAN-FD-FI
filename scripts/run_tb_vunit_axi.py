import os

from vunit import VUnit

# Paths are derived from this script's location so the runner is portable.
HERE = os.path.dirname(os.path.abspath(__file__))                 # .../can_fd_fi/scripts
IP = os.path.join(HERE, "..")                                     # .../can_fd_fi
HDL_MODULES = os.path.join(HERE, "..", "..", "..", "external", "git_hdl_modules", "modules")

# Initialize
vu = VUnit.from_argv()
vu.add_vhdl_builtins()
vu.add_osvvm()
vu.add_verification_components()
vu.add_random()


# HDL-Modules Files (from the hdl-modules git submodule)
def add_hdl_module(lib_name):
    lib = vu.add_library(lib_name)
    lib.add_source_files(os.path.join(HDL_MODULES, lib_name, "**", "*.vhd"))
    return lib


axi_lite = add_hdl_module("axi_lite")
axi = add_hdl_module("axi")
bfm = add_hdl_module("bfm")
common = add_hdl_module("common")
register_file = add_hdl_module("register_file")
math_lib = add_hdl_module("math")
resync = add_hdl_module("resync")
fifo = add_hdl_module("fifo")


defaultlib = vu.add_library("defaultlib")

# HDL-Register files (generated)
defaultlib.add_source_files(os.path.join(IP, "gen", "hdl", "**", "*.vhd"))
defaultlib.add_source_files(os.path.join(IP, "gen", "sim", "**", "*.vhd"))

# Project HDL Files
defaultlib.add_source_files(os.path.join(IP, "src", "hdl", "**", "*.vhd"))
# Project TB Files
defaultlib.add_source_files(os.path.join(IP, "src", "sim", "**", "*.vhd"))

# Run
vu.main()
