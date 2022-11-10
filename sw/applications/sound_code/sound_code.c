// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "hart.h"
#include "handler.h"
#include "core_v_mini_mcu.h"
#include "rv_timer.h"
#include "rv_timer_regs.h"
#include "soc_ctrl.h"
#include "rv_plic.h"
#include "rv_plic_regs.h"
#include "spi_host.h"
#include "spi_host_regs.h"
#include "dma.h"
#include "fast_intr_ctrl.h"
#include "gpio.h"
#include "fast_intr_ctrl_regs.h"

#define N_SAMPLES 1024

#define REVERT_24b_ADDR(addr) ((((uint32_t)addr & 0xff0000) >> 16) | ((uint32_t)addr & 0xff00) | (((uint32_t)addr & 0xff) << 16))

#define FLASH_ADDR 0x00000000 // 256B data alignment

#define FLASH_CLK_MAX_HZ (133 * 1000 * 1000) // In Hz (133 MHz for the flash w25q128jvsim used in the EPFL Programmer)

static rv_timer_t timer;
static const uint64_t kTickFreqHz = 1000 * 1000; // 1 MHz

// Interrupt controller variables
dif_plic_params_t rv_plic_params;
dif_plic_t rv_plic;
dif_plic_result_t plic_res;
dif_plic_irq_id_t intr_num;

volatile int8_t timer_flag;
volatile int8_t spi_intr_flag;
volatile int8_t dma_intr_flag;

// DEBUG
gpio_params_t gpio_params;
gpio_t gpio;
gpio_result_t gpio_res;
#define DEBUG_PIN 2
bool gpio_state = false;

uint16_t sin_lookup[N_SAMPLES];

// NOTE: Do i have to clear the IRQ timer?
void handler_irq_timer(void)
{
    // fast_intr_ctrl_t fast_intr_ctrl;
    // fast_intr_ctrl.base_addr = mmio_region_from_addr((uintptr_t)FAST_INTR_CTRL_START_ADDRESS);
    // clear_fast_interrupt(&fast_intr_ctrl, kTimer_1_fic_e);
    mmio_region_write32(timer.base_addr, RV_TIMER_TIMER_V_LOWER0_REG_OFFSET, 0);
    mmio_region_write32(timer.base_addr, RV_TIMER_TIMER_V_UPPER0_REG_OFFSET, 0);
    rv_timer_irq_clear(&timer, 0, 0);
    //if (gpio_state == false)
        //gpio_state = true;
    //else
        //gpio_state = false;
    //gpio_write(&gpio, DEBUG_PIN, gpio_state);
    timer_flag = 1;
}

spi_host_t spi_host_dac;
spi_host_t spi_host_adc;
spi_host_t spi_host_flash;

void handler_irq_fast_spi_flash(void)
{
    // Disable SPI interrupts
    spi_enable_evt_intr(&spi_host_flash, false);
    spi_enable_rxwm_intr(&spi_host_flash, false);
    // Clear fast interrupt
    fast_intr_ctrl_t fast_intr_ctrl;
    fast_intr_ctrl.base_addr = mmio_region_from_addr((uintptr_t)FAST_INTR_CTRL_START_ADDRESS);
    clear_fast_interrupt(&fast_intr_ctrl, kSpiFlash_fic_e);
    spi_intr_flag = 1;
}

void handler_irq_fast_dma(void)
{
    fast_intr_ctrl_t fast_intr_ctrl;
    fast_intr_ctrl.base_addr = mmio_region_from_addr((uintptr_t)FAST_INTR_CTRL_START_ADDRESS);
    clear_fast_interrupt(&fast_intr_ctrl, kDma_fic_e);
    dma_intr_flag = 1;
}

enum CHANNEL
{
    A = 0x0,
    B = 0x1,
    C = 0x2,
    D = 0x3,
    E = 0x4,
    F = 0x5,
    G = 0x6,
    H = 0x7,
    ALL = 0xF
};

