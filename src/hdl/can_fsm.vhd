library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sys_config_pkg.all;

entity can_fsm is
    Port (
        -- synthesis translate_off
        tb_ctrl_buffer_o    : out STD_LOGIC_VECTOR(3 downto 0);
        tb_data_buffer_o    : out STD_LOGIC_VECTOR(511 downto 0);
        tb_crc_stf_buffer_o : out STD_LOGIC_VECTOR(3 downto 0);
        tb_crc_buffer_o     : out STD_LOGIC_VECTOR(20 downto 0);
        tb_dlc_buffer_o     : out STD_LOGIC_VECTOR(3 downto 0);
        tb_id_buffer_o      : out STD_LOGIC_VECTOR(28 downto 0);
        -- synthesis translate_on

        dbg_id_buffer_o     : out STD_LOGIC_VECTOR(31 downto 0);
        dbg_ctrl_buffer_o   : out STD_LOGIC_VECTOR(31 downto 0);
        dbg_data_buffer_o   : out STD_LOGIC_VECTOR(31 downto 0);
        dbg_crc_buffer_o    : out STD_LOGIC_VECTOR(31 downto 0);

        -- AXI Slave IO
        clk                 : in  STD_LOGIC;
        reset_n             : in  STD_LOGIC;

        -- Timing-Unit IO
        sample_i            : in  STD_LOGIC;
        sample_strb_i       : in  STD_LOGIC;
        sleep_i             : in  STD_LOGIC;
        eof_stat_o          : out STD_LOGIC;
        brs_pend_stat_o     : out STD_LOGIC;
        crc_del_pend_stat_o : out STD_LOGIC;
        err_stat_o          : out STD_LOGIC;
        hard_sync_req_o     : out STD_LOGIC;
        sample_buff_ready_o : out std_logic;
        sample_buff_o       : out std_logic;

        -- Override-Unit IO
        fsm_state_o         : out fsm_state_types;
        fsm_cnt_o           : out INTEGER range 0 to 512;
        dlc_buffer_o        : out std_logic_vector(3 downto 0);
        dlc_ready_o         : out std_logic;
        id_buffer_o         : out std_logic_vector(28 downto 0);
        id_ready_o          : out std_logic;
        bs_insert_o         : out std_logic;
        bs_shift_o          : out std_logic_vector(4 downto 0);
        bs_state_o          : out bs_state_types;
        bs_crc_cnt_o        : out integer;
        fd_mode_o           : out std_logic;
        data_width_o        : out integer range 0 to 512;
        crc_width_o         : out integer range 0 to 21;
        destuff_strobe_o    : out std_logic;
        bs_insert_dynamic_o : out std_logic;
        bs_crc_mode_o       : out std_logic
    );
end can_fsm;

