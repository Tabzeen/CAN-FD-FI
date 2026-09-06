
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.can_fd_fi_regs_pkg.all;
use work.can_fd_fi_register_record_pkg.all;

entity can_fi_axi_top is
  port (
    clk     : in std_ulogic;
    reset_n : in std_ulogic;

    ----------------------------------------------------------------------------
    -- AXI4-Lite Slave Interface (FLAT)
    ----------------------------------------------------------------------------
    -- Write Address Channel
    s_axi_awaddr  : in  std_ulogic_vector(31 downto 0);
    s_axi_awvalid : in  std_ulogic;
    s_axi_awready : out std_ulogic;

    -- Write Data Channel
    s_axi_wdata   : in  std_ulogic_vector(31 downto 0);
    s_axi_wstrb   : in  std_ulogic_vector(3 downto 0);
    s_axi_wvalid  : in  std_ulogic;
    s_axi_wready  : out std_ulogic;

    -- Write Response Channel
    s_axi_bresp   : out std_ulogic_vector(1 downto 0);
    s_axi_bvalid  : out std_ulogic;
    s_axi_bready  : in  std_ulogic;

    -- Read Address Channel
    s_axi_araddr  : in  std_ulogic_vector(31 downto 0);
    s_axi_arvalid : in  std_ulogic;
    s_axi_arready : out std_ulogic;

    -- Read Data Channel
    s_axi_rdata   : out std_ulogic_vector(31 downto 0);
    s_axi_rresp   : out std_ulogic_vector(1 downto 0);
    s_axi_rvalid  : out std_ulogic;
    s_axi_rready  : in  std_ulogic;

    -- CAN RX line to Transceiver
    port_can_rx : in std_logic;
    port_can_tx : out std_logic;
    port_irq : out std_logic;
    
    -- Debugging Pins
    port_inj_trigger: out std_logic;
    port_frame_start: out std_logic;
    port_frame_end: out std_logic

  );
end entity;

architecture rtl of can_fi_axi_top is

  -- Records from axi_lite_pkg [cite: 50, 52]
  signal regs_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal regs_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

begin

  ------------------------------------------------------------------------------
  -- Master to Slave (Inputs)
  ------------------------------------------------------------------------------
  -- Address Read [cite: 7, 41]
  regs_m2s.read.ar.valid <= s_axi_arvalid;
  -- Note: addr field in record is u_unsigned(63 downto 0) [cite: 6, 7]
  regs_m2s.read.ar.addr(31 downto 0) <= unsigned(s_axi_araddr);
  
  -- Read Data (Master Ready) [cite: 35, 42]
  regs_m2s.read.r.ready  <= s_axi_rready;

  -- Address Write [cite: 7, 46]
  regs_m2s.write.aw.valid <= s_axi_awvalid;
  regs_m2s.write.aw.addr(31 downto 0) <= unsigned(s_axi_awaddr);

  -- Write Data [cite: 19, 20, 46]
  regs_m2s.write.w.valid <= s_axi_wvalid;
  regs_m2s.write.w.data(31 downto 0) <= s_axi_wdata;
  regs_m2s.write.w.strb(3 downto 0)  <= s_axi_wstrb;

  -- Write Response (Master Ready) [cite: 27, 46]
  regs_m2s.write.b.ready <= s_axi_bready;

  ------------------------------------------------------------------------------
  -- Slave to Master (Outputs)
  ------------------------------------------------------------------------------
  -- Address Read Ready [cite: 10, 44]
  s_axi_arready <= regs_s2m.read.ar.ready;

  -- Read Data Channel [cite: 31, 37, 44]
  s_axi_rvalid  <= regs_s2m.read.r.valid;
  s_axi_rdata   <= regs_s2m.read.r.data(31 downto 0);
  s_axi_rresp   <= regs_s2m.read.r.resp;

  -- Address Write Ready [cite: 10, 48]
  s_axi_awready <= regs_s2m.write.aw.ready;

  -- Write Data Ready [cite: 24, 48]
  s_axi_wready  <= regs_s2m.write.w.ready;

  -- Write Response Channel [cite: 31, 48]
  s_axi_bvalid  <= regs_s2m.write.b.valid;
  s_axi_bresp   <= regs_s2m.write.b.resp;

  ------------------------------------------------------------------------------
  -- Core Instantiation
  ------------------------------------------------------------------------------
  u_core : entity work.can_fi_route
    port map (
      clk      => clk,
      reset_n  => reset_n,
      regs_m2s => regs_m2s,
      regs_s2m => regs_s2m,
      port_can_rx => port_can_rx,
      port_can_tx => port_can_tx,
      port_irq => port_irq,
      port_inj_trigger => port_inj_trigger,
      port_frame_start => port_frame_start,
      port_frame_end => port_frame_end
    );

end architecture;