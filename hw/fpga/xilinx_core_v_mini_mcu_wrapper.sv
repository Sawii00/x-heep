// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module xilinx_core_v_mini_mcu_wrapper
  import obi_pkg::*;
  import reg_pkg::*;
#(
    parameter PULP_XPULP           = 0,
    parameter FPU                  = 0,
    parameter PULP_ZFINX           = 0,
    parameter CLK_LED_COUNT_LENGTH = 27
) (

    inout logic clk_i,
    inout logic rst_i,

    //visibility signals
    output logic rst_led,
    output logic clk_led,
    output logic clk_out,

    inout logic boot_select_i,
    inout logic execute_from_flash_i,

    //inout logic jtag_tck_i,
    //inout logic jtag_tms_i,
    //inout logic jtag_trst_ni,
    //inout logic jtag_tdi_i,
    //inout logic jtag_tdo_o,

    //inout logic uart_rx_i,
    //inout logic uart_tx_o,

    inout logic [29:0] gpio_io,

    output logic exit_value_o,
    inout  logic exit_valid_o,

    inout logic [3:0] spi_flash_sd_io,
    inout logic spi_flash_csb_o,
    inout logic spi_flash_sck_o,

    inout logic [3:0] spi_sd_io,
    inout logic spi_csb_o,
    inout logic spi_sck_o,

    inout logic i2c_scl_io,
    inout logic i2c_sda_io,

    inout wire [14:0] DDR_addr,
    inout wire [2:0] DDR_ba,
    inout wire DDR_cas_n,
    inout wire DDR_ck_n,
    inout wire DDR_ck_p,
    inout wire DDR_cke,
    inout wire DDR_cs_n,
    inout wire [3:0] DDR_dm,
    inout wire [31:0] DDR_dq,
    inout wire [3:0] DDR_dqs_n,
    inout wire [3:0] DDR_dqs_p,
    inout wire DDR_odt,
    inout wire DDR_ras_n,
    inout wire DDR_reset_n,
    inout wire DDR_we_n,
    inout wire FIXED_IO_ddr_vrn,
    inout wire FIXED_IO_ddr_vrp,
    inout wire [53:0] FIXED_IO_mio,
    inout wire FIXED_IO_ps_clk,
    inout wire FIXED_IO_ps_porb,
    inout wire FIXED_IO_ps_srstb

);


  logic AXI_HP_ACLK;
  logic [31:0]AXI_HP_araddr_sig;
  logic [1:0]AXI_HP_arburst_sig;
  logic [3:0]AXI_HP_arcache_sig;
  logic [5:0]AXI_HP_arid_sig;
  logic [3:0]AXI_HP_arlen_sig;
  logic [1:0]AXI_HP_arlock_sig;
  logic [2:0]AXI_HP_arprot_sig;
  logic [3:0]AXI_HP_arqos_sig;
  logic AXI_HP_arready_sig;
  logic [2:0]AXI_HP_arsize_sig;
  logic AXI_HP_arvalid_sig;
  logic [31:0]AXI_HP_awaddr_sig;
  logic [1:0]AXI_HP_awburst_sig;
  logic [3:0]AXI_HP_awcache_sig;
  logic [5:0]AXI_HP_awid_sig;
  logic [3:0]AXI_HP_awlen_sig;
  logic [1:0]AXI_HP_awlock_sig;
  logic [2:0]AXI_HP_awprot_sig;
  logic [3:0]AXI_HP_awqos_sig;
  logic AXI_HP_awready_sig;
  logic [2:0]AXI_HP_awsize_sig;
  logic AXI_HP_awvalid_sig;
  logic [5:0]AXI_HP_bid_sig;
  logic AXI_HP_bready_sig;
  logic [1:0]AXI_HP_bresp_sig;
  logic AXI_HP_bvalid_sig;
  logic [31:0]AXI_HP_rdata_sig;
  logic [5:0]AXI_HP_rid_sig;
  logic AXI_HP_rlast_sig;
  logic AXI_HP_rready_sig;
  logic [1:0]AXI_HP_rresp_sig;
  logic AXI_HP_rvalid_sig;
  logic [31:0]AXI_HP_wdata_sig;
  logic [5:0]AXI_HP_wid_sig;
  logic AXI_HP_wlast_sig;
  logic AXI_HP_wready_sig;
  logic [3:0]AXI_HP_wstrb_sig;
  logic AXI_HP_wvalid_sig;


  wire                               clk_gen;
  logic [                      31:0] exit_value;
  wire                               rst_n;
  logic [CLK_LED_COUNT_LENGTH - 1:0] clk_count;
  //wire  [4:0]PS_GPIO2JTAG_tri_io;
  logic                              jtag_tck_i;
  logic                              jtag_tms_i;
  logic                              jtag_trst_ni;
  logic                              jtag_tdi_i;
  logic                              jtag_tdo_o;

  logic                              UART_rxd_sig;
  logic                              UART_txd_sig;
  // low active reset
  assign rst_n   = !rst_i;

  // reset LED for debugging
  assign rst_led = rst_n;

  // counter to blink an LED
  assign clk_led = clk_count[CLK_LED_COUNT_LENGTH-1];

  always_ff @(posedge clk_gen or negedge rst_n) begin : clk_count_process
    if (!rst_n) begin
      clk_count <= '0;
    end else begin
      clk_count <= clk_count + 1;
    end
  end

  // clock output for debugging
  assign clk_out = clk_gen;

  xilinx_clk_wizard_wrapper xilinx_clk_wizard_wrapper_i (
      .clk_125MHz(clk_i),
      .clk_out1_0(clk_gen)
  );

  processing_system_wrapper processing_system_wrapper_i (
      .DDR_addr(DDR_addr),
      .DDR_ba(DDR_ba),
      .DDR_cas_n(DDR_cas_n),
      .DDR_ck_n(DDR_ck_n),
      .DDR_ck_p(DDR_ck_p),
      .DDR_cke(DDR_cke),
      .DDR_cs_n(DDR_cs_n),
      .DDR_dm(DDR_dm),
      .DDR_dq(DDR_dq),
      .DDR_dqs_n(DDR_dqs_n),
      .DDR_dqs_p(DDR_dqs_p),
      .DDR_odt(DDR_odt),
      .DDR_ras_n(DDR_ras_n),
      .DDR_reset_n(DDR_reset_n),
      .DDR_we_n(DDR_we_n),
      .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
      .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
      .FIXED_IO_mio(FIXED_IO_mio),
      .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
      .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
      .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
      .UART_rxd(UART_rxd_sig),
      .UART_txd(UART_txd_sig),
      .gpio_jtag_tck_i(jtag_tck_i),
      .gpio_jtag_tms_i(jtag_tms_i),
      .gpio_jtag_trst_ni(jtag_trst_ni),
      .gpio_jtag_tdi_i(jtag_tdi_i),
      .gpio_jtag_tdo_o(jtag_tdo_o),
      .AXI_HP_ACLK(clk_gen), //Is this ok????
      .AXI_HP_araddr(AXI_HP_araddr_sig),
      .AXI_HP_arburst(AXI_HP_arburst_sig),
      .AXI_HP_arcache(AXI_HP_arcache_sig),
      .AXI_HP_arid(AXI_HP_arid_sig),
      .AXI_HP_arlen(AXI_HP_arlen_sig),
      .AXI_HP_arlock(AXI_HP_arlock_sig),
      .AXI_HP_arprot(AXI_HP_arprot_sig),
      .AXI_HP_arqos(AXI_HP_arqos_sig),
      .AXI_HP_arready(AXI_HP_arready_sig),
      .AXI_HP_arsize(AXI_HP_arsize_sig),
      .AXI_HP_arvalid(AXI_HP_arvalid_sig),
      .AXI_HP_awaddr(AXI_HP_awaddr_sig),
      .AXI_HP_awburst(AXI_HP_awburst_sig),
      .AXI_HP_awcache(AXI_HP_awcache_sig),
      .AXI_HP_awid(AXI_HP_awid_sig),
      .AXI_HP_awlen(AXI_HP_awlen_sig),
      .AXI_HP_awlock(AXI_HP_awlock_sig),
      .AXI_HP_awprot(AXI_HP_awprot_sig),
      .AXI_HP_awqos(AXI_HP_awqos_sig),
      .AXI_HP_awready(AXI_HP_awready_sig),
      .AXI_HP_awsize(AXI_HP_awsize_sig),
      .AXI_HP_awvalid(AXI_HP_awvalid_sig),
      .AXI_HP_bid(AXI_HP_bid_sig),
      .AXI_HP_bready(AXI_HP_bready_sig),
      .AXI_HP_bresp(AXI_HP_bresp_sig),
      .AXI_HP_bvalid(AXI_HP_bvalid_sig),
      .AXI_HP_rdata(AXI_HP_rdata_sig),
      .AXI_HP_rid(AXI_HP_rid_sig),
      .AXI_HP_rlast(AXI_HP_rlast_sig),
      .AXI_HP_rready(AXI_HP_rready_sig),
      .AXI_HP_rresp(AXI_HP_rresp_sig),
      .AXI_HP_rvalid(AXI_HP_rvalid_sig),
      .AXI_HP_wdata(AXI_HP_wdata_sig),
      .AXI_HP_wid(AXI_HP_wid_sig),
      .AXI_HP_wlast(AXI_HP_wlast_sig),
      .AXI_HP_wready(AXI_HP_wready_sig),
      .AXI_HP_wstrb(AXI_HP_wstrb_sig),
      .AXI_HP_wvalid(AXI_HP_wvalid_sig)
  );

  axi_spi_slave_wrap fake_flash(

    .clk_i(clk_gen),
    .rst_ni,

    .test_mode,

    .axi_master.aw_valid(AXI_HP_awvalid_sig),
    .axi_master.aw_id(AXI_HP_awid_sig),
    .axi_master.aw_prot(AXI_HP_awprot_sig),
    .axi_master.aw_qos(AXI_HP_awqos_sig),
    .axi_master.aw_cache(AXI_HP_awcache_sig),
    .axi_master.aw_lock(AXI_HP_awlock_sig),
    .axi_master.aw_burst(AXI_HP_awburst_sig),
    .axi_master.aw_size(AXI_HP_awsize_sig),
    .axi_master.aw_len(AXI_HP_awlen_sig),
    .axi_master.aw_addr(AXI_HP_awaddr_sig),
    .axi_master.aw_ready(AXI_HP_awready_sig),

    .axi_master.w_valid(AXI_HP_wvalid_sig),
    .axi_master.w_data(AXI_HP_wdata_sig),
    .axi_master.w_strb(AXI_HP_wstrb_sig),
    .axi_master.w_last(AXI_HP_wlast_sig),
    .axi_master.w_ready(AXI_HP_wready_sig),

    .axi_master.b_valid(AXI_HP_bvalid_sig),
    .axi_master.b_id(AXI_HP_bid_sig),
    .axi_master.b_resp(AXI_HP_bresp_sig),
    .axi_master.b_ready(AXI_HP_bready_sig),

    .axi_master.ar_valid(AXI_HP_arvalid_sig),
    .axi_master.ar_id(AXI_HP_arid_sig),
    .axi_master.ar_prot(AXI_HP_arprot_sig),
    .axi_master.ar_qos(AXI_HP_arqos_sig),
    .axi_master.ar_cache(AXI_HP_arcache_sig),
    .axi_master.ar_lock(AXI_HP_arlock_sig),
    .axi_master.ar_burst(AXI_HP_arburst_sig),
    .axi_master.ar_size(AXI_HP_arsize_sig),
    .axi_master.ar_len(AXI_HP_arlen_sig),
    .axi_master.ar_addr(AXI_HP_araddr_sig),
    .axi_master.ar_ready(AXI_HP_arready_sig),

    .axi_master.r_valid(AXI_HP_rvalid_sig),
    .axi_master.r_id(AXI_HP_rid_sig),
    .axi_master.r_data(AXI_HP_rdata_sig),
    .axi_master.r_resp(AXI_HP_rresp_sig),
    .axi_master.r_last(AXI_HP_rlast_sig),
    .axi_master.r_ready(AXI_HP_rready_sig),

    .spi_clk,
    .spi_cs,
    .spi_oen0_o,
    .spi_oen1_o,
    .spi_oen2_o,
    .spi_oen3_o,

    .spi_sdo0,
    .spi_sdo1,
    .spi_sdo2,
    .spi_sdo3,
    .spi_sdi0,
    .spi_sdi1,
    .spi_sdi2,
    .spi_sdi3
  );


  x_heep_system x_heep_system_i (

      .clk_i (clk_gen),
      .rst_ni(rst_n),

      .jtag_tck_i  (jtag_tck_i),
      .jtag_tms_i  (jtag_tms_i),
      .jtag_trst_ni(jtag_trst_ni),
      .jtag_tdi_i  (jtag_tdi_i),
      .jtag_tdo_o  (jtag_tdo_o),

      .ext_xbar_master_req_i('0),
      .ext_xbar_master_resp_o(),
      .ext_xbar_slave_req_o(),
      .ext_xbar_slave_resp_i('0),
      .ext_peripheral_slave_req_o(),
      .ext_peripheral_slave_resp_i('0),

      .uart_rx_i(UART_txd_sig),
      .uart_tx_o(UART_rxd_sig),

      .intr_vector_ext_i('0),

      .gpio_0_io (gpio_io[0]),
      .gpio_1_io (gpio_io[1]),
      .gpio_2_io (gpio_io[2]),
      .gpio_3_io (gpio_io[3]),
      .gpio_4_io (gpio_io[4]),
      .gpio_5_io (gpio_io[5]),
      .gpio_6_io (gpio_io[6]),
      .gpio_7_io (gpio_io[7]),
      .gpio_8_io (gpio_io[8]),
      .gpio_9_io (gpio_io[9]),
      .gpio_10_io(gpio_io[10]),
      .gpio_11_io(gpio_io[11]),
      .gpio_12_io(gpio_io[12]),
      .gpio_13_io(gpio_io[13]),
      .gpio_14_io(gpio_io[14]),
      .gpio_15_io(gpio_io[15]),
      .gpio_16_io(gpio_io[16]),
      .gpio_17_io(gpio_io[17]),
      .gpio_18_io(gpio_io[18]),
      .gpio_19_io(gpio_io[19]),
      .gpio_20_io(gpio_io[20]),
      .gpio_21_io(gpio_io[21]),
      .gpio_22_io(gpio_io[22]),
      .gpio_23_io(gpio_io[23]),
      .gpio_24_io(gpio_io[24]),
      .gpio_25_io(gpio_io[25]),
      .gpio_26_io(gpio_io[26]),
      .gpio_27_io(gpio_io[27]),
      .gpio_28_io(gpio_io[28]),
      .gpio_29_io(gpio_io[29]),

      .execute_from_flash_i(execute_from_flash_i),
      .boot_select_i(boot_select_i),

      .spi_flash_sd_0_io(spi_flash_sd_io[0]),
      .spi_flash_sd_1_io(spi_flash_sd_io[1]),
      .spi_flash_sd_2_io(spi_flash_sd_io[2]),
      .spi_flash_sd_3_io(spi_flash_sd_io[3]),
      .spi_flash_cs_0_io(spi_flash_csb_o),
      .spi_flash_cs_1_io(),
      .spi_flash_sck_io (spi_flash_sck_o),

      .spi_sd_0_io(spi_sd_io[0]),
      .spi_sd_1_io(spi_sd_io[1]),
      .spi_sd_2_io(spi_sd_io[2]),
      .spi_sd_3_io(spi_sd_io[3]),
      .spi_cs_0_io(spi_csb_o),
      .spi_cs_1_io(),
      .spi_sck_io (spi_sck_o),

      .exit_value_o(exit_value),
      .exit_valid_o(exit_valid_o),

      .i2c_scl_io,
      .i2c_sda_io
  );


  assign exit_value_o = exit_value[0];


endmodule