architecture Behavioral of can_fsm is

    attribute mark_debug : string;

    -- Destuffer Signals
    signal bs_insert_r         : STD_LOGIC;
    signal bs_insert           : STD_LOGIC;
    signal bs_crc_mode_r       : STD_LOGIC;
    signal bs_crc_mode         : STD_LOGIC;
    signal bs_disable_r        : STD_LOGIC;
    signal bs_disable          : STD_LOGIC;
    signal destuff_strobe_r    : STD_LOGIC;
    signal destuff_strobe      : STD_LOGIC;
    signal bs_state_r          : bs_state_types;
    signal bs_state            : bs_state_types;
    signal bs_crc_cnt_r        : INTEGER;
    signal bs_crc_cnt          : INTEGER;
    signal bs_err_stat         : STD_LOGIC;
    signal bs_shift_r          : STD_LOGIC_VECTOR(4 downto 0) := "01010";
    signal bs_shift            : STD_LOGIC_VECTOR(4 downto 0) := "01010";
    signal bs_shift_recent_c   : std_logic;
    signal bs_insert_dynamic_c : std_logic;

    -- Parser FSM & Tracking
    type can_bit is (SOF, ID, IDE, RTR, FDF, R0, BRS, ESI, DLC, DATA, CRC_STF, CRC, CRC_DEL, ACK, ACK_DEL, EOF, DC);

    signal fsm_cnt_r           : INTEGER range 0 to 512;
    signal fsm_cnt             : INTEGER range 0 to 512;
    signal fsm_state_r         : fsm_state_types;
    signal fsm_state           : fsm_state_types;
    signal fd_mode_r           : STD_LOGIC;
    signal fd_mode             : STD_LOGIC;
    signal ext_id_r            : STD_LOGIC;
    signal ext_id              : STD_LOGIC;
    signal can_bit_type_r      : can_bit;
    signal can_bit_type        : can_bit;
    signal data_width_r        : INTEGER range 0 to 512;
    signal data_width          : INTEGER range 0 to 512;
    signal crc_width_r         : INTEGER range 0 to 21;
    signal crc_width           : INTEGER range 0 to 21;

    -- Internal Buffers & Status Flags
    signal sample_buf_r        : STD_LOGIC;
    signal sample_buf          : STD_LOGIC;
    signal sample_buf_ready_r  : STD_LOGIC;
    signal sample_buf_ready    : STD_LOGIC;
    signal id_ready_r          : STD_LOGIC;
    signal id_ready            : STD_LOGIC;
    signal dlc_ready_r         : STD_LOGIC;
    signal dlc_ready           : STD_LOGIC;
    signal id_buffer_r         : STD_LOGIC_VECTOR(28 downto 0);
    signal id_buffer           : STD_LOGIC_VECTOR(28 downto 0);
    signal dlc_buffer_r        : STD_LOGIC_VECTOR(3 downto 0);
    signal dlc_buffer          : STD_LOGIC_VECTOR(3 downto 0);

    -- Timing-Unit IO Registers
    signal eof_stat_r          : STD_LOGIC;
    signal eof_stat            : STD_LOGIC;
    signal brs_pend_stat_r     : STD_LOGIC;
    signal brs_pend_stat       : STD_LOGIC;
    signal crc_del_pend_stat_r : STD_LOGIC;
    signal crc_del_pend_stat   : STD_LOGIC;
    signal err_stat_r          : STD_LOGIC;
    signal err_stat            : STD_LOGIC;
    signal hard_sync_req_r     : STD_LOGIC;
    signal hard_sync_req       : STD_LOGIC;

    -- Test Vector Buffers (TB Comparison)
    -- synthesis translate_off
    signal tb_ctrl_buffer_r    : STD_LOGIC_VECTOR(3 downto 0);
    signal tb_ctrl_buffer      : STD_LOGIC_VECTOR(3 downto 0);
    signal tb_crc_stf_buffer_r : STD_LOGIC_VECTOR(3 downto 0);
    signal tb_crc_stf_buffer   : STD_LOGIC_VECTOR(3 downto 0);
    signal tb_crc_buffer_r     : STD_LOGIC_VECTOR(20 downto 0);
    signal tb_crc_buffer       : STD_LOGIC_VECTOR(20 downto 0);
    signal tb_data_buffer_r    : STD_LOGIC_VECTOR(511 downto 0);
    signal tb_data_buffer      : STD_LOGIC_VECTOR(511 downto 0);
    signal dbg_data_buffer_r   : STD_LOGIC_VECTOR(31 downto 0);
    signal dbg_data_buffer     : STD_LOGIC_VECTOR(31 downto 0);
    -- synthesis translate_on

