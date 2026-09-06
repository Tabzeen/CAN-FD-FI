library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.sys_config_pkg.all;

entity timer_unit is
    Port (
        -- Config Registers (AXI)
        cfg_ph1_len_nomi_i  : in  INTEGER range TSEG1_MIN to TSEG1_MAX;
        cfg_ph2_len_nomi_i  : in  INTEGER range TSEG2_MIN to TSEG2_MAX;
        cfg_ph1_len_data_i  : in  INTEGER range TSEG1_MIN to TSEG1_MAX;
        cfg_ph2_len_data_i  : in  INTEGER range TSEG2_MIN to TSEG2_MAX;
        cfg_sjw_nomi_i      : in  INTEGER range SJW_MIN to SJW_MAX;
        cfg_sjw_data_i      : in  INTEGER range SJW_MIN to SJW_MAX;
        cfg_brp_nomi_i      : in  INTEGER range BRP_MIN to BRP_MAX;
        cfg_brp_data_i      : in  INTEGER range BRP_MIN to BRP_MAX;
        cfg_psp_nomi_i      : in  INTEGER range PSP_MIN to PSP_MAX;
        cfg_psp_data_i      : in  INTEGER range PSP_MIN to PSP_MAX;
        cfg_fip_nomi_i      : in  INTEGER range FIP_MIN to FIP_MAX;
        cfg_fip_data_i      : in  INTEGER range FIP_MIN to FIP_MAX;
        cfg_ssp_i           : in  INTEGER range SSP_MIN to SSP_MAX;
        cfg_td_en_i         : in  std_logic;
        cfg_en_i            : in  STD_LOGIC;
        cfg_ready_o         : out STD_LOGIC;

        -- AXI Clock & Reset
        clk                 : in  STD_LOGIC;
        reset_n             : in  STD_LOGIC;

        -- CAN Bus IO
        can_rx_i            : in  STD_LOGIC;
        can_tx_o            : out STD_LOGIC;

		-- Global Sleep
        sleep_o             : out STD_LOGIC;

        -- Parser IO & Flags
        sample_o            : out STD_LOGIC;
        sample_strb_o       : out STD_LOGIC;

        eof_stat_i          : in  STD_LOGIC;
        brs_pend_stat_i     : in  STD_LOGIC;
        crc_del_pend_stat_i : in  STD_LOGIC;
        err_stat_i          : in  STD_LOGIC;
        hard_sync_req_i     : in  STD_LOGIC;

        -- Override IO
        injection_arm_i     : in  std_logic;
        xcvr_mode_req_i     : in  std_logic;
        xcvr_strb_o         : out std_logic;
        pre_sample_o        : out std_logic;
        pre_sample_strb_o   : out std_logic;
        fip_strb_o          : out std_logic;

        -- External Status
        frame_start_o       : out std_logic;
        frame_end_o         : out std_logic;
        injection_trigger_o : out std_logic
    );
end timer_unit;

