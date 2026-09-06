
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.sys_config_pkg.all;

use work.reference_data_set_1.all;
use work.reference_data_set_2.all;
use work.reference_data_set_3.all;
use work.reference_data_set_4.all;
use work.reference_data_set_5.all;
use work.reference_data_set_6.all;
use work.reference_data_set_7.all;
use work.reference_data_set_8.all;
use work.reference_data_set_9.all;
use work.reference_data_set_10.all;
use work.tb_ref_defs.all;


use IEEE.NUMERIC_STD.ALL;


entity tb_ref is
end tb_ref;

architecture Behavioral of tb_ref is

    -- UUT --

    -- AXI Signals
    signal clk : std_logic;
    signal reset_n : std_logic;

    -- TU IO
    signal uut_can_rx_i : STD_LOGIC := '0';
    signal uut_cfg_ph1_len_nomi_i : INTEGER range TSEG1_MIN to TSEG1_MAX;
    signal uut_cfg_ph2_len_nomi_i : INTEGER range TSEG2_MIN to TSEG2_MAX;
    signal uut_cfg_ph1_len_data_i : INTEGER range TSEG1_MIN to TSEG1_MAX;
    signal uut_cfg_ph2_len_data_i : INTEGER range TSEG2_MIN to TSEG2_MAX;
    signal uut_cfg_sjw_nomi_i     : INTEGER range SJW_MIN to SJW_MAX;
    signal uut_cfg_sjw_data_i     : INTEGER range SJW_MIN to SJW_MAX;
    signal uut_cfg_psp_nomi_i     : INTEGER range PSP_MIN to PSP_MAX;
    signal uut_cfg_psp_data_i     : INTEGER range PSP_MIN to PSP_MAX;
    signal uut_cfg_fip_nomi_i     : INTEGER range FIP_MIN to FIP_MAX;
    signal uut_cfg_fip_data_i     : INTEGER range FIP_MIN to FIP_MAX;
    signal uut_cfg_brp_nomi_i     : INTEGER range BRP_MIN to BRP_MAX;
    signal uut_cfg_brp_data_i     : INTEGER range BRP_MIN to BRP_MAX;
    signal uut_cfg_ssp_i : integer range SSP_MIN to SSP_MAX;
    signal uut_cfg_en_i : STD_LOGIC;
    signal uut_cfg_ready_o : STD_LOGIC;
    signal uut_cfg_td_en_i : std_logic; 
    signal uut_injection_arm_i : std_logic := '0';
    signal uut_xcvr_mode_req_i : std_logic := '0';
    signal uut_xcvr_strb_o : std_logic;
    signal uut_pre_sample_o : std_logic; 
    signal uut_pre_sample_strb_o : std_logic; 



    -- TU <-> Parser IO
    signal uut_eof_stat_io : STD_LOGIC := '0';
    signal uut_brs_pend_stat_io : STD_LOGIC := '0';
    signal uut_crc_del_pend_stat_io : STD_LOGIC := '0';
    signal uut_err_stat_io : STD_LOGIC := '0';
    signal uut_hard_resync_req_io : STD_LOGIC := '0';
    signal uut_sample_io : STD_LOGIC := '0';
    signal uut_can_tx_o : STD_LOGIC := '0';
    signal uut_sample_strb_io : STD_LOGIC := '0';
    signal uut_parser_flags_valid_io : STD_LOGIC := '0';
    signal uut_sleep_io : STD_LOGIC;
    
    -- Parser IO
    signal uut_error_inj_stat_o : STD_LOGIC := '0'; 
    signal uut_ctrl_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal uut_data_buffer : STD_LOGIC_VECTOR (511 downto 0);
    signal uut_crc_stf_buffer : STD_LOGIC_VECTOR (3 downto 0);
    signal uut_crc_buffer : STD_LOGIC_VECTOR (20 downto 0);
    signal uut_id_buffer : STD_LOGIC_VECTOR (28 downto 0);
    signal uut_dlc_buffer : STD_LOGIC_VECTOR (3 downto 0);


    -- Config frame
    type t_core_cfg is record
        ph1_len_nomi : INTEGER range TSEG1_MIN to TSEG1_MAX;
        ph2_len_nomi : INTEGER range TSEG2_MIN to TSEG2_MAX;
        ph1_len_data : INTEGER range TSEG1_MIN to TSEG1_MAX;
        ph2_len_data : INTEGER range TSEG2_MIN to TSEG2_MAX;
        sjw_nomi     : INTEGER range SJW_MIN to SJW_MAX;
        sjw_data     : INTEGER range SJW_MIN to SJW_MAX;
        brp_nomi     : INTEGER range BRP_MIN to BRP_MAX;
        brp_data     : INTEGER range BRP_MIN to BRP_MAX;
    end record;

    -- Test Vector Metadata --

    type t_can_frame_ref is record
        cfg : t_core_cfg;
        id : std_logic_vector(28 downto 0);
        dlc : std_logic_vector(3 downto 0);
        ctrl : std_logic_vector(3 downto 0); -- fdf(0) & r1(0) & brs(0) & esi(0)
        data : std_logic_vector(511 downto 0);
        crc_stf : std_logic_vector(3 downto 0);
        crc : std_logic_vector(20 downto 0);
        raw_frame_seq : t_can_seq;
        raw_frame_len : integer;
        is_ctu_frame : std_logic;
    end record;

    -- Combine each reference test file into a single array
    type t_ctu_ref_vecs is array (0 to 9) of t_reference_data_set;

    constant CTU_REF_VECS : t_ctu_ref_vecs := (
        0 => C_reference_data_set_1,
        1 => C_reference_data_set_2,
        2 => C_reference_data_set_3,
        3 => C_reference_data_set_4,
        4 => C_reference_data_set_5,
        5 => C_reference_data_set_6,
        6 => C_reference_data_set_7,
        7 => C_reference_data_set_8,
        8 => C_reference_data_set_9,
        9 => C_reference_data_set_10
    );

    -- Convert the CTU CAN FD Reference Test vectors to our format
    -- Assumes 80 MHz Freq
    function ctu_conv(ctu_item : t_reference_item) return t_can_frame_ref is 
        variable v : t_can_frame_ref;
        variable f : t_ctu_frame;
    begin
        f := ctu_item.frame;
        v.id := std_logic_vector(to_unsigned(f.identifier, v.id'length));
        v.dlc := f.dlc;
        v.ctrl := f.frame_format & '0' & f.brs & f.esi;

        
        v.data := (others => '0');
        for k in 0 to f.data_length - 1 loop
            v.data( ((f.data_length - k) * 8 - 1) downto ((f.data_length - k - 1) * 8) ) := f.data(k);
        end loop;

        v.raw_frame_seq := ctu_item.seq;
        v.raw_frame_len := ctu_item.seq_len;

        -- The Reference vectors use the following settings:
        -- 500 Kbps for Nominal, 2Mbps for Data
        -- Sample point at 80%

        -- 500 Kbps -> T_bit = 2µs -> brp = 160 -> /10 TQ -> 16
        -- 2Mbps -> T_bit = 500ns -> brp = 40 -> /2 TQ -> 20

        v.cfg.brp_nomi := 10;
        v.cfg.brp_data := 2;

        v.cfg.ph1_len_nomi := 11;
        v.cfg.ph2_len_nomi := 4;

        v.cfg.ph1_len_data := 15;
        v.cfg.ph2_len_data := 4;

        v.cfg.sjw_nomi := 5;
        v.cfg.sjw_data := 2;

        -- The CTU Frames do not have a GT CRC and CRC STF Comparison
        -- We keep them empty and ignore them in the TB

        v.crc_stf := (others => '0');
        v.crc := (others => '0');

        v.is_ctu_frame := '1';

        return v;
    end function;

    -- TB Signals & Constants --

    signal curr_test_vec : integer := 0;

    -- Testing @ 80 MHz
    constant CLK_PERIOD : time := 12.5 ns;

    type t_uut_buffer_frame is record
        ctrl_buffer : STD_LOGIC_VECTOR (3 downto 0);
        data_buffer : STD_LOGIC_VECTOR (511 downto 0);
        crc_stf_buffer : STD_LOGIC_VECTOR (3 downto 0);
        crc_buffer : STD_LOGIC_VECTOR (20 downto 0);
        id_buffer : STD_LOGIC_VECTOR (28 downto 0);
        dlc_buffer : STD_LOGIC_VECTOR (3 downto 0);
    end record;

    signal buffer_snapshot : t_uut_buffer_frame;

begin
    -- Instantiation of the Timer Unit
    TU_INST : entity work.timer_unit
    port map (
        clk                  => clk,
        reset_n              => reset_n,
        can_rx_i             => uut_can_rx_i,
        can_tx_o             => uut_can_tx_o,
        eof_stat_i           => uut_eof_stat_io,
        brs_pend_stat_i => uut_brs_pend_stat_io,
        crc_del_pend_stat_i => uut_crc_del_pend_stat_io,
        err_stat_i => uut_err_stat_io,
        hard_sync_req_i    => uut_hard_resync_req_io,
        sample_o             => uut_sample_io,
        sample_strb_o        => uut_sample_strb_io,
        cfg_ph1_len_nomi_i   => uut_cfg_ph1_len_nomi_i,
        cfg_ph2_len_nomi_i   => uut_cfg_ph2_len_nomi_i,
        cfg_ph1_len_data_i   => uut_cfg_ph1_len_data_i,
        cfg_ph2_len_data_i   => uut_cfg_ph2_len_data_i,
        cfg_sjw_nomi_i       => uut_cfg_sjw_nomi_i,
        cfg_sjw_data_i       => uut_cfg_sjw_data_i,
        cfg_psp_nomi_i       => uut_cfg_psp_nomi_i,
        cfg_psp_data_i       => uut_cfg_psp_data_i,
        cfg_fip_nomi_i       => uut_cfg_fip_nomi_i,
        cfg_fip_data_i       => uut_cfg_fip_data_i,
        cfg_brp_nomi_i       => uut_cfg_brp_nomi_i,
        cfg_brp_data_i       => uut_cfg_brp_data_i,
        cfg_ssp_i            => uut_cfg_ssp_i, 
        cfg_td_en_i          => uut_cfg_td_en_i,
        sleep_o              => uut_sleep_io,
        cfg_en_i             => uut_cfg_en_i,
        cfg_ready_o          => uut_cfg_ready_o,
        injection_arm_i      => uut_injection_arm_i, 
        xcvr_mode_req_i      => uut_xcvr_mode_req_i,
        xcvr_strb_o          => uut_xcvr_strb_o,
        pre_sample_o         => uut_pre_sample_o,
        pre_sample_strb_o    => uut_pre_sample_strb_o 
    );

    -- Instantiation of the CAN FSM (Parser)
    FSM_INST : entity work.can_fsm
    port map (
        clk                  => clk,
        reset_n              => reset_n,
        sample_i             => uut_sample_io,
        sample_strb_i        => uut_sample_strb_io,
        eof_stat_o           => uut_eof_stat_io,
        brs_pend_stat_o => uut_brs_pend_stat_io,
        crc_del_pend_stat_o => uut_crc_del_pend_stat_io,
        err_stat_o => uut_err_stat_io, 
        hard_sync_req_o      => uut_hard_resync_req_io,
        sleep_i              => uut_sleep_io,
        
        -- Debug/Spy Ports
        tb_ctrl_buffer_o     => uut_ctrl_buffer,
        tb_data_buffer_o     => uut_data_buffer,
        tb_crc_stf_buffer_o  => uut_crc_stf_buffer,
        tb_crc_buffer_o      => uut_crc_buffer,
        tb_id_buffer_o       => uut_id_buffer,
        tb_dlc_buffer_o      => uut_dlc_buffer
    );


    
    clk_process : process
    begin 
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;


    -- Check if the FSM has reached an EOF
    -- and copy the buffers to the Test.
    -- This is needed, because all buffers reset on sleep
    take_buffer_snapshot : process(clk)
    begin
        if rising_edge(clk) then
            if uut_eof_stat_io ='1' then
                buffer_snapshot.ctrl_buffer    <= uut_ctrl_buffer;
                buffer_snapshot.data_buffer    <= uut_data_buffer;
                buffer_snapshot.crc_stf_buffer <= uut_crc_stf_buffer;
                buffer_snapshot.crc_buffer     <= uut_crc_buffer;
                buffer_snapshot.id_buffer      <= uut_id_buffer;
                buffer_snapshot.dlc_buffer     <= uut_dlc_buffer;
            end if;

        end if;
    end process;


    ref_test : process
        variable frame_i : t_can_frame_ref;
        constant XCV_CFG_WIDTH : integer := 12;
        constant XCV_IFS_WIDTH : integer := 12;
        constant XCV_RESET_WIDTH : integer := 4;
    begin

        uut_can_rx_i <= '1';

        reset_n <= '0';
        wait for clk_period * XCV_RESET_WIDTH;
        reset_n <= '1';
        wait for clk_period * XCV_RESET_WIDTH;

        for test_set_idx in CTU_REF_VECS'range loop
            for i in CTU_REF_VECS(test_set_idx)'range loop

                curr_test_vec <= i;

                uut_can_rx_i <= '1';

                frame_i := ctu_conv(CTU_REF_VECS(test_set_idx)(i));
                
                assert uut_cfg_ready_o = '1' report "Unit is not config ready after sleep" severity failure;
                
                uut_cfg_en_i <= '1';
                uut_cfg_ph1_len_nomi_i <= frame_i.cfg.ph1_len_nomi;
                uut_cfg_ph2_len_nomi_i <= frame_i.cfg.ph2_len_nomi;
                uut_cfg_ph1_len_data_i <= frame_i.cfg.ph1_len_data;
                uut_cfg_ph2_len_data_i <= frame_i.cfg.ph2_len_data;
                uut_cfg_sjw_nomi_i <= frame_i.cfg.sjw_nomi;
                uut_cfg_sjw_data_i <= frame_i.cfg.sjw_data;
                uut_cfg_brp_nomi_i <= frame_i.cfg.brp_nomi;
                uut_cfg_brp_data_i <= frame_i.cfg.brp_data;
                uut_cfg_td_en_i <= '1';
                
                wait for CLK_PERIOD * XCV_CFG_WIDTH;

                uut_cfg_en_i <= '0';

                wait for CLK_PERIOD * XCV_IFS_WIDTH * frame_i.cfg.brp_nomi * (1 + frame_i.cfg.ph1_len_nomi + frame_i.cfg.ph2_len_nomi);

                assert uut_cfg_ready_o = '1' report "Unit is not config ready after IFS" severity failure;


                for j in 1 to frame_i.raw_frame_len loop
                    uut_can_rx_i <= frame_i.raw_frame_seq(j).value;
                    wait for frame_i.raw_frame_seq(j).drive_time;
                end loop;

                -- 1. Check ID
                assert buffer_snapshot.id_buffer = frame_i.id 
                    report "Test Vector " & integer'image(i) & " Failed: ID Mismatch." 
                    & " GT: "  & to_string(frame_i.id) & " is: " & to_string(buffer_snapshot.id_buffer)
                    severity failure;

                -- 2. Check Control (CTRL)
                assert buffer_snapshot.ctrl_buffer = frame_i.ctrl 
                    report "Test Vector " & integer'image(i) & " Failed: CTRL Mismatch." 
                    & " GT: "  & to_string(frame_i.ctrl) & " is: " & to_string(buffer_snapshot.ctrl_buffer)
                    severity failure;

                -- 3. Check DLC
                assert buffer_snapshot.dlc_buffer = frame_i.dlc 
                    report "Test Vector " & integer'image(i) & " Failed: DLC Mismatch." 
                    & " GT: "  & to_string(frame_i.dlc) & " is: " & to_string(buffer_snapshot.dlc_buffer)
                    severity failure;

                -- 4. Check Data
                -- We do this in a loop, as data is too large to be debugged directly
                if (buffer_snapshot.data_buffer /= frame_i.data) then
                    for j in frame_i.data'range loop
                        assert buffer_snapshot.data_buffer(j) = frame_i.data(j) 
                        report "Test Vector " & integer'image(i) & " Failed: DATA Mismatch at IDX: " & integer'image(j) 
                        & LF & "Expected " & to_string(frame_i.data(j)) & " got " & to_string(buffer_snapshot.data_buffer(j))
                        & LF & "GT: "  & to_hex_string(frame_i.data) & " is: " & to_hex_string(buffer_snapshot.data_buffer)
                        severity failure;
                    end loop;
                end if;

                
                
                -- CTU Frames dont have CRC and STF
                if frame_i.is_ctu_frame = '0' then
                    -- 5. Check CRC Stuff Count (CRC_STF)
                    assert buffer_snapshot.crc_stf_buffer = frame_i.crc_stf 
                        report "Test Vector " & integer'image(i) & " Failed: CRC_STF Mismatch." 
                        & " GT: "  & to_string(frame_i.crc_stf) & " is: " & to_string(buffer_snapshot.crc_stf_buffer)
                        severity failure;

                    -- 6. Check CRC
                    assert uut_crc_buffer = frame_i.crc 
                        report "Test Vector " & integer'image(i) & " Failed: CRC Mismatch." 
                        & " GT: "  & to_string(frame_i.crc) & " is: " & to_string(buffer_snapshot.crc_buffer)
                        severity failure;
                end if;
                    
                -- Optional success message for the specific vector
                report "Test Vector " & integer'image(i) & " of set " & integer'image(test_set_idx) &" Complete." severity note;

                
            end loop;
        end loop;
        assert False report "Test finished" severity failure;

    end process;


end Behavioral;