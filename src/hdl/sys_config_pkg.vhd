library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package sys_config_pkg is

    -- Log2 function used to determine RAM widths
    function log2_ceil (x : integer) return integer;

    -- Synthesis & Global Configuration Constants
    constant CFG_SYS_ENABLE_DEBUG : boolean := false;
    constant ID_MEM_ENTRY_COUNT   : integer := 8;

    -- FI & Transceiver Delay Constants
    constant MAX_GLITCH_REC       : integer := 5;
    constant TD_SLOT_CNT          : integer := 2;

    -- Memory Unit & Payload Geometry Constants
    constant PLD_SEG_IN_WIDTH     : integer := 32;
    constant PLD_OUT_WIDTH        : integer := 576;
    constant PLD_IN_SEG_CNT       : integer := 18;

    type fi_type_t is (FI_DATA, FI_BSFX, FI_BSDY, FI_DLC, FI_BIT, FI_NULL);
    function parse_fi_type (x : std_logic_vector(5 downto 0)) return fi_type_t;

    type fsm_state_types is (ABIT, CTRL, DATA, CRC_STF, CRC, EOF, ERRF, AWAIT_EOF, RESET, SLEEP);
    type bs_state_types  is (MONITOR, INSERT, BS_ERROR, CRC, CRC_INSERT, DISABLE, SLEEP);

    -- Structure of a Single Fault Injection Frame Element 
    type fi_frame_t is record
        fi_type  : fi_type_t;
        fi_field : std_logic_vector(2 downto 0);
        fi_meta  : std_logic_vector(8 downto 0);
    end record;

    constant fi_frame_init : fi_frame_t := (
        fi_type  => FI_NULL,
        fi_field => (others => '0'),
        fi_meta  => (others => '0')
    );

    type id_mem_t is record
        id_value : std_logic_vector(28 downto 0);
        id_mask  : std_logic_vector(28 downto 0);
        fi_frame : fi_frame_t;
    end record;

    type id_mem_arr_t is array (natural range <>) of id_mem_t;

    -- CAN and FI Timing Constraints
    constant TSEG1_MIN : integer := 1;
    constant TSEG1_MAX : integer := 255;
    constant TSEG2_MIN : integer := 1;
    constant TSEG2_MAX : integer := 127;
    constant SJW_MIN   : integer := 1;
    constant SJW_MAX   : integer := 127;
    constant BRP_MIN   : integer := 1;
    constant BRP_MAX   : integer := 32;
    constant PSP_MIN   : integer := 0;
    constant PSP_MAX   : integer := 255;
    constant FIP_MIN   : integer := 0;
    constant FIP_MAX   : integer := 255;
    constant SSP_MIN   : integer := 0;
    constant SSP_MAX   : integer := 383;

end package sys_config_pkg;

package body sys_config_pkg is

    function log2_ceil (x : integer) return integer is
    begin
        if x <= 1 then
            return 1;
        else
            return integer(ceil(log2(real(x))));
        end if;
    end function;        

    function parse_fi_type (x : std_logic_vector(5 downto 0)) return fi_type_t is
    begin
        case x is
            when "100000" => return FI_DATA; 
            when "010000" => return FI_BSFX;
            when "001000" => return FI_BSDY;
            when "000100" => return FI_DLC;
            when "000010" => return FI_BIT;
            when "000001" => return FI_NULL;
            when others   => return FI_NULL; -- Handles illegal states and metavalues (U, X, etc.)
        end case;
    end function;

end package body sys_config_pkg;