architecture Behavioral of timer_unit is

    attribute mark_debug : string;

    -- Debug Signals
    signal resync_triggered_ph1   : std_logic;
    signal resync_triggered_ph2   : std_logic;
    signal resync_triggered_ph1_r : std_logic;
    signal resync_triggered_ph2_r : std_logic;

    -- CAN Bus Synchronizers & Edge Detection

    signal can_rx_int             : STD_LOGIC_VECTOR(1 downto 0) := (others => '1');
    signal can_rx_buf             : STD_LOGIC := '1';
    signal prev_rx_r              : STD_LOGIC;
    signal prev_rx                : STD_LOGIC;
    signal prev_tx_r              : STD_LOGIC;
    signal prev_tx                : STD_LOGIC;
    signal can_tx_buf_r           : STD_LOGIC;
    signal can_tx_buf             : STD_LOGIC;
    signal rx_falling             : STD_LOGIC;
    signal tx_falling             : STD_LOGIC;

    -- Phase Math

    signal active_ph1_len_r       : integer range TSEG1_MIN to TSEG1_MAX;
    signal active_ph1_len         : integer range TSEG1_MIN to TSEG1_MAX;
    signal active_ph2_len_r       : integer range TSEG2_MIN to TSEG2_MAX;
    signal active_ph2_len         : integer range TSEG2_MIN to TSEG2_MAX;
    signal active_sjw_r           : integer range SJW_MIN to SJW_MAX;
    signal active_sjw             : integer range SJW_MIN to SJW_MAX;
    signal active_brp_r           : integer range BRP_MIN to BRP_MAX;
    signal active_brp             : integer range BRP_MIN to BRP_MAX;
    signal active_fip_r           : integer range FIP_MIN to FIP_MAX;
    signal active_fip             : integer range FIP_MIN to FIP_MAX;
    signal active_psp_r           : integer range PSP_MIN to PSP_MAX;
    signal active_psp             : integer range PSP_MIN to PSP_MAX;
    signal end_val_ph1            : integer range 1 to 1 + TSEG1_MAX;
    signal end_val_ph2            : integer range 1 to 1 + TSEG1_MAX + TSEG2_MAX;
    signal resync_target_ph1      : integer range 0 to 1 + TSEG1_MAX;
    signal resync_target_ph2      : integer range 0 to 1 + TSEG1_MAX + TSEG2_MAX;
    signal brs_en_r               : std_logic;
    signal brs_en                 : std_logic;

    -- State Management

    type tu_state_type is (ACTIVE, SLEEP, CONFIG);
    signal tu_active_r            : STD_LOGIC;
    signal tu_active              : STD_LOGIC;
    signal smgmt_tu_state_r       : tu_state_type;
    signal smgmt_tu_state         : tu_state_type;
    signal smgmt_bit_cnt_r        : INTEGER;
    signal smgmt_bit_cnt          : INTEGER;
    signal smgmt_tq_cnt_r         : INTEGER;
    signal smgmt_tq_cnt           : INTEGER;
    signal cfg_ready_r            : STD_LOGIC;
    signal cfg_ready              : STD_LOGIC;

    -- Timing & Prescaler Signals

    signal strb_cnt_r             : integer range 0 to 4095;
    signal strb_cnt               : integer range 0 to 4095;
    signal strb_tick_r            : STD_LOGIC;
    signal strb_tick              : STD_LOGIC;
    signal strobe_rst_req_r       : STD_LOGIC;
    signal strobe_rst_req         : STD_LOGIC;

    -- Transceiver Delay Compensation

    type t_td_count_start_arr is array (0 to TD_SLOT_CNT-1) of unsigned(9 downto 0);
    type t_td_active_arr is array (0 to TD_SLOT_CNT-1) of std_logic;

    -- Counter Register
    signal td_cnt_r               : unsigned(9 downto 0);
    signal td_cnt                 : unsigned(9 downto 0);

    -- Slot working memory
    signal td_count_start_arr     : t_td_count_start_arr;
    signal td_count_start_arr_r   : t_td_count_start_arr;
    signal td_active_arr          : t_td_active_arr;
    signal td_active_arr_r        : t_td_active_arr;

	-- TD Measurement
    signal td_measure_start       : unsigned(9 downto 0);
    signal td_measure_start_r     : unsigned(9 downto 0);
    signal td_measure_active      : std_logic;
    signal td_measure_active_r    : std_logic;
    -- Most recent delay
    signal xcvr_delay_r           : unsigned(9 downto 0);
    signal xcvr_delay             : unsigned(9 downto 0);

    -- Glitch Rejection Logic
    signal gl_detected_r          : std_logic;
    signal gl_detected            : std_logic;
    signal gl_idx_cnt             : integer range 0 to MAX_GLITCH_REC;
    signal gl_idx_cnt_r           : integer range 0 to MAX_GLITCH_REC;
    signal gl_rec_cnt             : integer range 0 to MAX_GLITCH_REC;
    signal gl_rec_cnt_r           : integer range 0 to MAX_GLITCH_REC;

    -- Bit Timing Logic
    signal btl_tq_cnt_r           : integer range 0 to 383;
    signal btl_tq_cnt             : integer range 0 to 383;
    signal btl_soft_resync_r      : STD_LOGIC;
    signal btl_soft_resync        : STD_LOGIC;
    signal btl_hold_edge_r        : STD_LOGIC;
    signal btl_hold_edge          : STD_LOGIC;
    signal bit_start              : STD_LOGIC;
    signal bit_start_r            : STD_LOGIC;

    -- Sampling & Override Signals
    signal sample_buf_r           : STD_LOGIC;
    signal sample_buf             : STD_LOGIC;
    signal sample_strb_r          : STD_LOGIC;
    signal sample_strb            : STD_LOGIC;
    signal psp_buf_r              : STD_LOGIC;
    signal psp_buf                : STD_LOGIC;
    signal psp_strb_r             : STD_LOGIC;
    signal psp_strb               : STD_LOGIC;
    signal fip_strb_r             : STD_LOGIC;
    signal fip_strb               : STD_LOGIC;
    -- Strobe to OU at transceiver mode
    signal xcvr_strb_r            : std_logic;
    signal xcvr_strb              : std_logic;
    signal xcvr_mode              : std_logic;
    signal xcvr_mode_r            : std_logic;

    -- External IO Pins
    signal frame_start            : std_logic;
    signal frame_start_r          : std_logic;
    signal frame_end              : std_logic;
    signal frame_end_r            : std_logic;
    signal injection_trigger      : std_logic;
    signal injection_trigger_r    : std_logic;

    -- Debug
