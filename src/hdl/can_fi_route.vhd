library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all; 
use ieee.fixed_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.sys_config_pkg.all;

use work.can_fd_fi_regs_pkg.all;
use work.can_fd_fi_register_record_pkg.all;

entity can_fi_route is
    Port (
        clk              : in  std_ulogic;
        reset_n          : in  std_logic;
        regs_m2s         : in  axi_lite_m2s_t;
        regs_s2m         : out axi_lite_s2m_t;
        port_can_rx      : in  std_logic;
        port_can_tx      : out std_logic;
        port_irq         : out std_logic;
        port_inj_trigger : out std_logic;
        port_frame_start : out std_logic;
        port_frame_end   : out std_logic
    );
end can_fi_route;

architecture Behavioral of can_fi_route is

    -- Top-Level Signals 
    signal regs_up_r       : can_fd_fi_regs_up_t        := can_fd_fi_regs_up_init;
    signal regs_up         : can_fd_fi_regs_up_t        := can_fd_fi_regs_up_init;
    signal regs_down       : can_fd_fi_regs_down_t      := can_fd_fi_regs_down_init;
    signal reg_was_written : can_fd_fi_reg_was_written_t := can_fd_fi_reg_was_written_init;
    signal reg_was_read    : can_fd_fi_reg_was_read_t   := can_fd_fi_reg_was_read_init;

    signal test_signal_r : std_logic;
    signal test_signal   : std_logic;

    signal axi_id_mem_arr_o : id_mem_arr_t(0 to ID_MEM_ENTRY_COUNT - 1);


    -- AXI Signals Config Inputs
    signal axi_cfg_ph1_len_nomi_o : INTEGER;
    signal axi_cfg_ph2_len_nomi_o : INTEGER;
    signal axi_cfg_ph1_len_data_o : INTEGER;
    signal axi_cfg_ph2_len_data_o : INTEGER;
    signal axi_cfg_sjw_nomi_o     : integer;
    signal axi_cfg_sjw_data_o     : integer;
    signal axi_cfg_brp_nomi_o     : integer;
    signal axi_cfg_brp_data_o     : integer;
    signal axi_cfg_psp_nomi_o     : integer;
    signal axi_cfg_psp_data_o     : integer;
    signal axi_cfg_fip_nomi_o     : integer;
    signal axi_cfg_fip_data_o     : integer;
    signal axi_cfg_ssp_o          : integer;
    signal axi_data_valid_o       : std_logic;
    signal axi_data_addr_o        : std_logic_vector(14 downto 0);
    signal axi_data_payload_o     : std_logic_vector(31 downto 0);
    signal axi_data_strobe_o      : std_logic;
    signal axi_cfg_td_en_o        : std_logic;

    signal axi_interrupt_resp_o : std_logic;

    -- TU Timer Unit Signals
    signal axi_cfg_en_o : std_logic;
    signal tu_cfg_ready_o               : STD_LOGIC;
    signal tu_sample_o                  : STD_LOGIC;
    signal tu_sample_strb_o             : STD_LOGIC;
    signal tu_sleep_o                   : STD_LOGIC;
    signal tu_xcvr_strb_o               : STD_LOGIC;
    signal tu_pre_sample_point_o        : STD_LOGIC;
    signal tu_pre_sample_point_strobe_o : std_logic;
    signal tu_fip_strb_o                : std_logic;

    -- Parser Unit Signals
    signal fsm_eof_stat_o          : STD_LOGIC;
    signal fsm_brs_pend_stat_o     : STD_LOGIC;
    signal fsm_crc_del_pend_stat_o : STD_LOGIC;
    signal fsm_err_stat_o          : STD_LOGIC;
    signal fsm_hard_sync_req_o     : STD_LOGIC;
    
    -- synthesis translate_off
    signal fsm_tb_ctrl_buffer_o    : STD_LOGIC_VECTOR(31 downto 0);
    signal fsm_tb_data_buffer_o    : STD_LOGIC_VECTOR(31 downto 0);
    signal fsm_tb_crc_stf_buffer_o : STD_LOGIC_VECTOR(31 downto 0);
    signal fsm_tb_crc_buffer_o     : STD_LOGIC_VECTOR(31 downto 0);
    signal fsm_tb_dlc_buffer_o     : STD_LOGIC_VECTOR(31 downto 0);
    signal fsm_tb_id_buffer_o      : STD_LOGIC_VECTOR(31 downto 0);
    -- synthesis translate_on
    
    signal fsm_id_buffer_o         : STD_LOGIC_VECTOR(28 downto 0);
    signal fsm_id_ready_o          : STD_LOGIC;
    signal fsm_sample_buff_ready_o : STD_LOGIC;
    signal fsm_sample_buff_o       : STD_LOGIC;
    signal fsm_state_o             : fsm_state_types;
    signal fsm_cnt_o               : integer range 0 to 512;
    signal fsm_dlc_buffer_o        : std_logic_vector(3 downto 0);
    signal fsm_dlc_ready_o         : std_logic;
    signal fsm_bs_insert_o         : std_logic;
    signal fsm_fd_mode_o           : std_logic;
    signal fsm_data_width_o        : integer range 0 to 512;
    signal fsm_destuff_strobe_o    : std_logic;
    signal fsm_bs_insert_dynamic_o : std_logic;
    signal fsm_bs_shift_o          : std_logic_vector(4 downto 0);
    signal fsm_bs_state_o          : bs_state_types;
    signal fsm_bs_crc_cnt_o        : integer;
    signal fsm_crc_width_o         : integer;
    signal fsm_bs_crc_mode_o       : std_logic;


    -- Memory Unit Signals
    -- synthesis translate_off
    signal mu_tb_is_match_o  : std_logic;
    signal mu_tb_match_idx_o : integer;
    -- synthesis translate_on

    signal mu_ram_write_err_flag_o : std_logic;
    signal mu_fi_frame_o           : fi_frame_t;
    signal mu_fi_frame_ready_o     : std_logic;
    signal mu_data_vector_ready_o  : std_logic;
    signal mu_data_override_o      : std_logic_vector(575 downto 0);
    signal mu_interrupt_o          : std_logic;


    -- Override Unit Signals
    signal ou_interrupt_req_o : std_logic;
    signal ou_inj_err_miss_o  : std_logic;
    signal ou_inj_err_dom_o   : std_logic;
    signal ou_inj_err_dlc_o   : std_logic;
    signal ou_inj_err_fsm_o   : std_logic;
    signal ou_inj_pending_o   : std_logic;
    signal ou_injection_arm_o : std_logic;
    signal ou_xcvr_mode_req_o : std_logic;

    -- ==========================================
    -- XXX DEBUG XXX
    -- ==========================================
    attribute mark_debug : string;
    signal dbg_id_buffer_o   : std_logic_vector(31 downto 0);
    signal dbg_data_buffer_o : STD_LOGIC_VECTOR(31 downto 0);
    signal dbg_ctrl_buffer_o : STD_LOGIC_VECTOR(31 downto 0);
    signal dbg_crc_buffer_o  : STD_LOGIC_VECTOR(31 downto 0);

    signal id_mask_zero  : std_logic_vector(28 downto 0);
    signal id_val_zero   : std_logic_vector(28 downto 0);
    signal fi_type_zero  : fi_type_t;
    signal fi_field_zero : std_logic_vector(2 downto 0);
    signal fi_meta_zero  : std_logic_vector(8 downto 0);

    --attribute mark_debug of dbg_id_buffer_o, dbg_ctrl_buffer_o, dbg_data_buffer_o, id_val_zero, id_mask_zero, ou_inj_err_miss_o, ou_inj_err_dom_o, ou_inj_err_dlc_o, ou_inj_err_fsm_o, axi_data_payload_o, axi_data_addr_o, axi_data_valid_o: signal is "true";
        
