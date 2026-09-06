
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;

entity tb_func_timer_unit is
end tb_func_timer_unit;

architecture Behavioral of tb_func_timer_unit is

    --- UUT ---

    -- UUT Mirror Signals
    signal clk : STD_LOGIC := '0';
    signal uut_reset_n : STD_LOGIC := '0';
    signal uut_can_rx_i : STD_LOGIC := '0';
    signal uut_eof_stat_i : STD_LOGIC := '0';
    signal uut_brs_pend_stat_i : STD_LOGIC := '0';
    signal uut_crc_del_pend_stat_i : STD_LOGIC := '0';
    signal uut_err_stat_i : STD_LOGIC := '0';
    signal uut_hard_resync_req_i : STD_LOGIC := '0';
    signal uut_sample_o : STD_LOGIC := '0';
    signal uut_can_tx_o : STD_LOGIC := '0';
    signal uut_sample_strb_o : STD_LOGIC := '0';
    signal uut_cfg_ph1_len_nomi_i : INTEGER range TSEG1_MIN to TSEG1_MAX;
    signal uut_cfg_ph2_len_nomi_i : INTEGER range TSEG2_MIN to TSEG2_MAX;
    signal uut_cfg_ph1_len_data_i : INTEGER range TSEG1_MIN to TSEG1_MAX;
    signal uut_cfg_ph2_len_data_i : INTEGER range TSEG2_MIN to TSEG2_MAX;
    signal uut_cfg_sjw_nomi_i     : INTEGER range SJW_MIN to SJW_MAX;
    signal uut_cfg_sjw_data_i     : INTEGER range SJW_MIN to SJW_MAX;
    signal uut_cfg_brp_nomi_i     : INTEGER range BRP_MIN to BRP_MAX;
    signal uut_cfg_brp_data_i     : INTEGER range BRP_MIN to BRP_MAX;
    signal uut_cfg_ssp_i          : INTEGER range SSP_MIN to SSP_MAX;
    signal uut_cfg_fip_nomi_i     : INTEGER range FIP_MIN to FIP_MAX;
    signal uut_cfg_fip_data_i     : INTEGER range FIP_MIN to FIP_MAX;
    signal uut_cfg_psp_nomi_i     : INTEGER range PSP_MIN to PSP_MAX;
    signal uut_cfg_psp_data_i     : INTEGER range PSP_MIN to PSP_MAX;
    signal uut_sleep_o : STD_LOGIC;
    signal uut_cfg_en_i : STD_LOGIC;
    signal uut_cfg_ready_o : STD_LOGIC;

    signal uut_injection_arm_i : std_logic := '0';
    signal uut_xcvr_mode_req_i : std_logic;
    signal uut_xcvr_strb_o : std_logic;
    signal uut_pre_sample_o : std_logic;
    signal uut_pre_sample_strb_o : std_logic;
    
    signal uut_cfg_td_en_i : std_logic;


    -- Snapshot of the tq value at which the SSP has been triggered
    signal ssp_snapshot_tq : integer;

    
    --- TRANSCEIVER ---

    -- Tracks the current vector and bit for debugging in Waveform viewer 
    signal xcv_curr_test_vec : INTEGER := 0;
    signal xcv_curr_bit_idx : INTEGER := 0;
    signal xcv_ph1_active : std_logic := '0';

    type frame_timing_T is record
        xcv_bit_start : time;
        xcv_sample_point : time;
        xcv_is_jitter_frame : std_logic;
    end record;

    signal xcv_frame_timing : frame_timing_T;
    
    --- PARSER FSM SIMULATOR ---

    -- Flag which tells the FSM Sim to update its internal
    -- shift registers with the config value
    signal fsm_cfg : std_logic;

    -- Configuration of FSM for all bits of the current test vector
    signal fsm_eof_flag_cfg : std_logic_vector (0 to 7); 
    signal fsm_fd_speed_cfg : std_logic_vector (0 to 7); 
    signal fsm_resync_cfg : std_logic_vector (0 to 7); 
    signal ou_override_cfg : std_logic_vector (0 to 7); 

    -- Internal buffer in the FSM of all bits for the current test vector
    signal fsm_eof_flag_sft : std_logic_vector (0 to 7); 
    signal fsm_fd_speed_sft : std_logic_vector (0 to 7); 
    signal fsm_resync_sft : std_logic_vector (0 to 7); 
    signal ou_override_sft : std_logic_vector (0 to 7); 

    -- Buffered timing_frame held for the propagation delay of the TU
    -- This avoids comparing the sample points of 
    signal fsm_frame_timing_hold : frame_timing_T;

    -- Collect the passed values from the TU to the FSM at its SP 
    signal fsm_sample_o_history : std_logic_vector(0 to 7) := (others => '0');

    -- Track the BRS state internally in the FSm Process
    signal fsm_brs_state : std_logic := '0';

    signal brs_prev : std_logic;

    --- SIMULATION CONSTANTS ---

    -- Test the Core @ 80MHz
    constant clk_period : time := 12.5 ns;

    -- Propagation delay until CAN RX signal reaches the TU
    constant TU_PROP_DELAY_LENGTH : integer := 4;    
    -- Calculation delay of the simulated Parser in cycles
    constant FSM_DELAY_WIDTH : integer := 1;
    -- Maximum no. of allowed cycles in difference bw. real and uut sample point 
    constant MAX_PHASE_ERR: real := 5.0;


    --- MISC ---

    signal test_timing_active : std_logic;

    --- TEST VECTORS ---

    -- Test Vector preset constants
    -- Min Prescaler and TQ Length settings
    -- Overrides settings in the test vectors if applicable
    constant MIN_PRESCALER: integer := 1;
    constant MIN_TQ_PROP: integer := 1;
    constant MIN_TQ_PH1: integer := 1;
    constant MIN_TQ_PH2: integer := 1;


    -- Array to define jitter offset for each bit
    type bit_delta_arr is array (0 to 7) of integer;

    -- Record of a single test vector. Each Vector Contains 
    -- Simulated Config values from the AXI Master
    -- Simulated Frame with:
    -- 1. CAN RX Bitstream
    -- 1. Parser FSM Responses for each bit
    -- 2. Optional Jitter for each Bit of a vector
    type tb_vector_T is record
        -- Should a reset be performed before the vector?
        do_reset : std_logic;
        -- Arbitration Prescaler Config
        brp_nomi : integer;
        -- Data Prescaler Config
        brp_data : integer;
        -- Position in TQ for the Pre-SP
        psp_nomi : integer;
        psp_data : integer;
        -- Position in TQ for the Inj.P 
        fip_nomi : integer;
        fip_data : integer;
        -- Propagation Segment Length Config
        prop_len_nomi : integer;
        prop_len_data : integer;
        -- Phase 1 & Phase 2 Arbit. & Data
        ph1_len_nomi : integer;
        ph2_len_nomi : integer;
        ph1_len_data : integer;
        ph2_len_data : integer;
        -- sjw settings for Arbit. & Data
        sjw_nomi : integer;
        sjw_data: integer ;
        -- Parser to TU Flag Responses to a sample 
        brs_mask : std_logic_vector(0 to 7);
        eof_mask : std_logic_vector(0 to 7);
        hard_resync_req_mask : std_logic_vector(0 to 7);
        override_mask : std_logic_vector(0 to 7);
        -- CAN RX signal on the bus
        rx_signal : std_logic_vector(0 to 7);
        -- Jitter for each bit
        bit_delta : bit_delta_arr;
    end record;

    -- Test Vector constructor function
    -- Constructs Test Vectors while respecting the min Prescaler and TQ Width settings
    function vec_generator(
        do_reset : std_logic;
        brp_nomi : integer;
        brp_data : integer;
        fip_nomi : integer;
        fip_data : integer;
        psp_nomi : integer;
        psp_data : integer;
        prop_len_nomi : integer;
        prop_len_data : integer;
        ph1_len_nomi : integer;
        ph2_len_nomi : integer;
        ph1_len_data : integer;
        ph2_len_data : integer;
        sjw_nomi : integer;
        sjw_data: integer ;
        brs_mask : std_logic_vector(0 to 7);
        eof_mask : std_logic_vector(0 to 7);
        hard_resync_req_mask : std_logic_vector(0 to 7);
        override_mask : std_logic_vector(0 to 7);
        rx_signal : std_logic_vector(0 to 7);
        bit_delta : bit_delta_arr
    ) return tb_vector_T is variable v : tb_vector_T;
    begin
        v.do_reset := do_reset;

        v.brp_nomi := maximum(brp_nomi, MIN_PRESCALER);
        v.brp_data := maximum(brp_data, MIN_PRESCALER); 

        v.fip_nomi := fip_nomi;
        v.fip_data := fip_data;
        v.psp_nomi := psp_nomi;
        v.psp_data := psp_data;

        v.ph1_len_nomi := maximum(ph1_len_nomi + prop_len_nomi, MIN_TQ_PH1); 
        v.ph2_len_nomi := maximum(ph2_len_nomi, MIN_TQ_PH2);
        v.ph1_len_data := maximum(ph1_len_data + prop_len_data, MIN_TQ_PH1); 
        v.ph2_len_data := maximum(ph2_len_data, MIN_TQ_PH2);

        v.sjw_nomi     := sjw_nomi;     
        v.sjw_data     := sjw_data;

        v.brs_mask      := brs_mask;    
        v.eof_mask     := eof_mask;
        v.hard_resync_req_mask := hard_resync_req_mask;
        v.override_mask := override_mask;

        v.rx_signal    := rx_signal;

        v.bit_delta    := bit_delta;

        return v;
    end function;

    type tb_vector_arr_T is array (natural range <>) of tb_vector_T;
    constant tb_vector_arr : tb_vector_arr_T := (
        -- 0: A simple visible signal (Reset State)
        0 => vec_generator(
            do_reset => '1', brp_nomi => 32, brp_data => 32, fip_nomi => 9, fip_data => 4, psp_nomi => 5, psp_data => 3,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 10, ph1_len_data => 3, ph2_len_data => 3,
            sjw_nomi => 5, sjw_data => 3, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "10101010", rx_signal => "01010101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 1: Same signal without reset
        1 => vec_generator(
            do_reset => '1', brp_nomi => 32, brp_data => 32, fip_nomi => 9, fip_data => 4, psp_nomi => 5, psp_data => 3,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 10, ph1_len_data => 3, ph2_len_data => 3,
            sjw_nomi => 5, sjw_data => 3, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "10101010", rx_signal => "01010101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 2: Simple signal with FD speed
        2 => vec_generator(
            do_reset => '0', brp_nomi => 32, brp_data => 8, fip_nomi => 9, fip_data => 4, psp_nomi => 5, psp_data => 3,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 10, ph1_len_data => 3, ph2_len_data => 3,
            sjw_nomi => 10, sjw_data => 3, brs_mask => "00011100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "10101010", rx_signal => "01010101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 3: FD Stress Test (High Ratio)
        3 => vec_generator(
            do_reset => '0', brp_nomi => 32, brp_data => 5, fip_nomi => 10, fip_data => 2, psp_nomi => 6, psp_data => 1,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 12, ph2_len_nomi => 4, ph1_len_data => 2, ph2_len_data => 1,
            sjw_nomi => 10, sjw_data => 1, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "10101010", rx_signal => "01110101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 4: Heavy Jitter / Synchronization Test
        4 => vec_generator(
            do_reset => '0', brp_nomi => 16, brp_data => 16, fip_nomi => 7, fip_data => 7, psp_nomi => 4, psp_data => 4,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 8, ph2_len_nomi => 4, ph1_len_data => 8, ph2_len_data => 4,
            sjw_nomi => 8, sjw_data => 8, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "11001100", rx_signal => "01010101", bit_delta => (3, -4, 3, -3, 5, 1, 0, 0)
        ),

        -- 5: Late Sample Point Test (~88%)
        5 => vec_generator(
            do_reset => '0', brp_nomi => 10, brp_data => 10, fip_nomi => 12, fip_data => 12, psp_nomi => 7, psp_data => 7,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 14, ph2_len_nomi => 2, ph1_len_data => 14, ph2_len_data => 2,
            sjw_nomi => 14, sjw_data => 14, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00110011", bit_delta => (0, 0, 1, 0, 0, -1, 0, 0)
        ),

        -- 6: Drift Check (Long Dominant Run)
        6 => vec_generator(
            do_reset => '0', brp_nomi => 20, brp_data => 20, fip_nomi => 9, fip_data => 9, psp_nomi => 5, psp_data => 5,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 5, ph1_len_data => 10, ph2_len_data => 5,
            sjw_nomi => 10, sjw_data => 10, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00110011", rx_signal => "00000011", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 7: Minimum Time Quanta (Fastest Config)
        7 => vec_generator(
            do_reset => '0', brp_nomi => 4, brp_data => 4, fip_nomi => 4, fip_data => 3, psp_nomi => 3, psp_data => 2,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 2, ph2_len_nomi => 2, ph1_len_data => 2, ph2_len_data => 2,
            sjw_nomi => 2, sjw_data => 2, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "11111110", rx_signal => "01010101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 8: High Ratio FD Switch
        8 => vec_generator(
            do_reset => '0', brp_nomi => 6, brp_data => 4, fip_nomi => 14, fip_data => 4, psp_nomi => 8, psp_data => 2,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 16, ph2_len_nomi => 4, ph1_len_data => 4, ph2_len_data => 1,
            sjw_nomi => 4, sjw_data => 4, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "10100101", rx_signal => "01110101", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 9: Odd Prescaler & Low Sample Point
        9 => vec_generator(
            do_reset => '0', brp_nomi => 3, brp_data => 3, fip_nomi => 5, fip_data => 5, psp_nomi => 3, psp_data => 3,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 5, ph2_len_nomi => 4, ph1_len_data => 5, ph2_len_data => 4,
            sjw_nomi => 4, sjw_data => 4, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "01100111", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 10: Hard Resynchronization (Negative Jitter)
        10 => vec_generator(
            do_reset => '0', brp_nomi => 10, brp_data => 10, fip_nomi => 9, fip_data => 9, psp_nomi => 5, psp_data => 5,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 4, ph1_len_data => 10, ph2_len_data => 4,
            sjw_nomi => 10, sjw_data => 10, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "01111110", rx_signal => "01010111", bit_delta => (0, 0, -3, 0, -3, 0, 0, 0)
        ),

        -- 11: Accumulated Positive Drift (Late Edges)
        11 => vec_generator(
            do_reset => '0', brp_nomi => 10, brp_data => 10, fip_nomi => 3, fip_data => 3, psp_nomi => 2, psp_data => 2,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 10, ph2_len_nomi => 4, ph1_len_data => 10, ph2_len_data => 4,
            sjw_nomi => 10, sjw_data => 10, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "11111111", rx_signal => "01010101", bit_delta => (1, 2, 3, 4, 4, 5, 6, 0)
        ),

        -- 12: Pathological Case (Single TQ Phase_Seg2)
        12 => vec_generator(
            do_reset => '0', brp_nomi => 8, brp_data => 8, fip_nomi => 12, fip_data => 12, psp_nomi => 7, psp_data => 7,
            prop_len_nomi => 1, prop_len_data => 1, ph1_len_nomi => 14, ph2_len_nomi => 1, ph1_len_data => 14, ph2_len_data => 1,
            sjw_nomi => 14, sjw_data => 14, brs_mask => "00000000", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "11111111", rx_signal => "00000001", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 13: 1Mbps @ BRP 2 (40 TQ)
        13 => vec_generator(
            do_reset => '0', brp_nomi => 16, brp_data => 2, fip_nomi => 14, fip_data => 20, psp_nomi => 8, psp_data => 10,
            prop_len_nomi => 0, prop_len_data => 0, ph1_len_nomi => 17, ph2_len_nomi => 2, ph1_len_data => 31, ph2_len_data => 8,
            sjw_nomi => 2, sjw_data => 2, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00101010", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 14: 1Mbps @ BRP 1 (80 TQ)
        14 => vec_generator(
            do_reset => '0', brp_nomi => 6, brp_data => 1, fip_nomi => 14, fip_data => 40, psp_nomi => 8, psp_data => 20,
            prop_len_nomi => 0, prop_len_data => 0, ph1_len_nomi => 17, ph2_len_nomi => 2, ph1_len_data => 63, ph2_len_data => 16,
            sjw_nomi => 20, sjw_data => 20, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00101010", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 15: 2Mbps @ BRP 2 (20 TQ)
        15 => vec_generator(
            do_reset => '0', brp_nomi => 6, brp_data => 2, fip_nomi => 14, fip_data => 12, psp_nomi => 8, psp_data => 6,
            prop_len_nomi => 0, prop_len_data => 0, ph1_len_nomi => 17, ph2_len_nomi => 2, ph1_len_data => 15, ph2_len_data => 4,
            sjw_nomi => 20, sjw_data => 20, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00101010", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 16: 2Mbps @ BRP 1 (40 TQ)
        16 => vec_generator(
            do_reset => '0', brp_nomi => 6, brp_data => 1, fip_nomi => 14, fip_data => 20, psp_nomi => 8, psp_data => 10,
            prop_len_nomi => 0, prop_len_data => 0, ph1_len_nomi => 17, ph2_len_nomi => 2, ph1_len_data => 31, ph2_len_data => 8,
            sjw_nomi => 20, sjw_data => 20, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00101010", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        ),

        -- 17: 5Mbps @ BRP 1 (16 TQ)
        17 => vec_generator(
            do_reset => '0', brp_nomi => 6, brp_data => 1, fip_nomi => 14, fip_data => 8, psp_nomi => 8, psp_data => 4,
            prop_len_nomi => 0, prop_len_data => 0, ph1_len_nomi => 17, ph2_len_nomi => 2, ph1_len_data => 11, ph2_len_data => 6,
            sjw_nomi => 20, sjw_data => 20, brs_mask => "00111100", eof_mask => "00000001", hard_resync_req_mask => "00000000",
            override_mask => "00000000", rx_signal => "00101010", bit_delta => (0, 0, 0, 0, 0, 0, 0, 0)
        )

    );
   


begin
    uut: entity work.timer_unit PORT MAP (
        clk          => clk,
        reset_n      => uut_reset_n,
        can_rx_i    => uut_can_rx_i,
        eof_stat_i     => uut_eof_stat_i,
        brs_pend_stat_i => uut_brs_pend_stat_i,
        crc_del_pend_stat_i => uut_crc_del_pend_stat_i,
        err_stat_i => uut_err_stat_i,
        hard_sync_req_i => uut_hard_resync_req_i,
        sample_o   => uut_sample_o,
        can_tx_o    => uut_can_tx_o,
        sample_strb_o => uut_sample_strb_o,
        cfg_ph1_len_nomi_i => uut_cfg_ph1_len_nomi_i,
        cfg_ph2_len_nomi_i => uut_cfg_ph2_len_nomi_i,
        cfg_ph1_len_data_i => uut_cfg_ph1_len_data_i,
        cfg_ph2_len_data_i => uut_cfg_ph2_len_data_i,
        cfg_sjw_nomi_i => uut_cfg_sjw_nomi_i,
        cfg_sjw_data_i => uut_cfg_sjw_data_i,
        cfg_brp_nomi_i => uut_cfg_brp_nomi_i,
        cfg_brp_data_i => uut_cfg_brp_data_i,
        cfg_fip_nomi_i => uut_cfg_fip_nomi_i,
        cfg_fip_data_i => uut_cfg_fip_data_i,
        cfg_psp_nomi_i => uut_cfg_psp_nomi_i,
        cfg_psp_data_i => uut_cfg_psp_data_i,
        cfg_ssp_i => uut_cfg_ssp_i,
        injection_arm_i => uut_injection_arm_i,
        xcvr_mode_req_i => uut_xcvr_mode_req_i,
        xcvr_strb_o => uut_xcvr_strb_o,
        pre_sample_o => uut_pre_sample_o,
        pre_sample_strb_o => uut_pre_sample_strb_o,
        sleep_o => uut_sleep_o,
        cfg_en_i => uut_cfg_en_i,
        cfg_ready_o => uut_cfg_ready_o,
        cfg_td_en_i => uut_cfg_td_en_i
    );


    -- Providing the Clock
    clk_process : process
    begin 
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;


    -- Simulates an external transceiver on the bus
    -- Also performs configuration of the TU

    sim_transceiver : process
        -- Declared per-process: GHDL cannot resolve external names in the
        -- architecture declarative region against a directly instantiated entity.
        alias uut_btl_tq_cnt is << signal .tb_func_timer_unit.uut.btl_tq_cnt_r : integer range 0 to 383 >>;
        alias uut_brs_en is << signal .tb_func_timer_unit.uut.brs_en_r : std_logic >>;
        alias uut_xcvr_mode is << signal .tb_func_timer_unit.uut.xcvr_mode_r : std_logic >>;

        -- Timing duration for offset 
        variable xcv_ph1_width : integer;
        variable xcv_ps2_width : integer;
        variable xcv_ifs_bit_time : time;

        variable xcv_brs_set_flag : STD_LOGIC;
        variable xcv_ph1_time : time;
        variable xcv_ph2_time : time;
        variable xcv_active_brp : integer;
        variable xcv_jitter_frame_flag : std_logic;

        variable test_2_bit_width : integer;

        constant XCV_RESET_WIDTH : integer := 4;
        constant XCV_IFS_WIDTH : integer := 12;
    begin

        uut_can_rx_i <= '1';
        -- Enable Transceiver Delay Calculation throughout the entire computation
        uut_cfg_td_en_i <= '1';

        -- TEST 1 Reading logic and injection mode overrides 
        for i in tb_vector_arr'range loop

            xcv_curr_test_vec <= i;

            -- Disable BRS if it was active in last bit of prev. vector
            xcv_brs_set_flag := '0';

            -- Perform a reset if requested by the Test Vector
            if tb_vector_arr(i).do_reset = '1' then
                uut_reset_n <= '0';
                wait for clk_period * XCV_RESET_WIDTH;
                uut_reset_n <= '1';
                wait for clk_period * XCV_RESET_WIDTH;
            end if;

            
            -- Keep the bus recessive during IFS
            uut_can_rx_i <= '1';

            -- Check if UUT is ready for configuration after entring sleep following an EOF bit 
            assert uut_cfg_ready_o = '1' report "Unit is not config ready after sleep" severity failure;

            -- Perform Configuration of UUT
            uut_cfg_en_i <= '1';
            uut_cfg_ph1_len_nomi_i <= tb_vector_arr(i).ph1_len_nomi;
            uut_cfg_ph2_len_nomi_i <= tb_vector_arr(i).ph2_len_nomi;
            uut_cfg_ph1_len_data_i <= tb_vector_arr(i).ph1_len_data;
            uut_cfg_ph2_len_data_i <= tb_vector_arr(i).ph2_len_data;
            uut_cfg_sjw_nomi_i <= tb_vector_arr(i).sjw_nomi;
            uut_cfg_sjw_data_i <= tb_vector_arr(i).sjw_data;                                    
            uut_cfg_brp_nomi_i <= tb_vector_arr(i).brp_nomi;                                    
            uut_cfg_brp_data_i <= tb_vector_arr(i).brp_data;                                    
            uut_cfg_fip_nomi_i <= tb_vector_arr(i).fip_nomi;
            uut_cfg_fip_data_i <= tb_vector_arr(i).fip_data;
            uut_cfg_psp_nomi_i <= tb_vector_arr(i).psp_nomi;
            uut_cfg_psp_data_i <= tb_vector_arr(i).psp_data;

            xcv_ph1_width := tb_vector_arr(i).ph1_len_nomi + 1;
            xcv_ps2_width := tb_vector_arr(i).ph2_len_nomi;


            -- Preload the FSM values for each bit into a shift register, to avoid wrong parser values at slight TB timing offsets
            -- at small TQ & PRescaler values, which results in the unrealistic scenario of FSM values switching before the TU produces a strobe.
            -- In a real scenario, the FSM is part of the TU and runs dependent on the TUs offsets instead of the outer bus and this cannot happen
            -- Therefore we prefeed the FSM values driectly so they can change at the Strobes of the TU

            fsm_cfg <= '1';
            fsm_eof_flag_cfg <= tb_vector_arr(i).eof_mask;
            fsm_fd_speed_cfg <= tb_vector_arr(i).brs_mask;
            fsm_resync_cfg <= tb_vector_arr(i).hard_resync_req_mask;

            -- Note, moved to OU
            ou_override_cfg <= tb_vector_arr(i).override_mask;

            -- IFS runs at nominal speed
            xcv_ifs_bit_time := clk_period * (xcv_ph1_width + xcv_ps2_width) * tb_vector_arr(i).brp_nomi;

            -- Wait out for one bit and disable config mode
            wait for xcv_ifs_bit_time;
            uut_cfg_en_i <= '0';
            fsm_cfg <= '0';

            -- Wait out IFS before transmitting frame data
            wait for xcv_ifs_bit_time * XCV_IFS_WIDTH;
            
            -- Check if the UUT correctly left the config state after the IFS;
            assert uut_cfg_ready_o = '1' report "Unit is not config ready after IFS" severity failure;

            -- Reset Jitter flag for the next vector
            xcv_jitter_frame_flag := '0';
            
            
            -- Iterate over each bit
            for j in tb_vector_arr(i).rx_signal'range loop
                report "Running Vector " & integer'image(i) & " Interation " & integer'image(j);
                
                -- PHASE 1 --
                
                -- Debugging signals
                xcv_curr_bit_idx <= j;
                xcv_ph1_active <= '1';
                
                -- Set rx signal of current bit
                uut_can_rx_i <= tb_vector_arr(i).rx_signal(j);

                
                -- Set Phase lengths and Prescaler depending on the BRS value carried over from last bit
                if xcv_brs_set_flag = '1' then
                    xcv_ph1_width := tb_vector_arr(i).ph1_len_data + 1;
                    xcv_active_brp := tb_vector_arr(i).brp_data;
                else
                    xcv_ph1_width := tb_vector_arr(i).ph1_len_nomi + 1;
                    xcv_active_brp := tb_vector_arr(i).brp_nomi;
                end if;
                xcv_ph1_time := clk_period * xcv_ph1_width * xcv_active_brp;
                
                
                -- Adjust Phase 2 width & Prescaler dep. on BRS value of the current bit, also prepare settings for the next bit
                if tb_vector_arr(i).brs_mask(j) = '1' then
                    xcv_ps2_width := tb_vector_arr(i).ph2_len_data;
                    xcv_active_brp := tb_vector_arr(i).brp_data;
                    xcv_brs_set_flag := '1';
                else
                    xcv_ps2_width := tb_vector_arr(i).ph2_len_nomi;
                    xcv_active_brp := tb_vector_arr(i).brp_nomi;
                    xcv_brs_set_flag := '0';
                end if;
                xcv_ph2_time := clk_period * (xcv_ps2_width + tb_vector_arr(i).bit_delta(j)) * xcv_active_brp;
                
                -- Set the jitter flag, if the current bit contains artificial jitter
                -- As the offset adds up to the pending bits, the flag should stay high for the rest fo the bit once triggered 
                if tb_vector_arr(i).bit_delta(j) /= 0 then
                    xcv_jitter_frame_flag := '1';
                else 
                    xcv_jitter_frame_flag := xcv_jitter_frame_flag;
                end if;

                -- set expected frame timings for the FSM Simulator module
                xcv_frame_timing.xcv_bit_start <= now;
                xcv_frame_timing.xcv_sample_point <= xcv_ph1_time;
                xcv_frame_timing.xcv_is_jitter_frame <= xcv_jitter_frame_flag;
                
                
                -- Sync with the wake delay of the UUT
                if j = 0 then
                    wait until uut_sleep_o = '0';
                end if;

                wait for xcv_ph1_time;

                -- PHASE 2 --
                
                -- Debugging signal
                xcv_ph1_active <= '0';

                -- Check if TX contains the override value at the sample point
                -- We Cannot check the first one as not TX is queued
                -- We also can't check the last, as the unit switches to sleep after the sample, as intended
                if j < tb_vector_arr(i).override_mask'length - 1 then
                    assert uut_can_tx_o = tb_vector_arr(i).override_mask(j) 
                    report "Missmatch at Output " & integer'image(j) & " in vector " & integer'image(i) & 
                    " expected " & std_logic'image(tb_vector_arr(i).override_mask(j)) & " got " & std_logic'image(uut_can_tx_o)
                    severity failure;
                end if;

                wait for xcv_ph2_time;

            end loop;
            -- Assert that the output equals the input
            wait for clk_period * 2;
            for j in tb_vector_arr(i).rx_signal'range loop
                
                assert fsm_sample_o_history(j) = tb_vector_arr(i).rx_signal(j)
                report "Mismatch at Vector: " & integer'image(i) & 
                    " Index: " & integer'image(j) & 
                    " | Expected: " & to_string(tb_vector_arr(i).rx_signal(j)) & 
                    " | Received: " & to_string(fsm_sample_o_history(j))
                severity failure;
            end loop;
        end loop;


        -- TEST 2: Actor Mode and TDC
        
        wait for clk_period;
        
        -- Provide a static setup
        uut_cfg_en_i <= '1';
        uut_cfg_ph1_len_nomi_i <= 9;
        uut_cfg_ph2_len_nomi_i <= 5;
        uut_cfg_ph1_len_data_i <= 9;
        uut_cfg_ph2_len_data_i <= 5;
        uut_cfg_sjw_nomi_i <= 10;
        uut_cfg_sjw_data_i <= 10;                                    
        uut_cfg_brp_nomi_i <= 8;                                    
        uut_cfg_brp_data_i <= 8;                                    
        uut_cfg_fip_nomi_i <= 4;
        uut_cfg_fip_data_i <= 4;
        uut_cfg_psp_nomi_i <= 2;
        uut_cfg_psp_data_i <= 2;
        wait for clk_period;
        uut_cfg_ssp_i <= uut_cfg_ph1_len_nomi_i + 1; -- = 10
        
        wait for clk_period;
        uut_cfg_en_i <= '0';
        
        test_timing_active <= '1';
        test_2_bit_width := 1 + uut_cfg_ph1_len_nomi_i + uut_cfg_ph2_len_nomi_i; -- = 15
        


        -- EXECUTED FIRST: TDC TEST
        for i in 0 to test_2_bit_width loop
            -- Wait for the TU to leave config mode
            uut_can_rx_i <= '1';
            uut_cfg_en_i <= '0';
            wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period * XCV_IFS_WIDTH;

            xcv_curr_test_vec <= 20 + i;
            fsm_cfg <= '1';
            ou_override_cfg <=  "11101111";
            fsm_fd_speed_cfg <= "01111111";
            fsm_eof_flag_cfg <= "00000001";
            fsm_resync_cfg <= "00000000";
            wait for clk_period;
            fsm_cfg <= '0';
            
            -- SOF
            uut_can_rx_i <= '0';
            wait for clk_period;
            wait until uut_btl_tq_cnt = 0;

            -- BRS 
            uut_can_rx_i <= '1';
            wait for clk_period;
            wait until uut_btl_tq_cnt = 0;

            -- Buffer bit, so we dont resync 
            uut_can_rx_i <= '0';
            wait until uut_btl_tq_cnt = 0;

            -- Override here  
            uut_can_rx_i <= '1';
            wait until uut_btl_tq_cnt = uut_cfg_fip_nomi_i; 
            if i /= 0 then
                wait until uut_btl_tq_cnt = (uut_cfg_fip_nomi_i + i) mod test_2_bit_width; 
            end if;

            uut_can_rx_i <= '0';
            
            wait until uut_sample_strb_o = '1';
            wait for clk_period;
            wait for clk_period;

            -- FIP 
            -- Incooperate a bit delta of 1, as it takes one TQ for the edge to be propagated 
            assert ssp_snapshot_tq = (1 + uut_cfg_fip_nomi_i + i + uut_cfg_ssp_i) mod test_2_bit_width report "SSP does not match the expected TDC" severity failure;
            
            wait until uut_sample_strb_o = '1';
            wait for clk_period;
            wait for clk_period;
            -- FIXME: This assertion cannot work of the delay, because there is no falling edge to which we can resync
            assert ssp_snapshot_tq = (1 + i + uut_cfg_ssp_i) mod test_2_bit_width report "SSP does not match the expected TDC" severity failure; 
            wait for clk_period;
            wait for clk_period;
            uut_cfg_en_i <= '1';
            wait for clk_period;
        end loop;


        -- Wait out the IFS to reset the bus state before the next test
        uut_can_rx_i <= '1';
        uut_can_rx_i <= '1';
        uut_cfg_en_i <= '0';
        wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period * XCV_IFS_WIDTH;

        fsm_cfg <= '1';
        ou_override_cfg <=  "11101111";
        fsm_fd_speed_cfg <= "01111111";
        fsm_eof_flag_cfg <= "00000001";
        fsm_resync_cfg <= "00000000";
        wait for clk_period;
        fsm_cfg <= '0';


        -- EXECUTED SECOND: TQ RESYNC / ACTOR MODE
        for i in 0 to 1 loop
            xcv_curr_test_vec <= 18 + i;
            fsm_cfg <= '1';
            ou_override_cfg <=  "11010101";
            fsm_fd_speed_cfg <= "01111111";
            fsm_eof_flag_cfg <= "00000001";
            fsm_resync_cfg <= "00000000";
            wait for clk_period;
            fsm_cfg <= '0';
            
            wait for clk_period;

            -- BIT 1: SOF 
            uut_can_rx_i <= '0';
            wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period; 
            
            -- BIT 2: Set bit for checking resync
            uut_can_rx_i <= '0' when i = 0 else '1';
            wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period; 
            uut_can_rx_i <= '1';
            wait for (1 + uut_cfg_fip_nomi_i) * uut_cfg_brp_nomi_i * clk_period;

            -- BIT 3: Transition to BRS
            assert uut_btl_tq_cnt = (1 - i) * (uut_cfg_fip_nomi_i) report "TU did not resync on injection" severity failure;

            -- Wait out the remaining 5 bits + buffer for the reset
            wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period * 6;
        end loop;

        -- TEST 3 Check Glitch rejection

        uut_reset_n <= '0';
        wait for clk_period * XCV_RESET_WIDTH;
        uut_reset_n <= '1';
        wait for clk_period * XCV_RESET_WIDTH;

        uut_can_rx_i <= '1';
        wait for test_2_bit_width * uut_cfg_brp_nomi_i * clk_period * XCV_IFS_WIDTH;
        
        uut_can_rx_i <= '0';
        wait for clk_period * 2; 
        
        uut_can_rx_i <= '1';
        
        wait for clk_period * 10; 
        
        assert uut_sleep_o = '1' 
            report "Glitch rejection failed! TU did not return to sleep after a recessive spike." 
            severity failure;

        assert False report "Simulation Finished, no errors" severity failure;

    end process; 

    -- For the second test, we need to test based on the internal state of the TU
    -- This is very hard to do with an external timing, as the FSM is always two clock cycles off due tue to the noise filtering
    test_2_timed_section: process(clk)
        -- Declared per-process: GHDL cannot resolve external names in the
        -- architecture declarative region against a directly instantiated entity.
        alias uut_btl_tq_cnt is << signal .tb_func_timer_unit.uut.btl_tq_cnt_r : integer range 0 to 383 >>;
        alias uut_brs_en is << signal .tb_func_timer_unit.uut.brs_en_r : std_logic >>;
        alias uut_xcvr_mode is << signal .tb_func_timer_unit.uut.xcvr_mode_r : std_logic >>;
    begin
        if rising_edge(clk) then

            -- Confirm that in main actor mode we perform an injection directly at the output
            if uut_btl_tq_cnt = 0 and uut_xcvr_mode = '1' and uut_sleep_o = '0' then
                assert uut_injection_arm_i = not uut_can_tx_o report "Output contains wrong value" severity failure;
            elsif ((uut_btl_tq_cnt = uut_cfg_fip_data_i and uut_brs_en = '1') or (uut_btl_tq_cnt = uut_cfg_fip_nomi_i and uut_brs_en = '0')) and uut_sleep_o = '0' then
                assert uut_injection_arm_i = not uut_can_tx_o report "Output contains wrong value" severity failure;
            end if;
            if uut_sample_strb_o = '1' then
                ssp_snapshot_tq <= uut_btl_tq_cnt;
            end if;

        end if;

    end process;

    -- Simulate the OU response for each bit
    -- Also check if the value currently on the bus agrees with the GT
    sim_ou : process(all)
        variable stored_psp_value : std_logic;
    begin
        if rising_edge(clk) then
            if fsm_cfg = '1' then
                ou_override_sft <= ou_override_cfg;
                uut_xcvr_mode_req_i <= '0';
            else
                if uut_pre_sample_strb_o = '1' then
                    stored_psp_value := uut_pre_sample_o;
                    assert stored_psp_value = uut_can_rx_i report "PSP value does not correspond to the current bus value" severity failure;
                    -- Feed the inverse of the override vector
                    uut_injection_arm_i <= not ou_override_sft(0);
                    ou_override_sft <= ou_override_sft(1 to 7) & '1';
                    if (not ou_override_sft(0)) = '1' and test_timing_active = '1' then
                        -- Placeholder for additions
                        uut_xcvr_mode_req_i <= '1';
                    end if;
                elsif uut_xcvr_mode_req_i = '1'  and uut_xcvr_strb_o = '1' then 
                    uut_injection_arm_i <= not ou_override_sft(0);
                    ou_override_sft <= ou_override_sft(1 to 7) & '0';
                end if;
            end if;
        end if;

    end process;

    -- Runs independent with every clock edge emulating the Parser Units outputs to the TU 
    sim_fsm_response : process(clk)
        -- Variable for keeping the shift position of a test vectors bits
        variable fsm_shift_cnt : integer := 8;

        -- Variables for simulating delay from Parser Pipeline
        variable fsm_delay_active_flag : std_logic := '0';
        variable fsm_delay_cnt : integer := 0;
        variable fsm_delay_max : integer := FSM_DELAY_WIDTH;

        -- Variable to keep memory of BRS / CRC_DEL Bit
        variable fd_mode : std_logic := '0';
    begin

        if fsm_cfg = '1' then
            fsm_eof_flag_sft <= fsm_eof_flag_cfg;
            -- Shifted by 1 to predict the BRS and CRC_DEL Variables
            fsm_fd_speed_sft <= fsm_fd_speed_cfg(1 to 7) & '0';
            fsm_resync_sft   <= fsm_resync_cfg;
            fsm_shift_cnt := 0;
            fsm_brs_state <= '0';
            
            -- Reset the internal FSM flags
            uut_eof_stat_i <= '0';
            
            uut_brs_pend_stat_i <= '0';
            uut_crc_del_pend_stat_i <= '0';
            uut_err_stat_i <= '0';

            uut_hard_resync_req_i <= '0';

        elsif rising_edge(clk) then
            -- Default assignments
            fsm_eof_flag_sft <= fsm_eof_flag_sft;
            fsm_fd_speed_sft <= fsm_fd_speed_sft;
            fsm_resync_sft   <= fsm_resync_sft;

            if uut_reset_n = '0' then
                uut_eof_stat_i <= '0';
                uut_hard_resync_req_i <= '0';
                uut_brs_pend_stat_i <= '0';
                uut_crc_del_pend_stat_i <= '0';
                uut_err_stat_i <= '0';
            elsif uut_sample_strb_o = '1' then
                -- Begin FSM Delay simulation
                fsm_delay_active_flag := '1';
                fsm_delay_cnt := 0;
            end if; 

            -- Only switch after FSM delay has finished
            if fsm_delay_cnt = fsm_delay_max and fsm_delay_active_flag = '1' then
                uut_eof_stat_i <= fsm_eof_flag_sft(0);
                uut_hard_resync_req_i <= fsm_resync_sft(0);
                
                -- Check the current BRS state and switch if needed

                -- Flags are reset after each tick
                uut_brs_pend_stat_i <= '0';
                uut_crc_del_pend_stat_i <= '0';
                uut_err_stat_i <= '0';
               
                -- brs_trans denotes, if this is the transitional bit where we switch from NOMI -> DATA
                -- in the middle of the bit
                if fsm_brs_state = '0' and fsm_fd_speed_sft(0) = '1' then
                    uut_brs_pend_stat_i <= '1';
                    fsm_brs_state <= '1';
                end if;
                
                if fsm_brs_state = '1' and fsm_fd_speed_sft(0) = '0' then
                    uut_crc_del_pend_stat_i <= '1';
                    fsm_brs_state <= '0';
                end if;
                

                fsm_eof_flag_sft <= fsm_eof_flag_sft(1 to 7) & '0';
                fsm_fd_speed_sft <= fsm_fd_speed_sft(1 to 7) & '0';
                fsm_resync_sft   <= fsm_resync_sft(1 to 7) & '0';
                fsm_shift_cnt := fsm_shift_cnt + 1;
                -- Load the output history as part of the fsm process so it is in sync with the FSM
                -- However, the final output should be checked in the main transceiver process;
                fsm_sample_o_history <= fsm_sample_o_history(1 to 7) & uut_sample_o;

                fsm_delay_active_flag := '0';

            elsif fsm_delay_active_flag = '1' then
                fsm_delay_cnt := fsm_delay_cnt + 1;
            end if;

            assert fsm_shift_cnt < 9 report "FSM Shift to Frame length mismatch" severity failure;
        end if;
    end process;



    -- Captures the positions in which the seperate sample + inj have been captured and asserts them 
    check_bit_timings : process(all)
        -- Declared per-process: GHDL cannot resolve external names in the
        -- architecture declarative region against a directly instantiated entity.
        alias uut_btl_tq_cnt is << signal .tb_func_timer_unit.uut.btl_tq_cnt_r : integer range 0 to 383 >>;
        alias uut_brs_en is << signal .tb_func_timer_unit.uut.brs_en_r : std_logic >>;
        alias uut_xcvr_mode is << signal .tb_func_timer_unit.uut.xcvr_mode_r : std_logic >>;
    begin
        if rising_edge(clk) and uut_sleep_o = '0' then


            -- Store the BRS state of the TU before the 
            if uut_btl_tq_cnt = 0 then
                brs_prev <= uut_brs_en;
            end if;
            
            if xcv_curr_test_vec /= 11 and xcv_curr_test_vec < 13 then 
                if uut_xcvr_mode_req_i = '1' then
                    -- Placeholder for SSP and Alt. FIP isnertion
                elsif brs_prev = '1' then 
                    if uut_pre_sample_strb_o = '1' then
                        assert uut_btl_tq_cnt = uut_cfg_psp_data_i report "PSP position does not match with setting" severity failure; 
                    end if;
                    if uut_sample_strb_o = '1' then
                        assert uut_btl_tq_cnt = 1 + uut_cfg_ph1_len_data_i report "SP position does not match with setting" severity failure; 
                    end if;


                    -- Injection point bounds checking
                    
                    -- At the new bit, we want the TX line to stay clear
                    if uut_btl_tq_cnt = 0 then
                        assert uut_can_tx_o = '1' report "TX not recessive at new bit" severity failure;
                    end if;
                    if uut_btl_tq_cnt = uut_cfg_fip_nomi_i then
                        assert uut_can_tx_o = not uut_injection_arm_i report "TX not dominiat at injection point" severity failure;
                    end if;
                else
                    if uut_pre_sample_strb_o = '1' then
                        assert uut_btl_tq_cnt = uut_cfg_psp_nomi_i report "PSP position does not match with SP" severity failure; 
                    end if;
                    if uut_sample_strb_o = '1' then
                        assert uut_btl_tq_cnt = 1 + uut_cfg_ph1_len_nomi_i report "SP position does not match with Setting" severity failure; 
                    end if;


                    -- Injection point bounds checking
                    
                    -- At the new bit, we want the TX line to stay clear
                    -- We cannot really test vector 11 here, as due to high jitter it is unpredictable
                    -- For 13 onwards we reach the clk frequency ceiling for overrides
                    if uut_btl_tq_cnt = 0 then
                        assert uut_can_tx_o = '1' report "TX not recessive at new bit" severity failure;
                    end if;
                    if uut_btl_tq_cnt = uut_cfg_fip_nomi_i then
                        assert uut_can_tx_o = not uut_injection_arm_i report "TX not dominiat at injection point" severity failure;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    


    -- Check how much the sample point drifts from the ground truth signal
    -- For this we get tge sample_o and subtract the propagation time for the CAN RX signal to arrive at the TUs BTL
    -- We do this because, technically we are still sampling the signal earlier, but due to the metastability gate it arrives later 

    -- Hold the timing_frame from the transport delay of the TU, so we dont accidentally compare the SP of N with N+1 at tight prscaler settings
    fsm_frame_timing_hold <= transport xcv_frame_timing after TU_PROP_DELAY_LENGTH * clk_period;

    sim_sample_point_capture : process
        variable phe_sp_uut_time : time;
        variable phe_phase_err : real; 
    begin
        wait until rising_edge(uut_sample_strb_o);
        -- Relative TU sample point to GT Bit
        -- Subtract propagation time (Metastability/2 + edge detection/1 + sample_strobe_set/1)
        phe_sp_uut_time := now - fsm_frame_timing_hold.xcv_bit_start - clk_period * TU_PROP_DELAY_LENGTH;
        phe_phase_err := real((phe_sp_uut_time - fsm_frame_timing_hold.xcv_sample_point) / 1 ps) / real(clk_period / 1 ps);

        -- Calculate relative margin depending on the bit width

        report "XCV Sample Point: " & time'image(fsm_frame_timing_hold.xcv_sample_point) & " UUT Sample Point " & time'image(phe_sp_uut_time) & " Offset in cycles: " & real'image(phe_phase_err);
        if fsm_frame_timing_hold.xcv_is_jitter_frame = '0' then
            assert abs(phe_phase_err) < MAX_PHASE_ERR report "Sample point drift higher than 5 cycles" severity warning;
        end if;
    end process;

end Behavioral;