--    attribute mark_debug of sample_strb_r, bit_start_r, btl_tq_cnt_r, smgmt_tu_state_r, cfg_ready_r,
--                            active_ph1_len_r, active_ph2_len_r, active_sjw_r, active_brp_r,
--                            can_rx_buf, can_tx_buf_r, td_measure_start_r, td_measure_active_r,
--                            td_count_start_arr_r, td_active_arr_r, xcvr_delay_r, td_cnt_r : signal is "true";


begin

    -- Output Assignments
    cfg_ready_o         <= cfg_ready_r;
    sleep_o             <= not tu_active_r;
    can_tx_o            <= can_tx_buf_r;
    sample_o            <= sample_buf_r;
    sample_strb_o       <= sample_strb_r;
    pre_sample_o        <= psp_buf_r;
    pre_sample_strb_o   <= psp_strb_r;
    fip_strb_o          <= fip_strb_r;
    xcvr_strb_o         <= xcvr_strb_r;
    frame_start_o       <= frame_start_r;
    frame_end_o         <= frame_end_r;
    injection_trigger_o <= injection_trigger_r;

    -- Falling Edge Detection
    rx_falling <= (not can_rx_buf) and prev_rx_r;
    tx_falling <= (not can_tx_buf) and prev_tx_r;

    -- Phase Boundary and Resync Targets
    end_val_ph1 <= 1 + active_ph1_len;
    end_val_ph2 <= 1 + active_ph1_len + active_ph2_len;

    resync_target_ph1 <= 1 when ((btl_tq_cnt_r + 1 - active_sjw < 1) or (hard_sync_req_i = '1')) else
                         btl_tq_cnt_r + 1 - active_sjw;

    resync_target_ph2 <= 1 when ((btl_tq_cnt_r + 1 + active_sjw > end_val_ph2) or (hard_sync_req_i = '1')) else
                         0 when (btl_tq_cnt_r + 1 + active_sjw = end_val_ph2) else
                         btl_tq_cnt_r + 1 + active_sjw;

    prev_rx <= can_rx_buf;
    prev_tx <= can_tx_buf;

    btl_processor : process(all)
    begin
        resync_triggered_ph1 <= '0';
        resync_triggered_ph2 <= '0';
        injection_trigger    <= '0';
        xcvr_mode            <= xcvr_mode_r;

        -- Presets & Sleep Handling
        if tu_active_r = '1' then
            btl_tq_cnt      <= btl_tq_cnt_r;
            btl_soft_resync <= btl_soft_resync_r;
            can_tx_buf      <= can_tx_buf_r;
        else
            btl_tq_cnt      <= 0;
            btl_soft_resync <= '1';
            can_tx_buf      <= '1';
            xcvr_mode       <= '0';
        end if;

        sample_buf    <= sample_buf_r;
        sample_strb   <= '0';
        psp_buf       <= psp_buf_r;
        psp_strb      <= '0';
        fip_strb      <= '0';
        xcvr_strb     <= '0';

        --- Edge retainment between TQ at mTQ resolution
        btl_hold_edge <= btl_hold_edge_r or rx_falling;
        bit_start     <= bit_start_r;

        if tu_active_r = '1' and strb_tick_r = '1' then
            bit_start <= '0';

            if btl_tq_cnt_r < end_val_ph2 - 1 then
                btl_tq_cnt <= btl_tq_cnt_r + 1;
            else
                btl_tq_cnt <= 0;
                bit_start  <= '1';
            end if;

            -- Resync Handling
            if (btl_hold_edge_r = '1' or rx_falling = '1') and btl_soft_resync_r = '0' and sample_buf_r = '1' then
                btl_soft_resync <= '1';
                if btl_tq_cnt_r > 0 then
                    if btl_tq_cnt_r < end_val_ph1 - 1 then
                        btl_tq_cnt           <= resync_target_ph1;
                        resync_triggered_ph1 <= '1';
                    else
                        btl_tq_cnt <= resync_target_ph2;
                        if resync_target_ph2 < btl_tq_cnt_r then
                            bit_start <= '1';
                        end if;
                        resync_triggered_ph2 <= '1';
                    end if;
                end if;
            end if;

            -- Transceiver Mode
            if xcvr_mode_r = '1' then
            	-- Disable any further Resync when transceiving
                btl_soft_resync <= '1';

                -- SSP Sampling when in data rate (Calc. by TDC process)
                if brs_en = '1' then
                    for i in 0 to TD_SLOT_CNT-1 loop
                        if td_active_arr_r(i) = '1' and (td_cnt_r - td_count_start_arr_r(i)) >= (xcvr_delay_r + cfg_ssp_i) then
                            sample_buf  <= can_rx_buf;
                            sample_strb <= '1';
                            exit;
                        end if;
                    end loop;
                end if;

                -- Standard SP Sampling when not in data rate
                if brs_en = '0' and btl_tq_cnt_r = end_val_ph1 - 1 then
                    sample_buf  <= can_rx_buf;
                    sample_strb <= '1';
                end if;

                -- OU Strobe at SP
                if btl_tq_cnt_r = end_val_ph1 - 1 then
                    xcvr_strb <= '1';
                end if;

                -- FIP is set to bit boundary in transciver mode
                if btl_tq_cnt_r < end_val_ph2 - 1 then
                    can_tx_buf <= not injection_arm_i;
                end if;

            -- Receiver Mode
            else
                -- PSP Logic, can trigger mutliple times before the SP 
                -- as a result of resync
                if btl_tq_cnt_r = active_psp_r - 1 then
                    psp_buf  <= can_rx_buf;
                    psp_strb <= '1';
                end if;

                -- SP
                if btl_tq_cnt_r = end_val_ph1 - 1 then
                    sample_buf      <= can_rx_buf;
                    sample_strb     <= '1';
                    -- Resync is reset at SP
                    btl_soft_resync <= '0';
                end if;

                -- FIP Logic
                if btl_tq_cnt_r = active_fip_r - 1 then
                    can_tx_buf <= not injection_arm_i;
                    -- Lock the Resync for this bit, so we do not resync on our injection (at single bit injections)
                    if injection_arm_i = '1' then
                        btl_soft_resync <= '1';
                    end if;

                    if xcvr_mode_req_i = '1' then
                        xcvr_mode <= '1';
                        -- Force a Hard Resync at our injection boundary when switching to transceiver mode
                        if sample_buf_r = '1' then
                            btl_tq_cnt <= 0;
                        end if;
                    end if;
                    fip_strb          <= '1';
                    injection_trigger <= not injection_arm_i;
                end if;

                -- Injection Release
                if btl_tq_cnt_r = end_val_ph2 - 1 then
                    can_tx_buf <= not injection_arm_i;
                    can_tx_buf <= '1';
                end if;
            end if;

            btl_hold_edge <= '0';
        end if;
    end process;

    tdc_counter : process(all)
    begin
        td_cnt             <= td_cnt_r;
        xcvr_delay         <= xcvr_delay_r;
        td_measure_start   <= td_measure_start_r;
        td_measure_active  <= td_measure_active_r;
        td_count_start_arr <= td_count_start_arr_r;
        td_active_arr      <= td_active_arr_r;

        if tx_falling = '1' and cfg_td_en_i = '1' then
            td_measure_start  <= td_cnt_r;
            td_measure_active <= '1';
        end if;

        if rx_falling = '1' and td_measure_active_r = '1' then
            xcvr_delay        <= td_cnt_r - td_measure_start_r;
            td_measure_active <= '0';
        end if;

        if strb_tick_r = '1' then
            td_cnt <= td_cnt_r + 1;

            -- Timestamp slot allocation for each bit boundary
            if (btl_tq_cnt_r = active_fip_r - 1 and injection_arm_i = '1' and xcvr_mode_r = '0') or
               (btl_tq_cnt_r = end_val_ph2 - 1 and xcvr_mode_r = '1') then
                for i in 0 to TD_SLOT_CNT-1 loop
                    if td_active_arr_r(i) = '0' then
                        td_count_start_arr(i) <= td_cnt_r;
                        td_active_arr(i)      <= '1';
                        exit;
                    end if;
                end loop;
            end if;

            -- SSP Strobe Generation
            for i in 0 to TD_SLOT_CNT-1 loop
                if td_active_arr_r(i) = '1' then
                    if (td_cnt_r - td_count_start_arr_r(i)) >= (xcvr_delay_r + cfg_ssp_i) then
                        td_active_arr(i) <= '0';
                    end if;
                end if;
            end loop;
        end if;

        if tu_active_r = '0' then
            td_cnt             <= (others => '0');
            xcvr_delay         <= to_unsigned(511, 10) when cfg_td_en_i = '1' else (others => '0');
            td_measure_active  <= '0';
            td_measure_start   <= (others => '0');
            td_active_arr      <= (others => '0');
            td_count_start_arr <= (others => (others => '0'));
        end if;
    end process;

    state_mgmt : process(all)
    begin
        tu_active      <= tu_active_r;
        smgmt_tu_state <= smgmt_tu_state_r;
        smgmt_tq_cnt   <= smgmt_tq_cnt_r;
        smgmt_bit_cnt  <= smgmt_bit_cnt_r;
        strobe_rst_req <= '0';
        cfg_ready      <= cfg_ready_r;
        frame_start    <= '0';
        frame_end      <= '0';

        if cfg_en_i = '1' then
            smgmt_tu_state <= CONFIG;
            smgmt_tq_cnt   <= 0;
            smgmt_bit_cnt  <= 0;
            cfg_ready      <= '0';
            tu_active      <= '0';
            strobe_rst_req <= '1';
        else
            case smgmt_tu_state_r is
                when CONFIG =>
                	-- Await IFS at nomi rate, reset when encountering dom. bit
                    if strb_tick_r = '1' then
                        smgmt_tq_cnt <= smgmt_tq_cnt_r + 1;

                        if smgmt_tq_cnt_r >= end_val_ph2 - 1 then
                            smgmt_bit_cnt <= smgmt_bit_cnt_r + 1;
                            smgmt_tq_cnt  <= 0;
                        end if;

                        if smgmt_bit_cnt_r = 11 then
                            smgmt_tu_state <= SLEEP;
                            cfg_ready      <= '1';
                            strobe_rst_req <= '1';
                        end if;

                        if can_rx_buf = '0' then
                            smgmt_tq_cnt   <= 0;
                            smgmt_bit_cnt  <= 0;
                            smgmt_tu_state <= CONFIG;
                        end if;
                    end if;
                when ACTIVE =>
                    if eof_stat_i = '1' or gl_detected_r = '1' then
                        tu_active      <= '0';
                        smgmt_tu_state <= SLEEP;
                        strobe_rst_req <= '1';
                        cfg_ready      <= '0';
                        frame_end      <= '1';
                    end if;


                when SLEEP =>
                    cfg_ready      <= '1';
                    strobe_rst_req <= '1';
                    if rx_falling = '1' then
                        tu_active      <= '1';
                        smgmt_tu_state <= ACTIVE;
                        cfg_ready      <= '0';
                        frame_start    <= '1';
                    end if;
            end case;
        end if;
    end process;

    glitch_rejection : process(all)
    begin
        gl_detected <= gl_detected_r;
        gl_idx_cnt  <= gl_idx_cnt_r;
        gl_rec_cnt  <= gl_rec_cnt_r;

        if tu_active = '1' then
            if gl_idx_cnt_r = MAX_GLITCH_REC then
                gl_detected <= '1' when gl_rec_cnt_r >= (MAX_GLITCH_REC / 2) + 1 else '0';
                gl_idx_cnt  <= gl_idx_cnt_r;
                gl_rec_cnt  <= gl_rec_cnt_r;
            else
                gl_idx_cnt <= gl_idx_cnt_r + 1;
                gl_rec_cnt <= gl_rec_cnt_r + 1 when can_rx_buf = '1' else gl_rec_cnt_r;
            end if;
        else
            gl_idx_cnt  <= 0;
            gl_rec_cnt  <= 0;
            gl_detected <= '0';
        end if;
    end process;

    strobe_gen : process(all)
    begin
        if strobe_rst_req_r = '1' then
            strb_cnt  <= 0;
            strb_tick <= '0';
        else
            strb_tick <= '0';
            strb_cnt  <= strb_cnt_r + 1;
            if strb_cnt_r >= active_brp_r - 1 then
                strb_cnt  <= 0;
                strb_tick <= '1';
            end if;
        end if;
    end process;

    shift_speed : process(all)
        variable is_sample_point : boolean;
    begin
        is_sample_point := btl_tq_cnt_r = (1 + active_ph1_len_r) - 1 and strb_tick_r = '1';

        active_ph1_len <= active_ph1_len_r;
        active_ph2_len <= active_ph2_len_r;
        active_sjw     <= active_sjw_r;
        active_brp     <= active_brp_r;
        brs_en         <= brs_en_r;
        active_fip     <= active_fip_r;
        active_psp     <= active_psp_r;

        if not tu_active_r then
            active_ph1_len <= cfg_ph1_len_nomi_i;
            active_ph2_len <= cfg_ph2_len_nomi_i;
            active_sjw     <= cfg_sjw_nomi_i;
            active_brp     <= cfg_brp_nomi_i;
            active_fip     <= cfg_fip_nomi_i;
            active_psp     <= cfg_psp_nomi_i;
            brs_en         <= '0';
        else
            if brs_pend_stat_i = '1' and is_sample_point and can_rx_buf = '1' then
                active_ph2_len <= cfg_ph2_len_data_i;
                active_sjw     <= cfg_sjw_data_i;
                active_brp     <= cfg_brp_data_i;
                brs_en         <= '1';
            elsif (crc_del_pend_stat_i = '1' and is_sample_point) or err_stat_i = '1' then
                active_ph2_len <= cfg_ph2_len_nomi_i;
                active_sjw     <= cfg_sjw_nomi_i;
                active_brp     <= cfg_brp_nomi_i;
                brs_en         <= '0';
            end if;

            -- Delay PH1 adjustments until next bit.
            if bit_start_r = '1' then
                if brs_en_r = '1' then
                    active_ph1_len <= cfg_ph1_len_data_i;
                    active_fip     <= cfg_fip_data_i;
                    active_psp     <= cfg_psp_data_i;
                else
                    active_ph1_len <= cfg_ph1_len_nomi_i;
                    active_fip     <= cfg_fip_nomi_i;
                    active_psp     <= cfg_psp_nomi_i;
                end if;
            end if;
        end if;
    end process;

    clk_reg_assign : process(all)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                can_rx_int             <= "11";
                can_rx_buf             <= '1';
                prev_rx_r              <= '1';
                prev_tx_r              <= '1';
                tu_active_r            <= '0';
                strb_cnt_r             <= 0;
                strb_tick_r            <= '0';
                btl_tq_cnt_r           <= 0;
                btl_soft_resync_r      <= '0';
                sample_buf_r           <= '0';
                sample_strb_r          <= '0';
                brs_en_r               <= '0';
                active_ph1_len_r       <= 8;
                active_ph2_len_r       <= 2;
                active_sjw_r           <= 8;
                active_brp_r           <= 8;
                btl_hold_edge_r        <= '0';
                can_tx_buf_r           <= '1';
                smgmt_tu_state_r       <= SLEEP;
                cfg_ready_r            <= '1';
                smgmt_tq_cnt_r         <= 0;
                smgmt_bit_cnt_r        <= 0;
                strobe_rst_req_r       <= '0';
                active_psp_r           <= 2;
                active_fip_r           <= 3;
                psp_buf_r              <= '1';
                psp_strb_r             <= '0';
                td_cnt_r               <= (others => '0');
                xcvr_delay_r           <= (others => '0');
                td_measure_start_r     <= (others => '0');
                td_measure_active_r    <= '0';
                xcvr_strb_r            <= '0';
                xcvr_mode_r            <= '0';
                fip_strb_r             <= '0';
                gl_detected_r          <= '0';
                gl_idx_cnt_r           <= 0;
                gl_rec_cnt_r           <= 0;
                frame_start_r          <= '0';
                frame_end_r            <= '0';
                td_active_arr_r        <= (others => '0');
                td_count_start_arr_r   <= (others => (others => '0'));
                bit_start_r            <= '0';
                resync_triggered_ph1_r <= '0';
                resync_triggered_ph2_r <= '0';
                injection_trigger_r    <= '0';
            else
                can_rx_int             <= can_rx_int(0) & can_rx_i;
                can_rx_buf             <= can_rx_int(1);
                prev_rx_r              <= prev_rx;
                prev_tx_r              <= prev_tx;
                active_ph1_len_r       <= active_ph1_len;
                active_ph2_len_r       <= active_ph2_len;
                active_sjw_r           <= active_sjw;
                tu_active_r            <= tu_active;
                strb_cnt_r             <= strb_cnt;
                strb_tick_r            <= strb_tick;
                btl_tq_cnt_r           <= btl_tq_cnt;
                btl_soft_resync_r      <= btl_soft_resync;
                sample_buf_r           <= sample_buf;
                sample_strb_r          <= sample_strb;
                brs_en_r               <= brs_en;
                btl_hold_edge_r        <= btl_hold_edge;
                can_tx_buf_r           <= can_tx_buf;
                smgmt_tu_state_r       <= smgmt_tu_state;
                cfg_ready_r            <= cfg_ready;
                smgmt_tq_cnt_r         <= smgmt_tq_cnt;
                smgmt_bit_cnt_r        <= smgmt_bit_cnt;
                strobe_rst_req_r       <= strobe_rst_req;
                active_brp_r           <= active_brp;
                active_psp_r           <= active_psp;
                active_fip_r           <= active_fip;
                psp_buf_r              <= psp_buf;
                psp_strb_r             <= psp_strb;
                td_cnt_r               <= td_cnt;
                xcvr_delay_r           <= xcvr_delay;
                td_measure_start_r     <= td_measure_start;
                td_measure_active_r    <= td_measure_active;
                xcvr_strb_r            <= xcvr_strb;
                xcvr_mode_r            <= xcvr_mode;
                fip_strb_r             <= fip_strb;
                gl_detected_r          <= gl_detected;
                gl_idx_cnt_r           <= gl_idx_cnt;
                gl_rec_cnt_r           <= gl_rec_cnt;
                td_active_arr_r        <= td_active_arr;
                td_count_start_arr_r   <= td_count_start_arr;
                frame_start_r          <= frame_start;
                frame_end_r            <= frame_end;
                bit_start_r            <= bit_start;
                resync_triggered_ph1_r <= resync_triggered_ph1;
                resync_triggered_ph2_r <= resync_triggered_ph2;
                injection_trigger_r    <= injection_trigger;
            end if; 
        end if;
    end process;

end Behavioral;