static inline __attribute__((always_inline)) uint16_t adc_2_dac_scale(uint16_t val)
{
    uint32_t temp = ((uint32_t)val * 330) / 250;
    return (uint32_t)temp & 0xFFFF;
}

#define PI 3.14159265f

void prepare_sin_table(uint16_t *samples, uint32_t sample_count, uint32_t freq, uint32_t sampling_freq)
{
    for (uint32_t i = 0; i < sample_count; ++i)
    {
        float t = (float)i / sampling_freq;
        float signal = round((sin(2 * PI * freq * t) + 1) * 4095) / 2;
        samples[i] = (uint16_t)(signal);
    }
}

void set_voltage(spi_host_t *SPI, enum CHANNEL ch, uint32_t val)
{
    uint32_t cmd = 0x03000000 | (ch << 20) | ((val & 0xFFF) << 8);
    spi_write_word(SPI, __builtin_bswap32(cmd)); // This sends the given command according to the mode specified in the command fifo
    const uint32_t cmd_set_voltage = spi_create_command((spi_command_t){
        .len = 3, // It's tot len - 1
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(SPI, cmd_set_voltage); // This writes the command information in the command fifo
    spi_wait_for_ready(SPI);
}

uint16_t get_voltage(spi_host_t *SPI)
{
    // spi_wait_for_ready(SPI);
    const uint32_t cmd_get_voltage = spi_create_command((spi_command_t){
        .len = 1,       // It's tot len - 1
        .csaat = false, // Chip Select Active After Transaction (to keep it activated)
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirRxOnly});
    spi_set_command(SPI, cmd_get_voltage);
    spi_wait_for_ready(SPI);
    spi_wait_for_rx_watermark(SPI);
    uint32_t res;
    spi_read_word(SPI, &res);
    return ((uint16_t)(res & 0xFFF));
}

void write_to_flash(spi_host_t *SPI, dma_t *DMA, uint16_t *data, uint32_t byte_count, uint32_t addr)
{
    uint32_t chunks = byte_count / 256;
    uint32_t remainder = byte_count % 256;
    printf("Chunks: %u, remainer: %u\n\r", chunks, remainder);
    // We can write only 256 bytes at a time.
    uint32_t i;
    for(i = 0; i < chunks; ++i)
    {
        write_to_flash_256_bytes_max(SPI, DMA, (uint8_t*)data + 256*i, 256, addr + 256*i);
    }
    if(remainder)
        write_to_flash_256_bytes_max(SPI, DMA, (uint8_t*)data + 256*i, remainder, i*256);
}

void write_to_flash_256_bytes_max(spi_host_t *SPI, dma_t *DMA, uint16_t *data, uint32_t byte_count, uint32_t addr)
{
    printf("Writing to flash %u bytes at addr %u\n\r", byte_count, addr);
    // Write enable
    const uint32_t write_enable_cmd = 0x06;
    spi_write_word(SPI, write_enable_cmd);
    const uint32_t cmd_write_en = spi_create_command((spi_command_t){
        .len = 0,
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(SPI, cmd_write_en);
    spi_wait_for_ready(SPI);

    // Write command
    const uint32_t write_byte_cmd = ((addr<< 8) | 0x02); // Program Page + addr
    spi_write_word(SPI, write_byte_cmd);
    const uint32_t cmd_write = spi_create_command((spi_command_t){
        .len = 3,
        .csaat = true,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(SPI, cmd_write);
    spi_wait_for_ready(SPI);

    uint32_t *fifo_ptr_tx = SPI->base_addr.base + SPI_HOST_TXDATA_REG_OFFSET;

    // -- DMA CONFIGURATION --
    // NOTE: 16-bit --> 2
    dma_set_read_ptr_inc(DMA, (uint32_t)2);                  // Do not increment address when reading from the SPI (Pop from FIFO)
    dma_set_write_ptr_inc(DMA, (uint32_t)0);                 // Do not increment address when reading from the SPI (Pop from FIFO)
    dma_set_read_ptr(DMA, (uint32_t)data);                   // SPI RX FIFO addr
    dma_set_write_ptr(DMA, (uint32_t)fifo_ptr_tx);           // copy data address
                                                             //
                                                             //
                                                             // Set the correct SPI-DMA mode:
                                                             // (0) disable
                                                             // (1) receive from SPI (use SPI_START_ADDRESS for spi_host pointer)
                                                             // (2) send to SPI (use SPI_START_ADDRESS for spi_host pointer)
                                                             // (3) receive from SPI FLASH (use SPI_FLASH_START_ADDRESS for spi_host pointer)
                                                             // (4) send to SPI FLASH (use SPI_FLASH_START_ADDRESS for spi_host pointer)
    dma_set_spi_mode(DMA, (uint32_t)4);                      // The DMA will wait for the SPI FLASH TX FIFO ready signal
    dma_set_data_type(DMA, (uint32_t)1);                     // NOTE: 16-bit
    dma_set_cnt_start(DMA, (uint32_t)byte_count); // Size of data received by SPI

    // Wait for the first data to arrive to the TX FIFO before enabling interrupt
    spi_wait_for_tx_not_empty(SPI);
    // Enable event interrupt
    spi_enable_evt_intr(SPI, true);
    // Enable TX empty interrupt
    spi_enable_txempty_intr(SPI, true);

    const uint32_t cmd_write_tx = spi_create_command((spi_command_t){
        .len = byte_count - 1,
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(SPI, cmd_write_tx);
    spi_wait_for_ready(SPI);

    // Wait for SPI interrupt
    printf("Waiting for the SPI interrupt...\n\r");
    while (spi_intr_flag == 0)
    {
        wait_for_interrupt();
    }
    printf("triggered!\n\r");

    // Check status register status waiting for ready
    bool flash_busy = true;
    uint8_t flash_resp[4] = {0xff, 0xff, 0xff, 0xff};
    while (flash_busy)
    {
        uint32_t flash_cmd = 0x00000005; // [CMD] Read status register
        spi_write_word(SPI, flash_cmd);  // Push TX buffer
        uint32_t spi_status_cmd = spi_create_command((spi_command_t){
            .len = 0,
            .csaat = true,
            .speed = kSpiSpeedStandard,
            .direction = kSpiDirTxOnly});
        uint32_t spi_status_read_cmd = spi_create_command((spi_command_t){
            .len = 0,
            .csaat = false,
            .speed = kSpiSpeedStandard,
            .direction = kSpiDirRxOnly});
        spi_set_command(SPI, spi_status_cmd);
        spi_wait_for_ready(SPI);
        spi_set_command(SPI, spi_status_read_cmd);
        spi_wait_for_ready(SPI);
        spi_wait_for_rx_watermark(SPI);
        spi_read_word(SPI, &flash_resp[0]);
        if ((flash_resp[0] & 0x01) == 0)
            flash_busy = false;
    }
    printf("Finished Writing to Flash!\n\r");
}

int main(int argc, char *argv[])
{

    // dif_plic_params_t rv_plic_params;
    // rv_plic_params.base_addr = mmio_region_from_addr((uintptr_t)PLIC_START_ADDRESS);
    // dif_plic_init(rv_plic_params, &rv_plic);

    gpio_params.base_addr = mmio_region_from_addr((uintptr_t)GPIO_START_ADDRESS);
    gpio_res = gpio_init(gpio_params, &gpio);
    gpio_res = gpio_output_set_enabled(&gpio, DEBUG_PIN, true);

    // Get current Frequency
    soc_ctrl_t soc_ctrl;
    soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
    uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);
    soc_ctrl_select_spi_host(&soc_ctrl); // IS THIS CORRECT EVEN WITH TWO SPIs?

    uint32_t core_clk = soc_ctrl_get_frequency(&soc_ctrl);

    // Enable interrupt on processor side
    // Enable global interrupt for machine-level interrupts
    CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    uint32_t mask = 1 << 21;
    CSR_SET_BITS(CSR_REG_MIE, mask);
    spi_intr_flag = 0;
    // Set mie.MEIE bit to one to enable timer interrupt
    mask = 1 << 7; // ;
    CSR_SET_BITS(CSR_REG_MIE, mask);
    timer_flag = 0;

    spi_host_dac.base_addr = mmio_region_from_addr((uintptr_t)SPI_START_ADDRESS);
    spi_set_enable(&spi_host_dac, true);
    spi_output_enable(&spi_host_dac, true);

    spi_host_adc.base_addr = mmio_region_from_addr((uintptr_t)SPI2_START_ADDRESS);
    spi_set_enable(&spi_host_adc, true);
    spi_output_enable(&spi_host_adc, true);

    spi_host_flash.base_addr = mmio_region_from_addr((uintptr_t)SPI_FLASH_START_ADDRESS);
    spi_set_enable(&spi_host_flash, true);
    spi_output_enable(&spi_host_flash, true);

    dma_t dma;
    dma.base_addr = mmio_region_from_addr((uintptr_t)DMA_START_ADDRESS);

    uint32_t *fifo_ptr_tx = spi_host_flash.base_addr.base + SPI_HOST_TXDATA_REG_OFFSET;
    uint32_t *fifo_ptr_rx = spi_host_flash.base_addr.base + SPI_HOST_RXDATA_REG_OFFSET;

    const uint32_t chip_cfg_dac = spi_create_configopts((spi_configopts_t){
        .clkdiv = 0, // 50 MHz
        .csnidle = 0x0,
        .csntrail = 0x0,
        .csnlead = 0x0,
        .fullcyc = false,
        .cpha = 1,
        .cpol = 0});
    spi_set_configopts(&spi_host_dac, 0, chip_cfg_dac);
    spi_set_csid(&spi_host_dac, 0);
    // spi_set_rx_watermark(&spi_host_dac, 4);

    const uint32_t chip_cfg_adc = spi_create_configopts((spi_configopts_t){
        .clkdiv = 0, // 50 MHz
        .csnidle = 0x0,
        .csntrail = 0x0,
        .csnlead = 0x0,
        .fullcyc = false,
        .cpha = 0,
        .cpol = 0});
    spi_set_configopts(&spi_host_adc, 0, chip_cfg_adc); // CSID is chipselect id of the SPI-> since we use different SPIs they can be the same
    spi_set_csid(&spi_host_adc, 0);                     // This set the current chip select to use-> if we share same SPI we ned to change chip select before each communication
    spi_set_rx_watermark(&spi_host_adc, 1);

    uint16_t clk_div = 0;
    if (FLASH_CLK_MAX_HZ < core_clk / 2)
    {
        clk_div = (core_clk / (FLASH_CLK_MAX_HZ)-2) / 2; // The value is truncated
        if (core_clk / (2 + 2 * clk_div) > FLASH_CLK_MAX_HZ)
            clk_div += 1; // Adjust if the truncation was not 0
    }
    printf("Divison Factor: %u\n\r", clk_div);
    // SPI Configuration
    // Configure chip 0 (flash memory)
    const uint32_t chip_cfg_flash = spi_create_configopts((spi_configopts_t){
        .clkdiv = clk_div,
        .csnidle = 0xF,
        .csntrail = 0xF,
        .csnlead = 0xF,
        .fullcyc = false,
        .cpha = 0,
        .cpol = 0});
    spi_set_configopts(&spi_host_flash, 0, chip_cfg_flash);
    spi_set_csid(&spi_host_flash, 0);

    // Setup rv_timer
    mmio_region_t timer_reg = mmio_region_from_addr(RV_TIMER_AO_START_ADDRESS);
    rv_timer_init(timer_reg, (rv_timer_config_t){.hart_count = 1, .comparator_count = 1}, &timer);
    rv_timer_tick_params_t tick_params;
    if (rv_timer_approximate_tick_params(freq_hz, kTickFreqHz, &tick_params) != kRvTimerOk)
    {
        printf("Failure setting tick timer\r\n");
        return EXIT_FAILURE;
    }
    rv_timer_set_tick_params(&timer, 0, tick_params);
    rv_timer_irq_enable(&timer, 0, 0, kRvTimerEnabled);
    rv_timer_arm(&timer, 0, 0, 10);

    // DAC configuration
    uint32_t cmd = 0x01000008;
    spi_write_word(&spi_host_dac, cmd); // This sends the given command according to the mode specified in the command fifo
    const uint32_t cmd_init = spi_create_command((spi_command_t){
        .len = 3, // It's tot len - 1
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(&spi_host_dac, cmd_init); // This writes the command information in the command fifo
    spi_wait_for_ready(&spi_host_dac);

    const uint32_t reset_cmd = 0xFFFFFFFF;
    spi_write_word(&spi_host_flash, reset_cmd);
    const uint32_t cmd_reset = spi_create_command((spi_command_t){
        .len = 3,
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(&spi_host_flash, cmd_reset);
    spi_wait_for_ready(&spi_host_flash);
    spi_set_rx_watermark(&spi_host_flash, 1);

    // Power up flash
    const uint32_t powerup_byte_cmd = 0xab;
    spi_write_word(&spi_host_flash, powerup_byte_cmd);
    const uint32_t cmd_powerup = spi_create_command((spi_command_t){
        .len = 0,
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(&spi_host_flash, cmd_powerup);
    spi_wait_for_ready(&spi_host_flash);

    prepare_sin_table(sin_lookup, N_SAMPLES, 1000, 80000);

    rv_timer_counter_set_enabled(&timer, 0, kRvTimerEnabled);

    volatile uint16_t results[N_SAMPLES];

/*
    for(uint32_t i = 0; i < N_SAMPLES; i += 4)
    {
        while(!timer_flag);
        timer_flag= 0;
        set_voltage(&spi_host_dac, ALL, sin_lookup[i]);
        for (volatile uint32_t k = 0; k < 5; ++k)
            ;
        results[i] = (get_voltage(&spi_host_adc));
        while(!timer_flag);
        timer_flag= 0;
        set_voltage(&spi_host_dac, ALL, sin_lookup[i+1]);
        for (volatile uint32_t k = 0; k < 5; ++k)
            ;
        results[i+1] = (get_voltage(&spi_host_adc));
        while(!timer_flag);
        timer_flag= 0;
        set_voltage(&spi_host_dac, ALL, sin_lookup[i+2]);
        for (volatile uint32_t k = 0; k < 5; ++k)
            ;
        results[i+2] = (get_voltage(&spi_host_adc));
        while(!timer_flag);
        timer_flag= 0;
        set_voltage(&spi_host_dac, ALL, sin_lookup[i+3]);
        for (volatile uint32_t k = 0; k < 5; ++k)
            ;
        results[i+3] = (get_voltage(&spi_host_adc));
    }

*/
    uint32_t i = 0;
    while (1)
    {
        if (timer_flag)
        {
            timer_flag = 0;
            if (i == N_SAMPLES)
                break;
            set_voltage(&spi_host_dac, ALL, sin_lookup[i]);
            for (volatile uint32_t k = 0; k < 5; ++k)
                ;
            results[i] = (get_voltage(&spi_host_adc));
            ++i;
        }
    }
    rv_timer_reset(&timer);

    printf("Finished setting values\n\r");

    write_to_flash(&spi_host_flash, &dma, results, sizeof(*results) * N_SAMPLES, FLASH_ADDR);

    const uint32_t powerdown_byte_cmd = 0xb9;
    spi_write_word(&spi_host_flash, powerdown_byte_cmd);
    const uint32_t cmd_powerdown = spi_create_command((spi_command_t){
        .len = 0,
        .csaat = false,
        .speed = kSpiSpeedStandard,
        .direction = kSpiDirTxOnly});
    spi_set_command(&spi_host_flash, cmd_powerdown);
    spi_wait_for_ready(&spi_host_flash);

    printf("Flash powered off\n\r");

    // To catch the end of the experiment and allow us to inspect the content of the array
    while (1)
    {
        asm volatile("nop");
    };

    return EXIT_SUCCESS;
}
