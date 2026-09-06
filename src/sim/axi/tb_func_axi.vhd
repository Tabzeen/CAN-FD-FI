library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.com_pkg.net;
context vunit_lib.vunit_context;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library bfm;

use work.can_fd_fi_register_record_pkg.all;
use work.can_fd_fi_register_check_pkg.all;
use work.can_fd_fi_register_read_write_pkg.all;
use work.can_fd_fi_register_wait_until_pkg.all;
use work.can_fd_fi_regs_pkg.all;

entity tb_can_fd_fi is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_can_fd_fi is
  signal clk : std_ulogic := '0';
  signal reset_n : std_logic := '1'; 
  signal regs_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal regs_s2m : axi_lite_s2m_t := axi_lite_s2m_init;
  signal uut_test_signal : std_logic;
begin
  clk <= not clk after 12.5 ns;
  test_runner_watchdog(runner, 1 ms);

  -- NOTE: This part simulates the AXI master and then checks for correct values

  ------------------------------------------------------------------------------
  main : process
    variable tu_cfg_base_val : can_fd_fi_tu_cfg_base_t := can_fd_fi_tu_cfg_base_init;
    variable tu_cfg_nomi_val : can_fd_fi_tu_cfg_nomi_t := can_fd_fi_tu_cfg_nomi_init;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("test_write_read_tu_cfg_base") then
      info("Starting test 1");
      -- TU_CFG_BASE is r_w. We can write and then read back to verify.
      tu_cfg_base_val.cfg_en_axi := '1';
      tu_cfg_base_val.cfg_brp_nomi_axi := 10; -- Must be within 2-32
      tu_cfg_base_val.cfg_brp_data_axi := 12; -- Must be within 2-32
      
      write_can_fd_fi_tu_cfg_base(net=>net, value=>tu_cfg_base_val);
      check_can_fd_fi_tu_cfg_base_equal(net=>net, expected=>tu_cfg_base_val);

    elsif run("test_write_tu_cfg_nomi") then
      -- TU_CFG_NOMI is write-only. We only issue the write command.
      tu_cfg_nomi_val.cfg_prop_len_nomi_axi := 64;
      tu_cfg_nomi_val.cfg_ph1_len_nomi_axi := 32;
      tu_cfg_nomi_val.cfg_ph2_len_nomi_axi := 16;
      tu_cfg_nomi_val.cfg_sjw_nomi_axi := 8;

      write_can_fd_fi_tu_cfg_nomi(net=>net, value=>tu_cfg_nomi_val);
      check_can_fd_fi_TU_CFG_NOMI_equal(net=>net, expected=>tu_cfg_nomi_val);

    end if;

    test_runner_cleanup(runner);
  end process;

  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity bfm.axi_lite_master
    port map (
      clk          => clk,
      axi_lite_m2s => regs_m2s,
      axi_lite_s2m => regs_s2m
    );

  ------------------------------------------------------------------------------
  -- The DUT then instantiates the AXI Slave interface via
  -- counter_register_file_axi_lite_inst : entity work.counter_register_file_axi_lite
  -- (See the hdl-registers page for vhdl example)
  dut : entity work.can_fi_route
    port map (
      clk => clk,
      reset_n => reset_n,
      regs_m2s => regs_m2s,
      regs_s2m => regs_s2m
    );

end architecture;