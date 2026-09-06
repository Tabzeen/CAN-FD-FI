library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;
use ieee.numeric_std.all;

entity override_unit is
    port (
        -- Clock & Control
        clk                       : in  std_logic;
        reset_n                   : in  std_logic;
        sleep_i                   : in  std_logic;

        -- Memory Unit IO
        fi_frame_i                : in  fi_frame_t;
        fi_frame_ready_i          : in  std_logic;
        data_vector_ready_i       : in  std_logic;
        data_override_i           : in  std_logic_vector(575 downto 0);
        interrupt_req_o           : out std_logic;

        -- Status & Error Flags
        inj_err_miss_o            : out std_logic;
        inj_err_dom_o             : out std_logic;
        inj_err_dlc_o             : out std_logic;
        inj_err_fsm_o             : out std_logic;
        inj_pending_o             : out std_logic;

        -- Parser & Destuffer Status
        fsm_state_i               : in  fsm_state_types;
        fsm_cnt_i                 : in  integer range 0 to 512; 
        dlc_buffer_i              : in  std_logic_vector(3 downto 0);
        dlc_ready_i               : in  std_logic;
        fd_mode_i                 : in  std_logic;
        sample_buff_i             : in  std_logic;
        sample_buff_ready_i       : in  std_logic;

        -- Destuffer Tracking & Field boundaries for transceiver mode
        data_width_i              : in  INTEGER range 0 to 512;
        crc_width_i               : in  INTEGER range 0 to 21;
        bs_insert_i               : in  std_logic;
        bs_insert_dynamic_i       : in  std_logic;
        bs_shift_i                : in  std_logic_vector(4 downto 0); 
        bs_state_i                : in  bs_state_types;
        bs_crc_cnt_i              : in  integer;
        bs_crc_mode_i             : in  std_logic;

        -- Timing Unit Interface
        pre_sample_point_i        : in  std_logic;
        pre_sample_point_strobe_i : in  std_logic;
        injection_arm_o           : out std_logic;
        xcvr_mode_req_o           : out std_logic;
        xcvr_strb_i               : in  std_logic;
        fip_strb_i                : in  std_logic
    );
end entity override_unit;

