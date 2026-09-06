

import random
from pathlib import Path
from utils import ExtCANFrame, ExtCANFDFrame, FIFrame 

fi_types = ["FI_DATA", "FI_BSFX", "FI_BSDY", "FI_DLC", "FI_BIT", "FI_NULL"]
fi_errs = ["000", "100", "010", "001"]

fi_type_err_map = {
    "FI_DATA" : ["000", "010", "001"],
    "FI_BSFX" : ["000", "100", "010"],
    "FI_BSDY" : ["000", "100"],
    "FI_DLC"  : ["000", "010"],
    "FI_BIT"  : ["000", "100", "010"],
    "FI_NULL" : ["000"]
}

dlc_str_lut = {
    0:  "0000",
    1:  "0001",
    2:  "0010",
    3:  "0011",
    4:  "0100",
    5:  "0101",
    6:  "0110",
    7:  "0111",
    8:  "1000",
    12: "1001",
    16: "1010",
    20: "1011",
    24: "1100",
    32: "1101",
    48: "1110",
    64: "1111"
}


def align_to_4(value):
    return (value + 3) & ~3

data_list = []
fi_frame_list = []
REC_SIZE = 1024 
# The Max no of bytes which the static VHDL array supports for the data override, indep of the actual DLC value
MAX_DATA_BYTES = 32
# The Max no of bits stored by the VHDL array 
MAX_DATA_BITS = MAX_DATA_BYTES * 8
# Hard constrained by the RAM Segments and vector input size of the override unit 
DATA_CRC_WIDTH = 576 
RAW_FRAME_SIZE = 512 


# Generate random data vectors, for each vector generate a set of different compatible error types 

fi_frame_idx = 0
for i in range(REC_SIZE):
    ide_i = random.randint(0, 1)
    fd_i = random.randint(0, 1)
    brs_i = random.randint(0, 1)

    # Constrain random vector selection pool based on the max value and the fd state
    # This is prefered over a naive "cut-off", which would lead to more base can vectors with 8 bytes 
    local_max = 8 if not fd_i and MAX_DATA_BYTES > 8 else MAX_DATA_BYTES  
    local_width_pool = [x for x in dlc_str_lut if x <= local_max]

    # Select random data width
    data_width_i = random.choice(local_width_pool)

    # Depending on if the fram eis fd or not, we reduce the max allowed data vector size for the generator
    data_i = [random.getrandbits(8) for _ in range(data_width_i)]
    id_a_i = random.getrandbits(11)
    id_b_i = random.getrandbits(18)
    
    if fd_i:
        tx_i = ExtCANFDFrame(data = data_i, ide = ide_i, id_a = id_a_i, id_b = id_b_i, fdf=1, brs=brs_i, max_data_bits=MAX_DATA_BITS, max_raw_bits=RAW_FRAME_SIZE)
    else:
        tx_i = ExtCANFrame(data = data_i, ide = ide_i, id_a = id_a_i, id_b = id_b_i, max_data_bits=MAX_DATA_BITS, max_raw_bits=RAW_FRAME_SIZE)
    
    data_list.append(tx_i)

    # Dont do BSFX for base frame, do another BSDY instead
    # (Kinda ugly solution,but least effort and it works and keeps the no of test vectors per data frame consistant)
    for t in fi_types:
        t_tmp = "FI_BSDY" if t == "FI_BSFX" and fd_i == 0 else t
        for err in fi_type_err_map[t_tmp]:
            fi_frame_list.append(FIFrame(fi_frame_idx, tx_i, t_tmp, err, i, DATA_CRC_WIDTH))
            fi_frame_idx += 1


final_fi_arr_size = len(fi_frame_list)


file_dir = Path(__file__).parent

vhdl_header = f"""
-- VHDL Record Definitions for CAN and Fault Injection Frames
-- Generated for use with REC_SIZE = {REC_SIZE}

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.sys_config_pkg.all;

package can_test_vec_pkg is

    constant REC_SIZE      : integer := {REC_SIZE};
    constant FI_REC_SIZE   : integer := {final_fi_arr_size};
    constant MAX_DATA_BITS : integer := {MAX_DATA_BITS};
    constant DATA_CRC_WIDTH: integer := {DATA_CRC_WIDTH};  
    constant MAX_RAW_BITS  : integer := {RAW_FRAME_SIZE};

    -- CAN / CAN FD Frame Record
    type can_frame_t is record
        id            : std_logic_vector(28 downto 0);
        dlc           : std_logic_vector(3 downto 0);
        ctrl          : std_logic_vector(3 downto 0);
        data          : std_logic_vector(MAX_DATA_BITS-1 downto 0);
        data_len      : integer;
        crc_stf       : std_logic_vector(3 downto 0);
        crc           : std_logic_vector(20 downto 0);
        eof           : std_logic_vector(12 downto 0);
        raw_frame     : std_logic_vector(0 to MAX_RAW_BITS-1);
        raw_frame_len : integer;
    end record;

    -- Fault Injection Frame Record
    type fi_tb_frame_t is record
        fi_type             : fi_type_t;
        fi_field            : std_logic_vector(2 downto 0);
        fi_meta             : std_logic_vector(8 downto 0);
        fi_valid            : std_logic;
        fi_err              : std_logic_vector(2 downto 0);
        fi_data_vec         : std_logic_vector(0 to DATA_CRC_WIDTH - 1);
        fi_data_len         : integer;
        fi_gt_data_out      : std_logic_vector(0 to DATA_CRC_WIDTH - 1);
        fi_target_frame_idx : integer;
    end record;

    -- Array Definitions
    type can_frame_array_t is array (0 to REC_SIZE-1) of can_frame_t;
    type fi_tb_frame_array_t is array (0 to FI_REC_SIZE-1) of fi_tb_frame_t;

"""


vhdl_tail = "end package;"


with open(file_dir / "can_test_vec_pkg.vhd", "w") as f:
    f.write(vhdl_header)

    data_h = "    constant D_TEST_FRAMES : can_frame_array_t := (\n"
    f.write(data_h)    
    for i in range(len(data_list)):
        f.write(data_list[i].format_record(i))
        if i == len(data_list) - 1:
            f.write("\n")
        else:
            f.write(",\n")
    frame_h = \
    """
    );

    constant FI_TEST_FRAMES : fi_tb_frame_array_t := (\n
    """
    f.write(frame_h)
    for i in range(len(fi_frame_list)):
        f.write(fi_frame_list[i].format_record(i))
        if i == len(fi_frame_list) - 1:
            f.write("\n")
        else:
            f.write(",\n")
    frame_t = "    );\n"
    f.write(frame_t)

    f.write(vhdl_tail)













