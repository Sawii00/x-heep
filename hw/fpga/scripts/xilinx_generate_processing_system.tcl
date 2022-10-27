create_bd_design "processing_system"
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_EN_CLK0_PORT {0} CONFIG.PCW_EN_RST0_PORT {0} CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} CONFIG.PCW_GPIO_EMIO_GPIO_IO {5}] [get_bd_cells processing_system7_0]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
#make_bd_intf_pins_external  [get_bd_intf_pins processing_system7_0/GPIO_0]
#set_property name PS_GPIO2JTAG [get_bd_intf_ports GPIO_0_0]

create_bd_port -dir I gpio_jtag_tdo_o
create_bd_port -dir O gpio_jtag_tdi_i
create_bd_port -dir O gpio_jtag_tms_i
create_bd_port -dir O gpio_jtag_trst_ni
create_bd_port -dir O gpio_jtag_tck_i

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3

set_property -dict [list CONFIG.DIN_TO {3} CONFIG.DIN_FROM {3} CONFIG.DIN_WIDTH {5} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_0]
set_property -dict [list CONFIG.DIN_TO {4} CONFIG.DIN_FROM {4} CONFIG.DIN_WIDTH {5} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_1]
set_property -dict [list CONFIG.DIN_TO {1} CONFIG.DIN_FROM {1} CONFIG.DIN_WIDTH {5} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_2]
set_property -dict [list CONFIG.DIN_TO {0} CONFIG.DIN_FROM {0} CONFIG.DIN_WIDTH {5} CONFIG.DOUT_WIDTH {1}] [get_bd_cells xlslice_3]


connect_bd_net [get_bd_pins xlslice_0/Din] [get_bd_pins processing_system7_0/GPIO_O]
connect_bd_net [get_bd_pins xlslice_1/Din] [get_bd_pins processing_system7_0/GPIO_O]
connect_bd_net [get_bd_pins xlslice_2/Din] [get_bd_pins processing_system7_0/GPIO_O]
connect_bd_net [get_bd_pins xlslice_3/Din] [get_bd_pins processing_system7_0/GPIO_O]

connect_bd_net [get_bd_ports gpio_jtag_tdi_i] [get_bd_pins xlslice_0/Dout]
connect_bd_net [get_bd_ports gpio_jtag_tck_i] [get_bd_pins xlslice_1/Dout]
connect_bd_net [get_bd_ports gpio_jtag_tms_i] [get_bd_pins xlslice_2/Dout]
connect_bd_net [get_bd_ports gpio_jtag_trst_ni] [get_bd_pins xlslice_3/Dout]


create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
set_property -dict [list CONFIG.CONST_WIDTH {2} CONFIG.CONST_VAL {0b11}] [get_bd_cells xlconstant_0]

set_property -dict [list CONFIG.IN0_WIDTH.VALUE_SRC USER CONFIG.IN1_WIDTH.VALUE_SRC USER CONFIG.IN2_WIDTH.VALUE_SRC USER] [get_bd_cells xlconcat_0]
set_property -dict [list CONFIG.NUM_PORTS {3} CONFIG.IN0_WIDTH {2} CONFIG.IN2_WIDTH {2}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/GPIO_I]
connect_bd_net [get_bd_ports gpio_jtag_tdo_o] [get_bd_pins xlconcat_0/In1]

# ILA
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila_0
set_property -dict [list CONFIG.PCW_EN_CLK0_PORT {1}] [get_bd_cells processing_system7_0]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins ila_0/clk]
set_property -dict [list CONFIG.C_NUM_OF_PROBES {4} CONFIG.C_ENABLE_ILA_AXI_MON {false} CONFIG.C_MONITOR_TYPE {Native}] [get_bd_cells ila_0]
connect_bd_net [get_bd_pins ila_0/probe0] [get_bd_pins xlslice_0/Dout]
connect_bd_net [get_bd_pins ila_0/probe1] [get_bd_pins xlslice_1/Dout]
connect_bd_net [get_bd_pins ila_0/probe2] [get_bd_pins xlslice_2/Dout]
connect_bd_net [get_bd_pins ila_0/probe3] [get_bd_pins xlslice_3/Dout]


save_bd_design
close_bd_design "processing_system"

set wrapper_path [ make_wrapper -fileset sources_1 -files [ get_files -norecurse processing_system.bd ] -top ]
add_files -norecurse -fileset sources_1 $wrapper_path