architecture Behavioral of override_unit is

    -- FSM States & Queue
    type ou_state_t is (OU_AWAIT_FI, OU_BIT, OU_BSDY, OU_BSFX, OU_DLC, OU_DATA_CRC, OU_DONE);
    signal ou_state_r               : ou_state_t;
    signal ou_state                 : ou_state_t;

    signal injection_queue_r        : std_logic;
    signal injection_queue          : std_logic;

    -- Parsing Stage Registers
    signal fi_frame_parsed_r        : std_logic;
    signal fi_frame_parsed          : std_logic;
    signal fi_can_field_r           : fsm_state_types;
    signal fi_can_field             : fsm_state_types;
    signal fi_meta_as_dlc_c         : std_logic_vector(3 downto 0);
    signal fi_meta_as_offset_c      : integer;

    -- Stage I: Tracking & Pipeline Alignment Registers
    signal bs_cnt_r                 : integer;
    signal bs_cnt                   : integer;

    -- Required to handle stuffing at state transitions correctly
    signal shadow_fsm_state_r       : fsm_state_types;
    signal shadow_fsm_state         : fsm_state_types;

    -- Strobes to trigger Stage II Receiver mode (Also updates internal FSM and Destuffer)
    signal prep_override_strobe_r   : std_logic;
    signal prep_override_strobe     : std_logic;
    -- Strobes to trigger Stage II Transceiver mode
    signal xcvr_prep_strobe_r       : std_logic;
    signal xcvr_prep_strobe         : std_logic;

    -- Late strobe provided by setup in Stage I to inject directly on ID-parsed bit
    signal late_substitute_strobe_r : std_logic;
    signal late_substitute_strobe   : std_logic;

    -- Stage II: Override Execution Registers
    signal prev_bit_r               : std_logic;
    signal prev_bit                 : std_logic;
    signal dlc_override_sr_r        : std_logic_vector(3 downto 0);
    signal dlc_override_sr          : std_logic_vector(3 downto 0);
    
    -- Interrupt Request to MU
    signal interrupt_req_r          : std_logic;
    signal interrupt_req            : std_logic;

    -- Injection Error Flags
    signal inj_err_miss_r           : std_logic;
    signal inj_err_miss             : std_logic;
    signal inj_err_dom_r            : std_logic;
    signal inj_err_dom              : std_logic;
    signal inj_err_fsm_r            : std_logic;
    signal inj_err_fsm              : std_logic;
    signal inj_err_dlc_r            : std_logic;
    signal inj_err_dlc              : std_logic;
    signal inj_pending_r            : std_logic;
    signal inj_pending              : std_logic;
    signal reset_inj_dom_c          : std_logic;

    -- Injection Arming Registers
    signal injection_arm_r          : std_logic;
    signal injection_arm            : std_logic;

    -- Dynamic & Fixed Stuffing Edge Case Handling
    signal bsfx_context_shift_r     : std_logic;
    signal bsfx_context_shift       : std_logic;
    signal bsfx_context_window_c    : fsm_state_types;
    signal bs_insert_fixed_c        : std_logic;

    -- Internal Mirror FSM and Destuffer Registers
    signal s_fsm_cnt_r              : INTEGER range 0 to 512; 
    signal s_fsm_cnt                : INTEGER range 0 to 512; 
    signal s_fsm_state_r            : fsm_state_types;
    signal s_fsm_state              : fsm_state_types;
    signal s_bs_insert_r            : STD_LOGIC;
    signal s_bs_insert              : STD_LOGIC;
    signal s_bs_crc_mode_r          : STD_LOGIC;
    signal s_bs_crc_mode            : STD_LOGIC;
    signal s_bs_disable_r           : STD_LOGIC;
    signal s_bs_disable             : STD_LOGIC;

    -- Strobes to advance shadow stuffer and arming unit
    signal stage_iii_strobe_r       : STD_LOGIC;
    signal stage_iii_strobe         : STD_LOGIC;
    signal s_bs_state_r             : bs_state_types;
    signal s_bs_state               : bs_state_types;
    signal s_bs_crc_cnt_r           : INTEGER;
    signal s_bs_crc_cnt             : INTEGER;
    signal s_bs_shift_r             : STD_LOGIC_VECTOR(4 downto 0) := "01010";
    signal s_bs_shift               : STD_LOGIC_VECTOR(4 downto 0) := "01010";
    signal s_bs_copy_req_r          : std_logic;
    signal s_bs_copy_req            : std_logic;
    signal s_bs_substitute_strb_r   : std_logic; 
    signal s_bs_substitute_strb     : std_logic; 

    -- Transceiver mode flag to TU
    signal xcvr_mode_req_r          : std_logic;
    signal xcvr_mode_req            : std_logic;

    -- Data Counters
    attribute mark_debug            : string;
    signal data_override_cnt        : integer range 0 to 575;
    signal data_override_cnt_r      : integer range 0 to 575;
    signal dbg_data_shr             : std_logic_vector(31 downto 0);

    -- synthesis translate_off
    signal tb_override_triggered : std_logic;
    signal tb_override_queued : std_logic;
    -- synthesis translate_on