begin
    -- BTL & Timer Unit
    id_mask_zero  <= axi_id_mem_arr_o(0).id_mask;
    id_val_zero   <= axi_id_mem_arr_o(0).id_value;
    fi_type_zero  <= axi_id_mem_arr_o(0).fi_frame.fi_type;
    fi_field_zero <= axi_id_mem_arr_o(0).fi_frame.fi_field;
    fi_meta_zero  <= axi_id_mem_arr_o(0).fi_frame.fi_meta;

    timer_unit_inst : entity work.timer_unit
        port map (
            clk                 => clk,
            reset_n             => reset_n,
            cfg_ph1_len_nomi_i  => axi_cfg_ph1_len_nomi_o,
            cfg_ph2_len_nomi_i  => axi_cfg_ph2_len_nomi_o,
            cfg_ph1_len_data_i  => axi_cfg_ph1_len_data_o,
            cfg_ph2_len_data_i  => axi_cfg_ph2_len_data_o,
            cfg_sjw_nomi_i      => axi_cfg_sjw_nomi_o,
            cfg_sjw_data_i      => axi_cfg_sjw_data_o,
            cfg_brp_nomi_i      => axi_cfg_brp_nomi_o,
            cfg_brp_data_i      => axi_cfg_brp_data_o,
            cfg_psp_nomi_i      => axi_cfg_psp_nomi_o,
            cfg_psp_data_i      => axi_cfg_psp_data_o,
            cfg_fip_nomi_i      => axi_cfg_fip_nomi_o,
            cfg_fip_data_i      => axi_cfg_fip_data_o,
            cfg_ssp_i           => axi_cfg_ssp_o,
            cfg_td_en_i         => axi_cfg_td_en_o,
            cfg_en_i            => axi_cfg_en_o,
            can_rx_i            => port_can_rx,
            eof_stat_i          => fsm_eof_stat_o,
            brs_pend_stat_i     => fsm_brs_pend_stat_o,
            crc_del_pend_stat_i => fsm_crc_del_pend_stat_o,
            err_stat_i          => fsm_err_stat_o,
            hard_sync_req_i     => fsm_hard_sync_req_o,
            injection_arm_i     => ou_injection_arm_o,
            xcvr_mode_req_i     => ou_xcvr_mode_req_o,
            cfg_ready_o         => tu_cfg_ready_o,
            can_tx_o            => port_can_tx,
            sample_o            => tu_sample_o,
            sample_strb_o       => tu_sample_strb_o,
            sleep_o             => tu_sleep_o,
            xcvr_strb_o         => tu_xcvr_strb_o,
            pre_sample_o        => tu_pre_sample_point_o,
            pre_sample_strb_o   => tu_pre_sample_point_strobe_o,
            fip_strb_o          => tu_fip_strb_o,
            injection_trigger_o => port_inj_trigger 
        );

    -- Parsing & Destuffer
    can_fsm_inst : entity work.can_fsm
        port map (
            -- synthesis translate_off
            tb_ctrl_buffer_o    => fsm_tb_ctrl_buffer_o,
            tb_data_buffer_o    => fsm_tb_data_buffer_o,
            tb_crc_stf_buffer_o => fsm_tb_crc_stf_buffer_o,
            tb_crc_buffer_o     => fsm_tb_crc_buffer_o,
            tb_dlc_buffer_o     => fsm_tb_dlc_buffer_o,
            tb_id_buffer_o      => fsm_tb_id_buffer_o,
            -- synthesis translate_on
            dbg_id_buffer_o     => dbg_id_buffer_o,
            dbg_ctrl_buffer_o   => dbg_ctrl_buffer_o,
            dbg_data_buffer_o   => dbg_data_buffer_o,
            dbg_crc_buffer_o    => dbg_crc_buffer_o,
            clk                 => clk,
            reset_n             => reset_n,
            sample_i            => tu_sample_o,
            sample_strb_i       => tu_sample_strb_o,
            sleep_i             => tu_sleep_o,
            eof_stat_o          => fsm_eof_stat_o,
            brs_pend_stat_o     => fsm_brs_pend_stat_o,
            crc_del_pend_stat_o => fsm_crc_del_pend_stat_o,
            err_stat_o          => fsm_err_stat_o,
            hard_sync_req_o     => fsm_hard_sync_req_o,
            sample_buff_ready_o => fsm_sample_buff_ready_o,
            sample_buff_o       => fsm_sample_buff_o,
            fsm_state_o         => fsm_state_o,
            fsm_cnt_o           => fsm_cnt_o,
            dlc_buffer_o        => fsm_dlc_buffer_o,
            dlc_ready_o         => fsm_dlc_ready_o,
            id_buffer_o         => fsm_id_buffer_o,
            id_ready_o          => fsm_id_ready_o,
            bs_insert_o         => fsm_bs_insert_o,
            bs_shift_o          => fsm_bs_shift_o,
            bs_state_o          => fsm_bs_state_o,
            bs_crc_cnt_o        => fsm_bs_crc_cnt_o,
            fd_mode_o           => fsm_fd_mode_o,
            data_width_o        => fsm_data_width_o,
            crc_width_o         => fsm_crc_width_o,
            destuff_strobe_o    => fsm_destuff_strobe_o,
            bs_insert_dynamic_o => fsm_bs_insert_dynamic_o,
            bs_crc_mode_o       => fsm_bs_crc_mode_o
        );

    -- Memory Unit
    memory_unit_inst : entity work.memory_unit
        generic map (
            ID_MEM_ENTRY_COUNT => ID_MEM_ENTRY_COUNT
        )
        port map (
            -- synthesis translate_off
            tb_is_match_o        => mu_tb_is_match_o,
            tb_match_idx_o       => mu_tb_match_idx_o,
            -- synthesis translate_on
            clk                  => clk,
            reset_n              => reset_n,
            sleep_i              => tu_sleep_o,
            cfg_en_i             => axi_cfg_en_o,
            axi_id_mem_arr_i     => axi_id_mem_arr_o,
            bus_id_buffer_i      => fsm_id_buffer_o,
            bus_id_buffer_ready_i => fsm_id_ready_o,
            axi_data_valid_i     => axi_data_valid_o,
            axi_data_addr_i      => axi_data_addr_o,
            axi_data_payload_i   => axi_data_payload_o,
            axi_data_strobe_i    => axi_data_strobe_o,
            interrupt_req_i      => ou_interrupt_req_o,
            axi_interrupt_resp_i => axi_interrupt_resp_o,
            ram_write_err_flag_o => mu_ram_write_err_flag_o,
            fi_frame_o           => mu_fi_frame_o,
            fi_frame_ready_o     => mu_fi_frame_ready_o,
            data_vector_ready_o  => mu_data_vector_ready_o,
            data_override_o      => mu_data_override_o,
            interrupt_o          => port_irq
        );

    --- Override Unit ---
    override_unit_inst : entity work.override_unit
        port map (
            clk                       => clk,
            reset_n                   => reset_n,
            sleep_i                   => tu_sleep_o,
            
            fi_frame_i                => mu_fi_frame_o,
            fi_frame_ready_i          => mu_fi_frame_ready_o,
            data_vector_ready_i       => mu_data_vector_ready_o,
            data_override_i           => mu_data_override_o,
            
            fsm_state_i               => fsm_state_o,
            fsm_cnt_i                 => fsm_cnt_o,
            data_width_i              => fsm_data_width_o,
            crc_width_i               => fsm_crc_width_o,
            fd_mode_i                 => fsm_fd_mode_o,
            dlc_buffer_i              => fsm_dlc_buffer_o,
            dlc_ready_i               => fsm_dlc_ready_o,

            bs_insert_i               => fsm_bs_insert_o,
            bs_insert_dynamic_i       => fsm_bs_insert_dynamic_o,
            bs_shift_i                => fsm_bs_shift_o,
            bs_state_i                => fsm_bs_state_o,
            bs_crc_cnt_i              => fsm_bs_crc_cnt_o,
            bs_crc_mode_i             => fsm_bs_crc_mode_o,

            sample_buff_i             => fsm_sample_buff_o,
            sample_buff_ready_i       => fsm_sample_buff_ready_o,
            pre_sample_point_i        => tu_pre_sample_point_o,
            pre_sample_point_strobe_i => tu_pre_sample_point_strobe_o,
            xcvr_strb_i               => tu_xcvr_strb_o,
            fip_strb_i                => tu_fip_strb_o,

            interrupt_req_o           => ou_interrupt_req_o,
            inj_pending_o             => ou_inj_pending_o,
            injection_arm_o           => ou_injection_arm_o,
            xcvr_mode_req_o           => ou_xcvr_mode_req_o,
            
            inj_err_miss_o            => ou_inj_err_miss_o,
            inj_err_dom_o             => ou_inj_err_dom_o,
            inj_err_dlc_o             => ou_inj_err_dlc_o,
            inj_err_fsm_o             => ou_inj_err_fsm_o
        );

    --- AXI Registers
    can_fd_fi_register_file_axi_lite_inst : entity work.can_fd_fi_register_file_axi_lite
        port map (
            clk             => clk,
            axi_lite_m2s    => regs_m2s,
            axi_lite_s2m    => regs_s2m,
            regs_up         => regs_up_r,
            regs_down       => regs_down,
            reg_was_read    => reg_was_read,
            reg_was_written => reg_was_written
        );
    
    -- Timing Unit Configuration mapping
    axi_cfg_brp_nomi_o <= regs_down.GLOBAL_CONFIG.cfg_brp_nomi;
    axi_cfg_brp_data_o <= regs_down.GLOBAL_CONFIG.cfg_brp_data;
    axi_cfg_ssp_o      <= regs_down.GLOBAL_CONFIG.cfg_ssp;
    axi_cfg_en_o       <= regs_down.GLOBAL_CONFIG.cfg_en;
    axi_cfg_td_en_o    <= regs_down.GLOBAL_CONFIG.cfg_td_en;

    axi_cfg_ph1_len_nomi_o <= regs_down.NOMINAL_CONFIG.cfg_ph1_len_nomi;
    axi_cfg_ph2_len_nomi_o <= regs_down.NOMINAL_CONFIG.cfg_ph2_len_nomi;
    axi_cfg_sjw_nomi_o     <= regs_down.NOMINAL_CONFIG.cfg_sjw_nomi;

    axi_cfg_ph1_len_data_o <= regs_down.DATA_CONFIG.cfg_ph1_len_data;
    axi_cfg_ph2_len_data_o <= regs_down.DATA_CONFIG.cfg_ph2_len_data;
    axi_cfg_sjw_data_o     <= regs_down.DATA_CONFIG.cfg_sjw_data;

    axi_cfg_psp_nomi_o <= regs_down.FI_CONFIG.cfg_psp_nomi;
    axi_cfg_psp_data_o <= regs_down.FI_CONFIG.cfg_psp_data;

    axi_cfg_fip_nomi_o <= regs_down.FI_CONFIG.cfg_fip_nomi;
    axi_cfg_fip_data_o <= regs_down.FI_CONFIG.cfg_fip_data;

    regs_up.STATUS_FLAGS.tu_ready_config <= tu_cfg_ready_o;

    --------------------
    -- Mapping Override Unit Registers 
    --------------------
    regs_up.STATUS_FLAGS.inj_err_miss <= ou_inj_err_miss_o;
    regs_up.STATUS_FLAGS.inj_err_dom  <= ou_inj_err_dom_o;
    regs_up.STATUS_FLAGS.inj_err_dlc  <= ou_inj_err_dlc_o;
    regs_up.STATUS_FLAGS.inj_err_fsm  <= ou_inj_err_fsm_o;

    --------------------
    -- Mapping Memory Unit AXI Registers 
    --------------------

    axi_data_valid_o     <= regs_down.MU_CFG_BASE.ram_data_valid;
    axi_data_addr_o      <= std_logic_vector(regs_down.MU_CFG_ADDR.ram_data_address);
    -- I assume this signal is clocked
    axi_data_strobe_o    <= reg_was_written.MU_CFG_BASE;
    axi_data_payload_o   <= std_logic_vector(regs_down.MU_RAM_DATA.ram_data_payload);
    axi_interrupt_resp_o <= reg_was_read.IRQ_RST_REG;

    --------------------
    -- Mapping IDs to Array values 
    -- VHDL does not support any kind of metaprogramming, so thats the best I can do
    --------------------

    -- Index 0
    axi_id_mem_arr_o(0).id_value <= std_logic_vector(regs_down.ID_MEM0_MATCH.idm0_match);
    axi_id_mem_arr_o(0).id_mask  <= std_logic_vector(regs_down.ID_MEM0_MASK.idm0_mask);
    axi_id_mem_arr_o(0).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM0_FIF.idm0_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM0_FIF.idm0_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM0_FIF.idm0_fif(8 downto 0))
    );

    -- Index 1
    axi_id_mem_arr_o(1).id_value <= std_logic_vector(regs_down.ID_MEM1_MATCH.idm1_match);
    axi_id_mem_arr_o(1).id_mask  <= std_logic_vector(regs_down.ID_MEM1_MASK.idm1_mask);
    axi_id_mem_arr_o(1).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM1_FIF.idm1_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM1_FIF.idm1_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM1_FIF.idm1_fif(8 downto 0))
    );

    -- Index 2
    axi_id_mem_arr_o(2).id_value <= std_logic_vector(regs_down.ID_MEM2_MATCH.idm2_match);
    axi_id_mem_arr_o(2).id_mask  <= std_logic_vector(regs_down.ID_MEM2_MASK.idm2_mask);
    axi_id_mem_arr_o(2).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM2_FIF.idm2_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM2_FIF.idm2_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM2_FIF.idm2_fif(8 downto 0))
    );

    -- Index 3
    axi_id_mem_arr_o(3).id_value <= std_logic_vector(regs_down.ID_MEM3_MATCH.idm3_match);
    axi_id_mem_arr_o(3).id_mask  <= std_logic_vector(regs_down.ID_MEM3_MASK.idm3_mask);
    axi_id_mem_arr_o(3).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM3_FIF.idm3_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM3_FIF.idm3_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM3_FIF.idm3_fif(8 downto 0))
    );

    -- Index 4
    axi_id_mem_arr_o(4).id_value <= std_logic_vector(regs_down.ID_MEM4_MATCH.idm4_match);
    axi_id_mem_arr_o(4).id_mask  <= std_logic_vector(regs_down.ID_MEM4_MASK.idm4_mask);
    axi_id_mem_arr_o(4).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM4_FIF.idm4_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM4_FIF.idm4_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM4_FIF.idm4_fif(8 downto 0))
    );

    -- Index 5
    axi_id_mem_arr_o(5).id_value <= std_logic_vector(regs_down.ID_MEM5_MATCH.idm5_match);
    axi_id_mem_arr_o(5).id_mask  <= std_logic_vector(regs_down.ID_MEM5_MASK.idm5_mask);
    axi_id_mem_arr_o(5).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM5_FIF.idm5_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM5_FIF.idm5_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM5_FIF.idm5_fif(8 downto 0))
    );

    -- Index 6
    axi_id_mem_arr_o(6).id_value <= std_logic_vector(regs_down.ID_MEM6_MATCH.idm6_match);
    axi_id_mem_arr_o(6).id_mask  <= std_logic_vector(regs_down.ID_MEM6_MASK.idm6_mask);
    axi_id_mem_arr_o(6).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM6_FIF.idm6_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM6_FIF.idm6_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM6_FIF.idm6_fif(8 downto 0))
    );

    -- Index 7
    axi_id_mem_arr_o(7).id_value <= std_logic_vector(regs_down.ID_MEM7_MATCH.idm7_match);
    axi_id_mem_arr_o(7).id_mask  <= std_logic_vector(regs_down.ID_MEM7_MASK.idm7_mask);
    axi_id_mem_arr_o(7).fi_frame <= ( 
        parse_fi_type(std_logic_vector(regs_down.ID_MEM7_FIF.idm7_fif(17 downto 12))),
        std_logic_vector(regs_down.ID_MEM7_FIF.idm7_fif(11 downto 9)),
        std_logic_vector(regs_down.ID_MEM7_FIF.idm7_fif(8 downto 0))
    );

    clk_reg_assign : process(all)
    begin
        if rising_edge(clk) then
            if not reset_n then
                regs_up_r <= can_fd_fi_regs_up_init;
            else
                regs_up_r     <= regs_up;
                test_signal_r <= test_signal;
            end if;
        end if;
    end process;

end Behavioral;