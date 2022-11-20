// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module fpga_embedded_system_emulation_toplevel
  import obi_pkg::*;
  import reg_pkg::*;
#(

) (
    inout logic clk_i,
    inout logic rst_i,

    //visibility signals
    output logic rst_led,
    output logic clk_led,
    output logic clk_out,

    inout logic boot_select_i,
    inout logic execute_from_flash_i,


    inout logic [29:0] gpio_io,

    output logic exit_value_o,
    inout  logic exit_valid_o,

    //inout logic [3:0] spi_flash_sd_io,
    //inout logic spi_flash_csb_o,
    //inout logic spi_flash_sck_o,

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


  // SIGNALS ENTERING HEEP
  logic jtag_tck_i_sig;
  logic jtag_tms_i_sig;
  logic jtag_trst_ni_sig;
  logic jtag_tdi_i_sig;
  logic jtag_tdo_o_sig;

  logic UART_rxd_sig;
  logic UART_txd_sig;


  //logic [3:0] spi_flash_sd_io_sig;
  logic spi_flash_csb_o_sig;
  logic spi_flash_sck_o_sig;

  logic spi_oen0_o_sig;
  logic spi_oen1_o_sig;
  logic spi_oen2_o_sig;
  logic spi_oen3_o_sig;

  logic spi_sdo0_sig;
  logic spi_sdo1_sig;
  logic spi_sdo2_sig;
  logic spi_sdo3_sig;
  logic spi_sdi0_sig;
  logic spi_sdi1_sig;
  logic spi_sdi2_sig;
  logic spi_sdi3_sig;

  parameter AXI_ADDR_WIDTH = 32;
  parameter AXI_ADDR_WIDTH_SLAVE = 4;
  parameter AXI_DATA_WIDTH = 32;
  parameter C_NUM_REGISTERS = 5;


  // PS SIDE PORTS
  logic AXI_HP_ACLK;
  logic AXI_HP_ARESETN;
  logic [AXI_ADDR_WIDTH - 1:0] AXI_HP_araddr_sig;
  logic [1:0] AXI_HP_arburst_sig;
  logic [3:0] AXI_HP_arcache_sig;
  logic [5:0] AXI_HP_arid_sig;
  logic [3:0] AXI_HP_arlen_sig;
  logic [1:0] AXI_HP_arlock_sig;
  logic [2:0] AXI_HP_arprot_sig;
  logic [3:0] AXI_HP_arqos_sig;
  logic AXI_HP_arready_sig;
  logic [2:0] AXI_HP_arsize_sig;
  logic AXI_HP_arvalid_sig;
  logic [AXI_ADDR_WIDTH - 1:0] AXI_HP_awaddr_sig;
  logic [1:0] AXI_HP_awburst_sig;
  logic [3:0] AXI_HP_awcache_sig;
  logic [5:0] AXI_HP_awid_sig;
  logic [3:0] AXI_HP_awlen_sig;
  logic [1:0] AXI_HP_awlock_sig;
  logic [2:0] AXI_HP_awprot_sig;
  logic [3:0] AXI_HP_awqos_sig;
  logic AXI_HP_awready_sig;
  logic [2:0] AXI_HP_awsize_sig;
  logic AXI_HP_awvalid_sig;
  logic [5:0] AXI_HP_bid_sig;
  logic AXI_HP_bready_sig;
  logic [1:0] AXI_HP_bresp_sig;
  logic AXI_HP_bvalid_sig;
  logic [AXI_DATA_WIDTH - 1:0] AXI_HP_rdata_sig;
  logic [5:0] AXI_HP_rid_sig;
  logic AXI_HP_rlast_sig;
  logic AXI_HP_rready_sig;
  logic [1:0] AXI_HP_rresp_sig;
  logic AXI_HP_rvalid_sig;
  logic [AXI_DATA_WIDTH - 1:0] AXI_HP_wdata_sig;
  logic [5:0] AXI_HP_wid_sig;
  logic AXI_HP_wlast_sig;
  logic AXI_HP_wready_sig;
  logic [3:0] AXI_HP_wstrb_sig;
  logic AXI_HP_wvalid_sig;

  logic spi_test_clk_sig;
  logic spi_test_cs_sig;
  logic [3:0] spi_test_data_sig;


  // ADDRESS HIJACKER PORTS
  logic [AXI_ADDR_WIDTH-1:0] axi_master_awaddr_in_sig;
  logic [AXI_ADDR_WIDTH-1:0] axi_master_araddr_in_sig;

  logic [AXI_ADDR_WIDTH_SLAVE - 1 : 0] s00_axi_awaddr_sig;
  logic s00_axi_awvalid_sig;
  logic s00_axi_awready_sig;
  logic [AXI_DATA_WIDTH - 1 : 0] s00_axi_wdata_sig;
  logic s00_axi_wvalid_sig;
  logic s00_axi_wready_sig;
  logic s00_axi_bvalid_sig;
  logic s00_axi_bready_sig;
  logic [(AXI_DATA_WIDTH / 8)-1 : 0] s00_axi_wstrb_sig;
  logic [2 : 0] s00_axi_arprot_sig;
  logic [2 : 0] s00_axi_awprot_sig;
  logic [AXI_ADDR_WIDTH_SLAVE - 1 : 0] s00_axi_araddr_sig;
  logic s00_axi_arvalid_sig;
  logic s00_axi_arready_sig;
  logic [AXI_DATA_WIDTH - 1 : 0] s00_axi_rdata_sig;
  logic s00_axi_rvalid_sig;
  logic s00_axi_rready_sig;
  logic [1:0] s00_axi_rresp_sig;
  logic [1:0] s00_axi_bresp_sig;



  core_v_mini_mcu_wrapper core_mcu_wrapper (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .rst_led(rst_led),
      .clk_led(clk_led),
      .clk_out(clk_out),
      .boot_select_i(boot_select_i),
      .execute_from_flash_i(execute_from_flash_i),
      .jtag_tck_i(jtag_tck_i_sig),
      .jtag_tms_i(jtag_tms_i_sig),
      .jtag_trst_ni(jtag_trst_ni_sig),
      .jtag_tdi_i(jtag_tdi_i_sig),
      .jtag_tdo_o(jtag_tdo_o_sig),
      .uart_rx_i(UART_txd_sig),
      .uart_tx_o(UART_rxd_sig),
      .gpio_io(gpio_io),
      .exit_value_o(exit_value_o),
      .exit_valid_o(exit_valid_o),
      .spi_flash_sd0_o(spi_sdo0_sig),
      .spi_flash_sd1_i(spi_sdi1_sig),
      .spi_flash_sd2_o(spi_sdo2_sig),
      .spi_flash_sd3_o(spi_sdo3_sig),
      .spi_flash_csb_o(spi_flash_csb_o_sig),
      .spi_flash_sck_o(spi_flash_sck_o_sig),
      .spi_sd_io(spi_sd_io),
      .spi_csb_o(spi_csb_o),
      .spi_sck_o(spi_sck_o),
      .i2c_scl_io(i2c_scl_io),
      .i2c_sda_io(i2c_sda_io)
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
      .gpio_jtag_tck_i(jtag_tck_i_sig),
      .gpio_jtag_tms_i(jtag_tms_i_sig),
      .gpio_jtag_trst_ni(jtag_trst_ni_sig),
      .gpio_jtag_tdi_i(jtag_tdi_i_sig),
      .gpio_jtag_tdo_o(jtag_tdo_o_sig),
      .AXI_HP_ACLK(AXI_HP_ACLK),
      .AXI_HP_ARESETN(AXI_HP_ARESETN),
      .AXI_HP_araddr(AXI_HP_araddr_sig),
      .AXI_HP_arburst(AXI_HP_arburst_sig),
      .AXI_HP_arcache(AXI_HP_arcache_sig),
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
      .AXI_HP_awlen(AXI_HP_awlen_sig),
      .AXI_HP_awlock(AXI_HP_awlock_sig),
      .AXI_HP_awprot(AXI_HP_awprot_sig),
      .AXI_HP_awqos(AXI_HP_awqos_sig),
      .AXI_HP_awready(AXI_HP_awready_sig),
      .AXI_HP_awsize(AXI_HP_awsize_sig),
      .AXI_HP_awvalid(AXI_HP_awvalid_sig),
      .AXI_HP_bready(AXI_HP_bready_sig),
      .AXI_HP_bresp(AXI_HP_bresp_sig),
      .AXI_HP_bvalid(AXI_HP_bvalid_sig),
      .AXI_HP_rdata(AXI_HP_rdata_sig),
      .AXI_HP_rlast(AXI_HP_rlast_sig),
      .AXI_HP_rready(AXI_HP_rready_sig),
      .AXI_HP_rresp(AXI_HP_rresp_sig),
      .AXI_HP_rvalid(AXI_HP_rvalid_sig),
      .AXI_HP_wdata(AXI_HP_wdata_sig),
      .AXI_HP_wlast(AXI_HP_wlast_sig),
      .AXI_HP_wready(AXI_HP_wready_sig),
      .AXI_HP_wstrb(AXI_HP_wstrb_sig),
      .AXI_HP_wvalid(AXI_HP_wvalid_sig),
      .M_AXI_araddr(s00_axi_araddr_sig),
      .M_AXI_arready(s00_axi_arready_sig),
      .M_AXI_arvalid(s00_axi_arvalid_sig),
      .M_AXI_awaddr(s00_axi_awaddr_sig),
      .M_AXI_awready(s00_axi_awready_sig),
      .M_AXI_awvalid(s00_axi_awvalid_sig),
      .M_AXI_bready(s00_axi_bready_sig),
      .M_AXI_bresp(s00_axi_bresp_sig),
      .M_AXI_bvalid(s00_axi_bvalid_sig),
      .M_AXI_rdata(s00_axi_rdata_sig),
      .M_AXI_rready(s00_axi_rready_sig),
      .M_AXI_rresp(s00_axi_rresp_sig),
      .M_AXI_rvalid(s00_axi_rvalid_sig),
      .M_AXI_wdata(s00_axi_wdata_sig),
      .M_AXI_wready(s00_axi_wready_sig),
      .M_AXI_wvalid(s00_axi_wvalid_sig),
      .M_AXI_awprot(s00_axi_awprot_sig),
      .M_AXI_arprot(s00_axi_arprot_sig),
      .M_AXI_wstrb(s00_axi_wstrb_sig),
      .spi_test_clk(spi_test_clk_sig),
      .spi_test_cs(spi_test_cs_sig),
      .spi_test_data(spi_test_data_sig)
  );

  axi_address_hijacker #(
      .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
      //.AXI_ADDR_WIDTH_SLAVE(AXI_ADDR_WIDTH_SLAVE),
      .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
      //.C_NUM_REGISTERS(C_NUM_REGISTERS)
  ) add_hij (
      .axi_master_awaddr_in(axi_master_awaddr_in_sig),
      .axi_master_araddr_in(axi_master_araddr_in_sig),

      // output write and read address by adding fixed offset 
      .axi_master_araddr_out(AXI_HP_araddr_sig),
      .axi_master_awaddr_out(AXI_HP_awaddr_sig),

      .S_AXI_ACLK(AXI_HP_ACLK),
      .S_AXI_ARESETN(AXI_HP_ARESETN),

      .S_AXI_AWADDR (s00_axi_awaddr_sig),
      .S_AXI_AWPROT (s00_axi_awprot_sig),   ///////////
      .S_AXI_AWVALID(s00_axi_awvalid_sig),
      .S_AXI_AWREADY(s00_axi_awready_sig),
      .S_AXI_WDATA  (s00_axi_wdata_sig),
      .S_AXI_WSTRB  (s00_axi_wstrb_sig),
      .S_AXI_WVALID (s00_axi_wvalid_sig),
      .S_AXI_WREADY (s00_axi_wready_sig),
      .S_AXI_BRESP  (s00_axi_bresp_sig),
      .S_AXI_BVALID (s00_axi_bvalid_sig),
      .S_AXI_BREADY (s00_axi_bready_sig),
      .S_AXI_ARADDR (s00_axi_araddr_sig),
      .S_AXI_ARPROT (s00_axi_arprot_sig),   ////////////
      .S_AXI_ARVALID(s00_axi_arvalid_sig),
      .S_AXI_ARREADY(s00_axi_arready_sig),
      .S_AXI_RDATA  (s00_axi_rdata_sig),
      .S_AXI_RRESP  (s00_axi_rresp_sig),
      .S_AXI_RVALID (s00_axi_rvalid_sig),
      .S_AXI_RREADY (s00_axi_rready_sig)

  );

  axi_spi_slave #(
      .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
  ) fake_flash (

      .axi_aclk(AXI_HP_ACLK),
      .axi_aresetn(AXI_HP_ARESETN),

      .test_mode('0),

      .axi_master_aw_valid(AXI_HP_awvalid_sig),
      .axi_master_aw_id(AXI_HP_awid_sig),
      .axi_master_aw_prot(AXI_HP_awprot_sig),
      .axi_master_aw_qos(AXI_HP_awqos_sig),
      .axi_master_aw_cache(AXI_HP_awcache_sig),
      .axi_master_aw_lock(AXI_HP_awlock_sig),
      .axi_master_aw_burst(AXI_HP_awburst_sig),
      .axi_master_aw_size(AXI_HP_awsize_sig),
      .axi_master_aw_len(AXI_HP_awlen_sig),
      .axi_master_aw_addr(axi_master_awaddr_in_sig),
      .axi_master_aw_ready(AXI_HP_awready_sig),

      .axi_master_w_valid(AXI_HP_wvalid_sig),
      .axi_master_w_data (AXI_HP_wdata_sig),
      .axi_master_w_strb (AXI_HP_wstrb_sig),
      .axi_master_w_last (AXI_HP_wlast_sig),
      .axi_master_w_ready(AXI_HP_wready_sig),

      .axi_master_b_valid(AXI_HP_bvalid_sig),
      .axi_master_b_id(AXI_HP_bid_sig),
      .axi_master_b_resp(AXI_HP_bresp_sig),
      .axi_master_b_ready(AXI_HP_bready_sig),

      .axi_master_ar_valid(AXI_HP_arvalid_sig),
      .axi_master_ar_id(AXI_HP_arid_sig),
      .axi_master_ar_prot(AXI_HP_arprot_sig),
      .axi_master_ar_qos(AXI_HP_arqos_sig),
      .axi_master_ar_cache(AXI_HP_arcache_sig),
      .axi_master_ar_lock(AXI_HP_arlock_sig),
      .axi_master_ar_burst(AXI_HP_arburst_sig),
      .axi_master_ar_size(AXI_HP_arsize_sig),
      .axi_master_ar_len(AXI_HP_arlen_sig),
      .axi_master_ar_addr(axi_master_araddr_in_sig),
      .axi_master_ar_ready(AXI_HP_arready_sig),

      .axi_master_r_valid(AXI_HP_rvalid_sig),
      .axi_master_r_id(AXI_HP_rid_sig),
      .axi_master_r_data(AXI_HP_rdata_sig),
      .axi_master_r_resp(AXI_HP_rresp_sig),
      .axi_master_r_last(AXI_HP_rlast_sig),
      .axi_master_r_ready(AXI_HP_rready_sig),

      .spi_sclk(spi_flash_sck_o_sig),
      .spi_cs  (spi_flash_csb_o_sig),
      //.spi_oen0_o(spi_oen0_o_sig),
      //.spi_oen1_o(spi_oen1_o_sig),
      //.spi_oen2_o(spi_oen2_o_sig),
      //.spi_oen3_o(spi_oen3_o_sig),

      //.spi_sdo0(spi_sdo0_sig),
      .spi_sdo1(spi_sdi1_sig),
      //.spi_sdo2(spi_sdo2_sig),
      //.spi_sdo3(spi_sdo3_sig),
      .spi_sdi0(spi_sdo0_sig),
      //.spi_sdi1(spi_sdi1_sig),
      .spi_sdi2(spi_sdo2_sig),
      .spi_sdi3(spi_sdo3_sig)
  );


  // TESTING PURPOSES -> THEY WILL BE INPUT TO PS AND READ BY SYSTEM ILA
  assign spi_test_clk_sig  = spi_flash_sck_o_sig;
  assign spi_test_cs_sig   = spi_flash_csb_o_sig;
  assign spi_test_data_sig = {spi_sdo0_sig, spi_sdi1_sig, spi_sdo2_sig, spi_sdo3_sig};



endmodule