begin

    -- Output Assignments
    inj_err_miss_o      <= inj_err_miss_r;
    inj_err_dom_o       <= inj_err_dom_r;
    inj_err_fsm_o       <= inj_err_fsm_r;
    inj_err_dlc_o       <= inj_err_dlc_r;
    inj_pending_o       <= inj_pending_r;
    injection_arm_o     <= injection_arm_r;
    interrupt_req_o     <= interrupt_req_r;
    xcvr_mode_req_o     <= xcvr_mode_req_r;

	-- DLC is only 4b long, filter out the 4 LSB from the FI-Meta field
    fi_meta_as_dlc_c    <= fi_frame_i.fi_meta(3 downto 0);

    -- Conversion so that VHDL does not complain
    fi_meta_as_offset_c <= to_integer(unsigned(fi_frame_i.fi_meta));

    parse_fi_frame : process(all)
    begin
        fi_frame_parsed <= fi_frame_parsed_r;
        fi_can_field    <= fi_can_field_r;

        if sleep_i then
            fi_frame_parsed <= '0';
            fi_can_field    <= SLEEP;
        elsif fi_frame_ready_i = '1' then
            case fi_frame_i.fi_field is
                when "000"  => fi_can_field <= ABIT;
                when "001"  => fi_can_field <= CTRL;
                -- We skip DLC, because we consider it as part of CTRL, but keep the counting in order
                -- This is because the Parser implements it as a seperate state
                when "011"  => fi_can_field <= DATA;
                when "100"  => fi_can_field <= CRC_STF;
                when "101"  => fi_can_field <= CRC;
                when "110"  => fi_can_field <= EOF;
                when others => fi_can_field <= SLEEP;        
            end case;
            fi_frame_parsed <= '1';    
        end if;
    end process;

    ou_state_machine : process(all)
    begin
        -- Defaults
        ou_state               <= ou_state_r;
        late_substitute_strobe <= '0';
        bsfx_context_shift     <= bsfx_context_shift_r;
        shadow_fsm_state       <= shadow_fsm_state_r;
        reset_inj_dom_c        <= '0';    
        xcvr_prep_strobe       <= '0';
        prev_bit               <= prev_bit_r;
        prep_override_strobe   <= '0';
        interrupt_req          <= '0';

        -- Update the Context window for BSFX (See OU notes for 21.04)
        bsfx_context_window_c <= shadow_fsm_state_r when bsfx_context_shift_r else fsm_state_i; 

        -- Latch error flags across frame until next injection trigger
        inj_err_fsm            <= inj_err_fsm_r;
        inj_err_dlc            <= inj_err_dlc_r;
        inj_err_miss           <= inj_err_miss_r;
        inj_pending            <= inj_pending_r;

        if injection_arm_r = '1' then
            inj_pending <= '0';
        end if;

        
        -- Terminate the current Frame process correctly and reset registers for next Frame
        if sleep_i then
            shadow_fsm_state   <= ABIT;
            bsfx_context_shift <= '0';

            -- Check for missed triggers when FSM strobes halt prematurely
            if ou_state_r = OU_BIT or ou_state_r = OU_BSDY then
                inj_err_miss <= '1';
                ou_state     <= OU_DONE;
            -- When done enable interrupt and reset
            elsif ou_state_r = OU_DONE then
                interrupt_req <= '1';
                ou_state <= OU_AWAIT_FI;
            end if;
        elsif fsm_state_i = ERRF then
            inj_err_fsm <= '1';
            ou_state <= OU_DONE;
        elsif ou_state_r = OU_AWAIT_FI then
            if fi_frame_parsed_r = '1' and data_vector_ready_i = '1' then
                case fi_frame_i.fi_type is
                    when FI_DATA => ou_state <= OU_DATA_CRC;
                    when FI_BSFX => ou_state <= OU_BSFX;
                    when FI_BSDY => ou_state <= OU_BSDY;
                    when FI_DLC  => ou_state <= OU_DLC;
                    when FI_BIT  => ou_state <= OU_BIT;
                    when others  => ou_state <= OU_DONE;
                end case;
				
                -- Flag reset occurs only after new matching frame was found
                -- This is so the flags remain readable from AXI
                reset_inj_dom_c <= '1';
                inj_err_fsm     <= '0';
                inj_err_dlc     <= '0';
                inj_err_miss    <= '0';
                inj_pending     <= '1';
                prev_bit        <= '0';

              -- Note: See OU Working notes from 18.04
              -- TL;DR: We need to catch up on the predicted first CTRL bit after an extended ID
              -- As we already processed the sample_buff strobe in this state, we pass it on to the active state.
                late_substitute_strobe <= '1';
            end if;

        -- Capture the dom error from the Injection arming process
        -- This allows the PSP to be updated multiple times from resync, without triggering an error until the FIP is certain
        elsif inj_err_dom_r = '1' and fip_strb_i = '1' then
            ou_state <= OU_DONE;

        -- Main Actor Mode Strobe Handling
        elsif xcvr_strb_i = '1' then
            case ou_state_r is
            -- Exit conditions delayed by 1, in order to allow to check for stuffing in stage II
            -- meaning bit 1 of next state still counts as a tick
                when OU_DLC =>
                    if s_fsm_cnt_r > 0 and s_fsm_state_r > CTRL then
                        ou_state <= OU_DONE;
                    else
                        xcvr_prep_strobe <= '1';
                    end if;

                when OU_DATA_CRC =>
                    if s_fsm_cnt_r > 0 and s_fsm_state_r = EOF then
                        ou_state <= OU_DONE;
                    else
                        xcvr_prep_strobe <= '1';
                    end if; 

                when others =>
                    ou_state <= OU_DONE;
            end case;
                
        elsif (sample_buff_ready_i = '1' or late_substitute_strobe_r = '1') and xcvr_mode_req_r = '0' then
            shadow_fsm_state <= fsm_state_i;
            -- Add the current bit to buffer for the next bit to detect required value for stuffing
            prev_bit         <= sample_buff_i;    

            case ou_state_r is
                when OU_BIT =>
                    if injection_arm_r = '1' then
                        ou_state <= OU_DONE;
                    elsif fsm_state_i = fi_can_field and fsm_cnt_i = fi_meta_as_offset_c then
                        prep_override_strobe <= '1';
                    elsif fsm_state_i > fi_can_field then
                        inj_err_miss <= not injection_arm_r;
                        ou_state     <= OU_DONE;
                    end if;

                when OU_BSDY =>
                    if injection_arm_r = '1' then
                        ou_state <= OU_DONE;
                    elsif shadow_fsm_state_r = fi_can_field then
                        prep_override_strobe <= '1';
                    elsif shadow_fsm_state_r > fi_can_field then 
                        inj_err_miss <= not injection_arm_r;
                        ou_state     <= OU_DONE;
                    end if; 

                when OU_BSFX =>
                    -- Unified index tracking across CRC and CRC Stuff segments
                    if injection_arm_r = '1' then
                        ou_state <= OU_DONE;
                    elsif (bsfx_context_window_c = CRC_STF or bsfx_context_window_c = CRC) and fd_mode_i = '1' then
                        prep_override_strobe <= '1';
                        bsfx_context_shift   <= '1';
                    elsif bsfx_context_window_c > CRC then 
                        inj_err_miss <= not injection_arm_r;
                        ou_state     <= OU_DONE;
                    end if;

                when OU_DLC =>
                    if fsm_state_i = CTRL and fsm_cnt_i > 3 then
                        prep_override_strobe <= '1';
                    end if;
                    if fsm_state_i > CTRL then
                        ou_state <= OU_DONE;
                    end if;

                when OU_DATA_CRC =>
                    if dlc_ready_i = '1' and (fi_meta_as_dlc_c /= dlc_buffer_i) then
                        inj_err_dlc <= '1';
                        ou_state    <= OU_DONE;
                    elsif fsm_state_i = DATA or fsm_state_i = CRC_STF or fsm_state_i = CRC then
                        prep_override_strobe <= '1';
                    elsif fsm_state_i = EOF and fsm_cnt_i = 0 then
                        -- Final strobe handles tail stuffing after 5 consecutive recessive data bits
                        prep_override_strobe <= '1';
                    elsif fsm_state_i >= EOF then
                        ou_state <= OU_DONE;
                    end if;

                when others =>
                    ou_state <= OU_DONE;
            end case;      
        end if;
    end process;


    prep_override : process(all)
    begin
        -- Defaults
        injection_queue      <= injection_queue_r;
        bs_cnt               <= bs_cnt_r;
        -- Needed for BSFX in order to determine if the stuffing belongs to the previous dynamic frame or the fixed one
        bs_insert_fixed_c    <= '1' when bs_insert_i and not bs_insert_dynamic_i else '0';
        s_bs_crc_mode        <= s_bs_crc_mode_r;
        s_bs_disable         <= s_bs_disable_r;
        s_fsm_cnt            <= s_fsm_cnt_r;
        s_fsm_state          <= s_fsm_state_r;
        stage_iii_strobe     <= '0';
        xcvr_mode_req        <= xcvr_mode_req_r;
        dlc_override_sr      <= dlc_override_sr_r;
        data_override_cnt    <= data_override_cnt_r;
        s_bs_copy_req        <= '0';
        s_bs_substitute_strb <= '0';

        -- Sync with the FSM while not in actor mode 
        -- This is necessary as we DO NOT update all s_fsm_* registers
        -- when we transition to actor mode, but only do this partialy
        -- i.e. we update cnt but not state
        if prep_override_strobe_r = '1' then
            s_fsm_cnt     <= fsm_cnt_i;
            s_fsm_state   <= fsm_state_i;
            s_bs_crc_mode <= bs_crc_mode_i;
            s_bs_disable  <= '0';
        end if;

        if sleep_i = '1' then
            bs_cnt        <= 0;
            xcvr_mode_req <= '0';

        elsif ou_state_r = OU_AWAIT_FI then
            if fi_frame_parsed_r = '1' and data_vector_ready_i = '1' then
                data_override_cnt <= 575;
                dlc_override_sr   <= fi_meta_as_dlc_c;
            end if;

        elsif ou_state_r = OU_DONE then
            injection_queue <= '1';

        -- Bit stuff check before the injection is passed to the PSP check
        elsif prep_override_strobe_r = '1' then
            injection_queue <= '1';

            case ou_state_r is
                when OU_BIT =>
                    if bs_insert_i = '0' then
                        injection_queue <= '0';
                    end if;

                when OU_BSFX =>
                    if bs_insert_fixed_c = '1' then
                        bs_cnt <= bs_cnt_r + 1;
                        if bs_cnt_r = fi_meta_as_offset_c then
                            bs_cnt          <= bs_cnt_r;
                            injection_queue <= '0';
                        end if;
                    end if;

                when OU_BSDY =>
                    -- Dynamic stuffing filter ignores leading fixed CRC bit in FD mode
                    if bs_insert_dynamic_i = '1' then
                        bs_cnt <= bs_cnt_r + 1;
                        if bs_cnt_r = fi_meta_as_offset_c then
                            bs_cnt          <= bs_cnt_r;
                            injection_queue <= '0';
                        end if;
                    end if;

                when OU_DLC =>  
                    if bs_insert_i = '0' then
                        injection_queue      <= dlc_override_sr_r(3);
                        -- Dominant override (0) wins arbitration and shifts unit to actor mode
                        xcvr_mode_req        <= not dlc_override_sr_r(3);
                        s_bs_substitute_strb <= not dlc_override_sr_r(3);
                        dlc_override_sr      <= dlc_override_sr_r(2 downto 0) & '0';

                        s_fsm_cnt <= fsm_cnt_i + 1;
                        if fsm_cnt_i = 7 then
                            s_fsm_state <= CRC;
                            s_fsm_cnt   <= 0;
                        end if;
                    else
                        if inj_pending_r = '0' then
                            injection_queue <= not prev_bit_r;
                        end if;
                    end if;

                when OU_DATA_CRC =>
                    if bs_insert_i = '0' then
                        injection_queue      <= data_override_i(data_override_cnt_r);
                        xcvr_mode_req        <= not data_override_i(data_override_cnt_r);
                        s_bs_substitute_strb <= not data_override_i(data_override_cnt_r);
                        data_override_cnt    <= data_override_cnt_r - 1;

                        s_fsm_cnt <= fsm_cnt_i + 1;
                        if fsm_state_i = DATA then
                            if fsm_cnt_i = data_width_i - 1 then
                                s_fsm_cnt     <= 0;
                                s_fsm_state   <= CRC_STF when fd_mode_i else CRC;
                                s_bs_crc_mode <= fd_mode_i;
                            end if;
                        elsif fsm_state_i = CRC_STF then
                            if fsm_cnt_i = 3 then
                                s_fsm_state <= CRC;
                                s_fsm_cnt   <= 0;
                            end if;
                        elsif fsm_state_i = CRC then
                            if fsm_cnt_i = crc_width_i - 1 then
                                s_fsm_state  <= EOF;
                                s_fsm_cnt    <= 0;
                                s_bs_disable <= '1';
                            end if;
                        end if;
                    else
                        if inj_pending_r = '0' then
                            injection_queue <= not prev_bit_r;
                        end if;
                    end if;

                when others =>
                    injection_queue <= '1'; 
            end case;


        -- Stage IIa (Transceiver Mode)
        -- Updates the FSM, inserts stuff and drives the signal to Stage III
        elsif xcvr_prep_strobe_r = '1' then
            if s_bs_insert = '0' then
                case ou_state_r is
                    when OU_DLC =>
                        s_fsm_cnt       <= s_fsm_cnt_r + 1;
                        injection_queue <= dlc_override_sr_r(3);
                        dlc_override_sr <= dlc_override_sr_r(2 downto 0) & '0';

                        if s_fsm_cnt_r = 7 then
                            s_fsm_state <= CRC;
                            s_fsm_cnt   <= 0;

                        elsif s_fsm_state_r = CRC then
                        -- Hotfix: The Main FSM provides an additional strobe to allow for stuffing
                    	-- However if no stuffing occurs then it will enter this case instead and will try
                   		 -- to push a 0, we avoid that with this
                            injection_queue <= '1';
                        end if;

                    when OU_DATA_CRC =>
                        injection_queue   <= data_override_i(data_override_cnt_r);
                        data_override_cnt <= data_override_cnt_r - 1;
                        s_fsm_cnt         <= s_fsm_cnt_r + 1;

                        if s_fsm_state_r = DATA then
                            if s_fsm_cnt_r = data_width_i - 1 then
                                s_fsm_cnt     <= 0;
                                s_fsm_state   <= CRC_STF when fd_mode_i else CRC;
                                s_bs_crc_mode <= fd_mode_i;
                            end if;
                        elsif s_fsm_state_r = CRC_STF then
                            if s_fsm_cnt_r = 3 then
                                s_fsm_state <= CRC;
                                s_fsm_cnt   <= 0;
                            end if;
                        elsif s_fsm_state_r = CRC then
                            if s_fsm_cnt_r = crc_width_i - 1 then
                                s_fsm_state  <= EOF;
                                s_fsm_cnt    <= 0;
                                s_bs_disable <= '1';
                            end if;
                        elsif s_fsm_state_r = EOF then
                            injection_queue <= '1';
                        end if;

                    when others =>
                        s_fsm_cnt <= s_fsm_cnt_r;
                end case;
            else
                -- Invert last bs buffer bit bit for stuffing insertion
                injection_queue <= not s_bs_shift_r(0);
            end if;

            stage_iii_strobe <= '1';
        end if;
    end process;

    arm_injection : process(all)
    begin
        injection_arm <= injection_arm_r;
        inj_err_dom   <= inj_err_dom_r;

        if reset_inj_dom_c then  
            inj_err_dom <= '0';
        end if;
        -- HOTFIX: Stop the OU from trying to do further injections once the OU is finished
        if sleep_i = '1' or ou_state = OU_DONE then
            injection_arm <= '0';         
        -- Ignore the PSP and use the injection value directly disregarding the bus state whenin transceiver mode 
        elsif stage_iii_strobe_r = '1' then
            injection_arm <= not injection_queue_r;
        -- NOTE, here we "inverse" the injection value, by converting it from a literal bit to a flag
        elsif pre_sample_point_strobe_i = '1' then
            injection_arm <= '0';
            if injection_queue_r = '0' then
                if pre_sample_point_i = '1' then
                    injection_arm <= '1';
                else
                    inj_err_dom <= '1';
                end if;
            end if;
        end if;
    end process;


    -- Minimal version of the destuffer, used to determine when stuffing should be inserted on the bus
    shadow_stuffer : process(all)
    begin
        s_bs_insert  <= s_bs_insert_r; 
        s_bs_crc_cnt <= s_bs_crc_cnt_r;
        s_bs_shift   <= s_bs_shift_r;
        s_bs_state   <= s_bs_state_r;

        -- Mirror destuffer context from main parser prior to takeover
        if prep_override_strobe_r = '1' then
            s_bs_insert  <= bs_insert_i;
            s_bs_crc_cnt <= bs_crc_cnt_i;
            s_bs_shift   <= bs_shift_i;
            s_bs_state   <= bs_state_i;
        end if;

        -- Shift register updates on normal actor strobes or early substitute strobe
        if stage_iii_strobe_r = '1' or s_bs_substitute_strb_r = '1' then
            s_bs_insert <= '0';
            s_bs_shift  <= s_bs_shift_r(3 downto 0) & injection_queue_r;
            
            case s_bs_state_r is
                when MONITOR => 
                    if s_bs_crc_mode_r = '1' then
                        s_bs_state  <= CRC_INSERT;
                        s_bs_insert <= '1';
                    elsif ((s_bs_shift_r(3 downto 0) & injection_queue_r) = "00000") or 
                          ((s_bs_shift_r(3 downto 0) & injection_queue_r) = "11111") then
                        s_bs_state  <= INSERT;
                        s_bs_insert <= '1';
                    elsif s_bs_disable_r = '1' then
                        s_bs_state  <= DISABLE;
                    else
                        s_bs_state  <= MONITOR;
                    end if;

                when INSERT =>
                    if s_bs_disable_r = '1' then
                        s_bs_state <= DISABLE;
                    else
                        s_bs_state <= MONITOR;
                    end if;
                
                when CRC =>
                    s_bs_crc_cnt <= s_bs_crc_cnt_r + 1;
                    if s_bs_disable_r = '1' then
                        s_bs_state <= DISABLE;
                    elsif s_bs_crc_cnt_r = 3 then
                        s_bs_crc_cnt <= 0;
                        s_bs_state   <= CRC_INSERT;
                        s_bs_insert  <= '1';
                    end if;
                
                when CRC_INSERT =>
                    s_bs_crc_cnt <= 0;
                    s_bs_state   <= CRC;

                when others =>
                    s_bs_state <= DISABLE;
            end case;
        end if;
    end process;

    clk_reg_assign : process(clk, reset_n)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                fi_frame_parsed_r        <= '0';
                ou_state_r               <= OU_AWAIT_FI;
                injection_queue_r        <= '1';
                inj_err_fsm_r            <= '0';
                inj_err_miss_r           <= '0';
                inj_err_dom_r            <= '0';
                inj_err_dlc_r            <= '0';
                inj_pending_r            <= '0';
                dlc_override_sr_r        <= (others => '0');
                bs_cnt_r                 <= 0;
                prep_override_strobe_r   <= '0';
                injection_arm_r          <= '0';
                prev_bit_r               <= '0';
                fi_can_field_r           <= SLEEP;
                interrupt_req_r          <= '0';
                late_substitute_strobe_r <= '0';
                shadow_fsm_state_r       <= ABIT;
                bsfx_context_shift_r     <= '0';
                s_fsm_cnt_r              <= 0;
                s_fsm_state_r            <= ABIT;
                xcvr_prep_strobe_r       <= '0';
                s_bs_insert_r            <= '0';
                s_bs_crc_mode_r          <= '0';
                s_bs_disable_r           <= '0';
                stage_iii_strobe_r       <= '0';
                s_bs_state_r             <= MONITOR;
                s_bs_crc_cnt_r           <= 0;
                s_bs_shift_r             <= "00000";
                xcvr_mode_req_r          <= '0';
                s_bs_copy_req_r          <= '0';
                s_bs_substitute_strb_r   <= '0';
                data_override_cnt_r      <= 575;
            else
                fi_frame_parsed_r        <= fi_frame_parsed;
                ou_state_r               <= ou_state;
                injection_queue_r        <= injection_queue;
                inj_err_fsm_r            <= inj_err_fsm;
                inj_err_miss_r           <= inj_err_miss;
                inj_err_dom_r            <= inj_err_dom;
                inj_err_dlc_r            <= inj_err_dlc;
                inj_pending_r            <= inj_pending;
                dlc_override_sr_r        <= dlc_override_sr;
                bs_cnt_r                 <= bs_cnt;
                prev_bit_r               <= prev_bit;
                prep_override_strobe_r   <= prep_override_strobe;
                injection_arm_r          <= injection_arm;
                fi_can_field_r           <= fi_can_field;
                interrupt_req_r          <= interrupt_req;
                late_substitute_strobe_r <= late_substitute_strobe;
                shadow_fsm_state_r       <= shadow_fsm_state;
                bsfx_context_shift_r     <= bsfx_context_shift;
                s_fsm_cnt_r              <= s_fsm_cnt;
                s_fsm_state_r            <= s_fsm_state;
                xcvr_prep_strobe_r       <= xcvr_prep_strobe;
                s_bs_insert_r            <= s_bs_insert;
                s_bs_crc_mode_r          <= s_bs_crc_mode;
                s_bs_disable_r           <= s_bs_disable;
                stage_iii_strobe_r       <= stage_iii_strobe;
                s_bs_state_r             <= s_bs_state;
                s_bs_crc_cnt_r           <= s_bs_crc_cnt;
                s_bs_shift_r             <= s_bs_shift;
                xcvr_mode_req_r          <= xcvr_mode_req;
                s_bs_copy_req_r          <= s_bs_copy_req;
                s_bs_substitute_strb_r   <= s_bs_substitute_strb; 
                data_override_cnt_r      <= data_override_cnt;
            end if;
        end if;
    end process;
    
    -- synthesis translate_off
    tb_proc : process(all)
    begin
        if reset_n = '0' or sleep_i = '1' or sample_buff_ready_i = '1' then
            tb_override_triggered <= '0';
            tb_override_queued    <= '1';
        elsif prep_override_strobe_r = '1' or xcvr_prep_strobe_r = '1' then    
            tb_override_triggered <= '1';
        elsif injection_queue_r = '1' then    
            tb_override_queued    <= '1';
        end if;
    end process;
    -- synthesis translate_on

end architecture Behavioral;