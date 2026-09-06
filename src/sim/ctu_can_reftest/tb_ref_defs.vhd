
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package tb_ref_defs is
    -- Constants and Data Payload Types
    constant C_MAX_REF_SEQ_LENGHT : natural := 1024;

    type t_ctu_data is array (0 to 63) of std_logic_vector(7 downto 0);

    -- Software CAN Frame type. Used for generation, transmission, reception,
    -- comparison of CAN Frames.
    type t_ctu_frame is record
        -- CAN Identifier (Base or Extended)
        identifier      :   natural;
        -- Data payload
        data            :   t_ctu_data;
        -- Data length code as defined in CAN Standard
        dlc             :   std_logic_vector(3 downto 0);
        -- Data length in bytes
        data_length     :   natural range 0 to 64;
        -- Identifier type (0 - BASE Format, 1 - Extended Format)
        ident_type      :   std_logic;
        -- Frame type (0 - Normal CAN, 1 - CAN FD)
        frame_format    :   std_logic;
        -- RTR Flag (0 - No RTR Frame, 1 - RTR Frame)
        rtr             :   std_logic;
        -- Bit rate shift flag
        brs             :   std_logic;
        -- ESI Flag (Error state indicator)
        esi             :   std_logic;
        -- Identifier valid flag
        ivld            :   std_logic;
        -- Timestamp (as defined in TIMESTAMP_U_W and TIMESTAMP_L_W)
        timestamp       :   std_logic_vector(63 downto 0);
        -- Receive word count (valid only for received frames)
        rwcnt           :   natural;
        -- Loopback frame flag
        lbpf            :   std_logic;
        -- Index of TXT Buffer used to send the frame
        lbtbi           :   natural;
        -- Error frame flag
        erf             :   std_logic;
        -- Error frame details
        erf_pos         :   std_logic_vector(3 downto 0);
        erf_erp         :   std_logic;
        erf_type        :   std_logic_vector(2 downto 0);
    end record;

    -- Driver and Reference Sequence Types
    type t_can_seq_entry is record
        -- Value to be driven
        value           :   std_logic;
        -- Time for which to drive this value
        drive_time      :   time;
    end record;

    type t_can_seq is 
        array (1 to C_MAX_REF_SEQ_LENGHT) of t_can_seq_entry;

    type t_reference_item is record
        frame           :   t_ctu_frame;
        seq             :   t_can_seq;
        seq_len         :   natural;
    end record;

    type t_reference_data_set is 
        array (1 to 1000) of t_reference_item;

    type t_reference_data_set_acc is access t_reference_data_set;


end package;