begin

    -- Output Assignments
    fsm_state_o         <= fsm_state_r;
    fsm_cnt_o           <= fsm_cnt_r;
    dlc_buffer_o        <= dlc_buffer_r;
    dlc_ready_o         <= dlc_ready_r;
    id_buffer_o         <= id_buffer_r;
    id_ready_o          <= id_ready_r;
    bs_insert_o         <= bs_insert_r;
    bs_shift_o          <= bs_shift_r;
    bs_state_o          <= bs_state_r;
    bs_crc_cnt_o        <= bs_crc_cnt_r;
    fd_mode_o           <= fd_mode_r;
    data_width_o        <= data_width_r;
    crc_width_o         <= crc_width_r;
    destuff_strobe_o    <= destuff_strobe_r;
    sample_buff_ready_o <= sample_buf_ready_r;
    sample_buff_o       <= sample_buf_r;

    eof_stat_o          <= eof_stat_r;
    brs_pend_stat_o     <= brs_pend_stat_r;
    crc_del_pend_stat_o <= crc_del_pend_stat_r;
    err_stat_o          <= err_stat_r;
    hard_sync_req_o     <= hard_sync_req_r;
    bs_insert_dynamic_o <= bs_insert_dynamic_c;
    bs_crc_mode_o       <= bs_crc_mode_r;

    -- Bitstuffing Error Combinational Gate
    bs_shift_recent_c <= bs_shift_r(0);
    bs_gate : process(all)
        variable bse_destuff_passive : BOOLEAN;
        variable bse_consecutive     : BOOLEAN;
    begin
        bse_destuff_passive := (bs_state_r = INSERT) or (bs_state_r = CRC_INSERT);
        bse_consecutive     := bs_shift_recent_c = sample_i;

        if sample_strb_i = '1' and bse_destuff_passive and bse_consecutive then
            bs_err_stat <= '1';
        else
            bs_err_stat <= '0';
        end if;
    end process;

    -- Denotes a Dynamic state of the stuffer (Osed for the OU)
    bs_insert_dynamic_c <= '1' when bs_state_r = INSERT else '0';

    update_bs : process(all)
    begin
        bs_state   <= bs_state_r;
        bs_insert  <= bs_insert_r;
        bs_shift   <= bs_shift_r;
        bs_crc_cnt <= bs_crc_cnt_r;

        -- Priority Reset & Sleep Handling
        if bs_state_r = SLEEP or sleep_i = '1' then
            bs_insert  <= '0';
            bs_crc_cnt <= 0;
            bs_shift   <= "10101";
            bs_state   <= MONITOR when sleep_i = '0' else SLEEP;

        elsif bs_err_stat = '1' then
            bs_state   <= BS_ERROR;
            -- Reset to not retrigger gate
            bs_shift   <= "10101";
            bs_insert  <= '0';

        -- Destuffing Shift & Prediction Logic
        elsif destuff_strobe_r = '1' then
            bs_insert <= '0';
            bs_shift  <= bs_shift_r(3 downto 0) & sample_buf_r;

            case bs_state_r is
                when MONITOR =>
                    -- ISO 11898-1:2015 Compliance fixed stuffing at data crc boundary replaces dynamic
                    if bs_crc_mode_r = '1' then
                        bs_state  <= CRC_INSERT;
                        bs_insert <= '1';
                    elsif ((bs_shift_r(3 downto 0) & sample_buf_r) = "00000") or
                          ((bs_shift_r(3 downto 0) & sample_buf_r) = "11111") then
                        bs_state  <= INSERT;
                        bs_insert <= '1';
                    elsif bs_disable_r = '1' then
                        bs_state  <= DISABLE;
                    else
                        bs_state  <= MONITOR;
                    end if;

                when INSERT =>
                    if bs_disable_r = '1' then
                        bs_state <= DISABLE;
                    else
                        bs_state <= MONITOR;
                    end if;

                -- In CRC fixed stuffing, stuff bit occurs every 5th bit (including bit 0)
                when CRC =>
                    bs_crc_cnt <= bs_crc_cnt_r + 1;
                    if bs_disable_r = '1' then
                        bs_state <= DISABLE;
                    elsif bs_crc_cnt_r = 3 then
                        bs_crc_cnt <= 0;
                        bs_state   <= CRC_INSERT;
                        bs_insert  <= '1';
                    end if;

                when CRC_INSERT =>
                    bs_crc_cnt <= 0;
                    bs_state   <= CRC;

                when DISABLE =>
                    bs_shift  <= "10101";
                    bs_insert <= '0';
                    bs_state  <= MONITOR when bs_disable_r = '0' else DISABLE;

                when BS_ERROR =>
                    bs_state  <= BS_ERROR;
                    bs_shift  <= bs_shift_r;
                    bs_insert <= '0';

                when others =>
                    bs_state <= BS_ERROR;
            end case;
        end if;
    end process;

    parser_fsm : process(all)
        variable v_cnt_delta  : INTEGER range 0 to 512;
        variable v_next_state : fsm_state_types;
    begin

        -- FSM Progression 
        v_cnt_delta      := 0;
        v_next_state     := fsm_state_r;
        can_bit_type <= can_bit_type_r;
        fd_mode <= fd_mode_r;
        ext_id <= ext_id_r;
        
        -- Internal Flags
        sample_buf_ready <= '0';
        sample_buf       <= sample_buf_r;
        bs_disable     <= bs_disable_r;
        bs_crc_mode    <= bs_crc_mode_r;
        destuff_strobe <= '0';
        dlc_ready        <= '0';
        dlc_buffer <= dlc_buffer_r;
        id_ready         <= id_ready_r;
        id_buffer  <= id_buffer_r;

        -- FSM Flags for TU
        eof_stat          <= eof_stat_r;
        brs_pend_stat     <= brs_pend_stat_r;
        crc_del_pend_stat <= crc_del_pend_stat_r;
        err_stat          <= err_stat_r;
        hard_sync_req     <= hard_sync_req_r;




        -- All flags are only valid for one bit
        if sample_strb_i then
            eof_stat          <= '0';
            brs_pend_stat     <= '0';
            crc_del_pend_stat <= '0';
            err_stat          <= '0';
            hard_sync_req     <= '0';
            sample_buf        <= sample_i;
            sample_buf_ready  <= '1';
        end if;

        -- PRIORITY LOGIC --

        -- Reset for FSM, to reduce Fanout on the Reset line
        -- Will be triggered 1 Cycle later!
        if fsm_state_r = SLEEP or sleep_i = '1' then
            -- 1. Reset Next State variables
            fsm_cnt <= 0;

            -- 2. Reset Control Flags
            id_ready         <= '0';
            dlc_ready        <= '0';
            eof_stat         <= '0';
            sample_buf_ready <= '0';

            -- 3. Reset FD and Speed Registers
            fd_mode           <= '0';
            brs_pend_stat     <= '0';
            crc_del_pend_stat <= '0';
            err_stat          <= '0';
            ext_id            <= '0';
            hard_sync_req     <= '0';

            -- 4. Reset Bit Stuffing Configuration
            bs_disable  <= '0';
            bs_crc_mode <= '0';

            id_buffer  <= (others => '0');
            dlc_buffer <= (others => '0');

            -- 5. Reset CAN Bit Trackers
            can_bit_type <= SOF;   -- Set to SOF as default idle type

            -- 6. Reset Data Buffers
            sample_buf <= '1';    -- Bus Idle is Recessive ('1')

            v_next_state := ABIT when sleep_i = '0' else SLEEP;

        -- Override the standard procedure of the FSM, queue the Error state at bs error
        elsif bs_err_stat = '1' then
            destuff_strobe <= '0';
            v_next_state := ERRF;
            err_stat <= '1';

        -- Ignore a bit if it is stuffed
        elsif sample_strb_i = '1' and bs_insert_r = '1' then
            -- pass "turn" to the destuffer
            destuff_strobe <= '1';

        --- PARSING LOGIC ---

        elsif sample_strb_i = '1' and bs_insert_r = '0' then

            destuff_strobe <= '1';
            v_cnt_delta := 1;

            case fsm_state_r is

                when ABIT =>
                    case fsm_cnt_r is
                        -- SOF: Wake the BS Component, Init Regisers
                        when 0 =>
                            can_bit_type <= ID;

                        -- ID BITS: Parse ID and Ext. ID
                        when 1 to 10 | 14 to 30 =>
                            can_bit_type <= ID;
                            id_buffer    <= id_buffer_r(27 downto 0) & sample_i;

                        -- Final ID Bit
                        when 11 | 31 =>
                            id_buffer    <= id_buffer_r(27 downto 0) & sample_i;
                            -- Next bit is SSR, RTR or RSS, we as a Fault Injector
                            -- do not care, as we cannot parse an ID yet. 
                            can_bit_type <= DC;

                        -- RSS / RTR Bit
                        when 12 =>
                            -- Next Bit is the IDE
                            can_bit_type <= IDE;
                        
                      

                        -- IDE BIT: Check for IDE value, and skip to the end if only base ID is sent 
                        when 13 =>
                            if sample_i = '0' then
                                -- Announce to the Override comp. that the FDF is pending
                                can_bit_type <= FDF;
                                -- Notify the Parse comp. that the full ID has been sent and parsing can start
                                id_ready     <= '1';
                                v_next_state := CTRL;
                            else
                                -- IF IDE is 1 we expect the Ext. ID
                                can_bit_type <= ID;
                                -- Mark the Frame as Ext ID
                                ext_id       <= '1';
                            end if;

                        -- RTR BIT
                        when 32 =>
                            -- Announce to the Override comp. that the FDF is pending
                            can_bit_type <= FDF;
                            -- Notify the Parse comp. that the full ID has been send and parsing can start
                            id_ready     <= '1';
                            v_next_state := CTRL;

                        when others =>
                            null;
                    end case;

                when CTRL =>

                    -- CTRL State Logic
                    case fsm_cnt_r is
                        -- FDF / R0 BIT: Handle FDF Bit to switch to FD Parse mode
                        when 0 =>
                            fd_mode       <= sample_i;
                            hard_sync_req <= sample_i;
                            -- Skip FD Bits and JMP to DLC if we stay in base CAN mode
                            if sample_i = '0' and ext_id_r = '0' then
                                v_cnt_delta  := 4;
                                can_bit_type <= DLC;
                            -- If FD Frame, announce the R0 Bit
                            else
                                can_bit_type <= R0;
                            end if;

                        -- R1 / R0 BIT
                        when 1 =>
                            -- For Extended ID, we record two reserved bits, after which we jump to DLC
                            if fd_mode_r = '0' and ext_id_r = '1' then
                                v_cnt_delta  := 3;
                                can_bit_type <= DLC;
                            else
                                -- Announce that the BRS is pending for an FD Frame
                                can_bit_type <= BRS;
                                -- Also announce the BRS to the TU
                                brs_pend_stat <= '1';
                            end if;

                        -- BRS BIT: Handle BRS Bit, request Speed change in TU
                        when 2 =>
                            -- Announce that ESI is pending
                            can_bit_type <= ESI;

                        -- ESI BIT
                        when 3 =>
                            -- Announce DLC
                            can_bit_type <= DLC;

                        -- DLC BITS: Parse DLC in Override Unit
                        when 4 to 6 =>
                            can_bit_type <= DLC;
                            dlc_buffer   <= dlc_buffer_r(2 downto 0) & sample_i;

                        -- END OF CTRL: Switch State at the end of DLC
                        when 7 =>
                            -- Check if the DLC is 0, if yes jump to CRC directly
                            -- as no data follows. This needs to be decided in-place
                            -- to avoid unnecessary flagging
                            if dlc_buffer_r(2 downto 0) & sample_i = "0000" then
                                v_next_state := CRC_STF when fd_mode_r = '1' else CRC;
                                can_bit_type <= CRC_STF when fd_mode_r = '1' else CRC;
                                -- Enable CRC mode, which is handled in the next cycle(!)
                                bs_crc_mode  <= fd_mode_r;
                            else
                                v_next_state := DATA;
                                can_bit_type <= DATA;
                            end if;
                            -- The DLC Unit still needs to know we are done in order 
                            -- to assign the correct CRC width, no matter if we have data or not
                            dlc_buffer <= dlc_buffer_r(2 downto 0) & sample_i;
                            dlc_ready  <= '1';

                        when others =>
                            null;
                    end case;

                -- Interate through Data only
                when DATA =>

                    if fsm_cnt_r = data_width_r - 1 then
                        v_next_state := CRC_STF when fd_mode_r = '1' else CRC;
                        -- Switch to Fixed bitstuffing in FD Mode
                        bs_crc_mode  <= fd_mode_r;
                        -- Announce that the CRC Stuffing is pending (if in FD Mode)
                        can_bit_type <= CRC_STF when fd_mode_r = '1' else CRC;
                    else
                        -- If we didnt reach CRC, more data follows
                        can_bit_type <= DATA;
                    end if;

                when CRC_STF =>

                    v_next_state := CRC when fsm_cnt_r >= 3 else CRC_STF;
                    can_bit_type <= CRC when fsm_cnt_r >= 3 else CRC_STF;

                -- Parse CRC
                when CRC =>

                    -- Check if at final CRC Bit
                    if fsm_cnt_r = crc_width_r - 1 then
                        v_next_state      := EOF;
                        bs_crc_mode       <= '0';
                        can_bit_type      <= CRC_DEL;
                        -- Disable the BS Component for the Frame's tail
                        bs_disable        <= '1';
                        -- Announce the CRC_DEL to the TU
                        crc_del_pend_stat <= '1';
                    else
                        can_bit_type <= CRC;
                    end if;

                when EOF =>
                    case fsm_cnt_r is
                        when 0 =>
                            can_bit_type <= ACK;
                        when 1 =>
                            can_bit_type <= ACK_DEL;
                        -- We usually do not terminate to any error except for bitstuffing, but for
                        -- EOF issues we need to know if the frame is "extended" due to Errors so the TU and OU
                        -- Still can parse the Bus
                        when 2 =>
                            if sample_i = '0' then
                                can_bit_type <= DC;
                                v_next_state := ERRF;
                            else
                                can_bit_type <= EOF;
                            end if;
                        when 3 to 7 =>
                            -- If the EOF is not recessive, something went wrong, transition to Error State
                            if sample_i = '0' then
                                can_bit_type <= DC;
                                v_next_state := ERRF;
                            else
                                can_bit_type <= EOF;
                            end if;
                        when 8 =>
                            if sample_i = '0' then
                                can_bit_type <= DC;
                                v_next_state := ERRF;
                            else
                                eof_stat     <= '1';
                                v_next_state := SLEEP;
                            end if;
                        when others =>
                            null;
                    end case;

                when ERRF =>
                    -- Check if Error Frame has been encountered
                    -- This is done by keeping a history of samples
                    -- and recording if a transition happens
                    -- If none happens we encountered an EF and can
                    -- report back a successfull fault injection
                    -- If not, we report an error and switch to the 
                    -- AWAIT_EOF state 

                    can_bit_type <= DC;

                    -- Don't drive the BS unit anymore, keep it stuck in the error state
                    destuff_strobe <= '0';
                    if sample_i = '1' then
                        v_next_state := AWAIT_EOF;
                    elsif fsm_cnt_r >= 6 then
                        v_next_state := AWAIT_EOF;
                    end if;

                -- This state is different from the normal EOF case, that it doesnt parse
                -- or allow override. At this point the Frame is expected to be broken
                -- and we just wait out a recessive bus 
                when AWAIT_EOF =>
                    -- Here we just wait for the bus to go low for 7 consecutive
                    -- samples, if it occured we switch to idle
                    -- It is guranteed to occur at some point.

                    can_bit_type <= DC;

                    v_cnt_delta := 0;
                    if sample_buf_r = '1' and sample_i = '1' then
                        v_cnt_delta := 1;
                    elsif sample_buf_r = '0' and sample_i = '0' then
                        v_cnt_delta := v_cnt_delta - 1 when v_cnt_delta > 0 else 0;
                    end if;

                    if fsm_cnt_r = 6 then
                        eof_stat     <= '1';
                        v_next_state := SLEEP;
                    end if;

                when others =>
                    null;
            end case;

        end if;

        -- Reset the internal counter on state change
        if(v_next_state /= fsm_state_r) then
            fsm_cnt <= 0;
        else
            fsm_cnt <= fsm_cnt_r + v_cnt_delta;
        end if;
        fsm_state <= v_next_state;

    end process;

    -- Assemble the DLC value, look into the LUT for the matching
    -- Data and CRC lengths and apply them back to the FSM
    parse_dlc : process(all)
        variable dlc_integer : INTEGER;
    begin
        -- Default keeps the value contents until DLC is changed
        data_width <= data_width_r;
        crc_width  <= crc_width_r;
        if sleep_i = '1' then
            data_width <= 0;
            crc_width  <= 0;
        elsif dlc_ready_r = '1' then
            dlc_integer := to_integer(unsigned(dlc_buffer_r));
            case dlc_buffer_r is
                -- FD Speeds do not correspond to the binary value
                when "1001" => data_width <= 12 * 8;
                when "1010" => data_width <= 16 * 8;
                when "1011" => data_width <= 20 * 8;
                when "1100" => data_width <= 24 * 8;
                when "1101" => data_width <= 32 * 8;
                when "1110" => data_width <= 48 * 8;
                when "1111" => data_width <= 64 * 8;
                when others =>
                    data_width <= dlc_integer * 8;
            end case;
            if fd_mode_r = '0' then
                crc_width <= 15;
            elsif dlc_integer <= 10 then
                crc_width <= 17;
            else
                crc_width <= 21;
            end if;
        end if;
    end process;

    clock_reg_assign : process(all)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                fsm_state_r         <= SLEEP;
                bs_state_r          <= SLEEP;
                bs_insert_r         <= '0';
                bs_crc_cnt_r        <= 0;
                bs_shift_r          <= "01010";
                destuff_strobe_r    <= '0';

                data_width_r        <= 0;
                crc_width_r         <= 0;

                eof_stat_r          <= '0';
                brs_pend_stat_r     <= '0';
                crc_del_pend_stat_r <= '0';
                err_stat_r          <= '0';
                hard_sync_req_r     <= '0';

                id_buffer_r         <= (others => '0');
                dlc_buffer_r        <= (others => '0');
            else
                bs_shift_r          <= bs_shift;
                fsm_cnt_r           <= fsm_cnt;
                fsm_state_r         <= fsm_state;
                bs_state_r          <= bs_state;
                bs_insert_r         <= bs_insert;
                bs_shift_r          <= bs_shift;
                bs_disable_r        <= bs_disable;
                bs_crc_cnt_r        <= bs_crc_cnt;
                destuff_strobe_r    <= destuff_strobe;

                can_bit_type_r      <= can_bit_type;
                sample_buf_ready_r  <= sample_buf_ready;

                data_width_r        <= data_width;
                crc_width_r         <= crc_width;

                sample_buf_r        <= sample_buf;
                id_ready_r          <= id_ready;
                dlc_ready_r         <= dlc_ready;

                eof_stat_r          <= eof_stat;
                brs_pend_stat_r     <= brs_pend_stat;
                crc_del_pend_stat_r <= crc_del_pend_stat;
                err_stat_r          <= err_stat;
                hard_sync_req_r     <= hard_sync_req;
                fd_mode_r           <= fd_mode;
                ext_id_r            <= ext_id;
                bs_crc_mode_r       <= bs_crc_mode;

                id_buffer_r         <= id_buffer;
                dlc_buffer_r        <= dlc_buffer;
            end if;
        end if;
    end process;

    ---------------------------
    --- Testbench processes ---
    ---------------------------

    -- synthesis translate_off
    tb_id_buffer_o      <= id_buffer_r;
    tb_ctrl_buffer_o    <= tb_ctrl_buffer_r;

    tb_data_buffer_o    <= tb_data_buffer_r;
    tb_crc_stf_buffer_o <= tb_crc_stf_buffer_r;
    tb_crc_buffer_o     <= tb_crc_buffer_r;
    tb_dlc_buffer_o     <= dlc_buffer_r;

    update_tb_vectors : process(all)
    begin
        tb_data_buffer    <= tb_data_buffer_r;
        tb_ctrl_buffer    <= tb_ctrl_buffer_r;
        tb_crc_stf_buffer <= tb_crc_stf_buffer_r;
        tb_crc_buffer     <= tb_crc_buffer_r;

        if fsm_state_r = SLEEP or sleep_i = '1' then
            tb_data_buffer    <= (others => '0');
            tb_ctrl_buffer    <= (others => '0');
            tb_crc_stf_buffer <= (others => '0');
            tb_crc_buffer     <= (others => '0');
        elsif sample_strb_i = '1' and bs_insert_r = '0' then
            case fsm_state_r is
                when CTRL =>
                    if fsm_cnt_r <= 3 then
                        tb_ctrl_buffer <= tb_ctrl_buffer_r(2 downto 0) & sample_i;
                    end if;
                when DATA =>
                    tb_data_buffer <= tb_data_buffer_r(510 downto 0) & sample_i;
                when CRC_STF =>
                    tb_crc_stf_buffer <= tb_crc_stf_buffer_r(2 downto 0) & sample_i;
                when CRC =>
                    tb_crc_buffer <= tb_crc_buffer_r(19 downto 0) & sample_i;
                when others =>
                    null;
            end case;
        end if;
    end process;

    tb_clock_reg_assign : process(all)
    begin
        if reset_n = '0' then
            tb_ctrl_buffer_r    <= (others => '0');
            tb_data_buffer_r    <= (others => '0');
            tb_crc_stf_buffer_r <= (others => '0');
            tb_crc_buffer_r     <= (others => '0');
        elsif rising_edge(clk) then
            tb_ctrl_buffer_r    <= tb_ctrl_buffer;
            tb_data_buffer_r    <= tb_data_buffer;
            dbg_data_buffer_r   <= dbg_data_buffer;
            tb_crc_stf_buffer_r <= tb_crc_stf_buffer;
            tb_crc_buffer_r     <= tb_crc_buffer;
        end if;
    end process;
    -- synthesis translate_on

    ---------------------
    --- Debug Process ---   
    ---------------------

    debug_gen: if CFG_SYS_ENABLE_DEBUG generate

        signal dbg_id_buffer_r   : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_ctrl_buffer_r : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_data_buffer_r : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_crc_buffer_r  : STD_LOGIC_VECTOR(31 downto 0);

        signal dbg_id_buffer     : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_ctrl_buffer   : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_data_buffer   : STD_LOGIC_VECTOR(31 downto 0);
        signal dbg_crc_buffer    : STD_LOGIC_VECTOR(31 downto 0);

    begin
        dbg_id_buffer_o   <= dbg_id_buffer_r;
        dbg_ctrl_buffer_o <= dbg_ctrl_buffer_r;
        dbg_data_buffer_o <= dbg_data_buffer_r;
        dbg_crc_buffer_o  <= dbg_crc_buffer_r;

        update_dbg_vectors : process(all)
        begin
            dbg_data_buffer <= dbg_data_buffer_r;
            dbg_ctrl_buffer <= dbg_ctrl_buffer_r;
            dbg_crc_buffer  <= dbg_crc_buffer_r;
            dbg_id_buffer   <= dbg_id_buffer_r;

            if fsm_state_r = SLEEP or sleep_i = '1' then
                -- Hold the dbg buffer when id_buffer_r gets reset
                dbg_id_buffer <= dbg_id_buffer_r;
            elsif sample_strb_i = '1' and bs_insert_r = '0' then
                case fsm_state_r is
                    when ABIT =>
                        if fsm_cnt_r <= 1 then
                            dbg_data_buffer <= (others => '0');
                            dbg_ctrl_buffer <= (others => '0');
                            dbg_crc_buffer  <= (others => '0');
                        end if;
                    when CTRL =>
                        dbg_id_buffer   <= "000" & id_buffer_r;
                        dbg_ctrl_buffer <= dbg_ctrl_buffer_r(30 downto 0) & sample_i;
                    when DATA =>
                        dbg_data_buffer <= dbg_data_buffer_r(30 downto 0) & sample_i;
                    when CRC_STF to CRC =>
                        dbg_crc_buffer  <= dbg_crc_buffer_r(30 downto 0) & sample_i;
                    when others =>
                        null;
                end case;
            end if;
        end process;

        dbg_clk_clock_reg_assign : process(all)
        begin
            if rising_edge(clk) then
                if reset_n = '0' then
                    dbg_id_buffer_r   <= (others => '0');
                    dbg_ctrl_buffer_r <= (others => '0');
                    dbg_data_buffer_r <= (others => '0');
                    dbg_crc_buffer_r  <= (others => '0');
                else
                    dbg_id_buffer_r   <= dbg_id_buffer;
                    dbg_ctrl_buffer_r <= dbg_ctrl_buffer;
                    dbg_data_buffer_r <= dbg_data_buffer;
                    dbg_crc_buffer_r  <= dbg_crc_buffer;
                end if;
            end if;
        end process;

    end generate debug_gen;

end Behavioral;