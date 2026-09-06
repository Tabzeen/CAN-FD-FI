// -----------------------------------------------------------------------------
// can_fi_axi_top_bd_wrap.v
//
// Verilog wrapper around the VHDL-2008 entity `can_fi_axi_top`, so it can be
// referenced as an RTL module in the Vivado IP Integrator block design.
//
// Background: IPI "Add Module (RTL)" does not support VHDL-2008 modules, but it
// does accept Verilog. This wrapper is a 1:1 port passthrough; the VHDL-2008
// hierarchy (can_fi_axi_top -> can_fi_route -> ... + hdl-modules axi_lite /
// register_file) compiles underneath as ordinary project sources.
//
// The AXI4-Lite slave ports keep their `s_axi_*` names so Vivado infers an
// AXI4-Lite interface for them in the block design (confirmed: create_bd_cell
// auto-infers s_axi + clk + reset_n + port_irq).
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module can_fi_axi_top_bd_wrap (
    input  wire        clk,
    input  wire        reset_n,

    // AXI4-Lite slave: write address channel
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // AXI4-Lite slave: write data channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // AXI4-Lite slave: write response channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // AXI4-Lite slave: read address channel
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // AXI4-Lite slave: read data channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // CAN transceiver lines + interrupt
    input  wire        port_can_rx,
    output wire        port_can_tx,
    output wire        port_irq,

    // Debug Wires
    output wire       port_inj_trigger,
    output wire       port_frame_start,
    output wire       port_frame_end

);

    can_fi_axi_top u_can_fi_axi_top (
        .clk           (clk),
        .reset_n       (reset_n),

        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),

        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),

        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),

        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),

        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),

        .port_can_rx   (port_can_rx),
        .port_can_tx   (port_can_tx),
        .port_irq      (port_irq),

        .port_inj_trigger (port_inj_trigger),
        .port_frame_start (port_frame_start),
        .port_frame_end   (port_frame_end)
    );

endmodule
