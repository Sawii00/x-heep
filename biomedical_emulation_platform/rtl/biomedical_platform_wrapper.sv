// Copyright 2022 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

module biomedical_platform_wrapper
    import obi_pkg::*;
    import reg_pkg::*;
#(

)(
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


  logic                              jtag_tck_i_sig;
  logic                              jtag_tms_i_sig;
  logic                              jtag_trst_ni_sig;
  logic                              jtag_tdi_i_sig;
  logic                              jtag_tdo_o_sig;

  logic                              UART_rxd_sig;
  logic                              UART_txd_sig;


  xilinx_core_v_mini_mcu_wrapper core_mcu_wrapper(
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
    .spi_flash_sd_io(spi_flash_sd_io),
    .spi_flash_csb_o(spi_flash_csb_o),
    .spi_flash_sck_o(spi_flash_sck_o),
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
      .gpio_jtag_tdo_o(jtag_tdo_o_sig)
  );





endmodule
