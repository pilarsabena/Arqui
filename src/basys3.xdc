
set_property PACKAGE_PIN W5 [get_ports i_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_clk]

create_clock -period 10.000 -name sys_clk_pin -waveform {0 5} -add [get_ports i_clk]

## Botones
set_property PACKAGE_PIN T18 [get_ports i_reset]     ;# BTNU
set_property IOSTANDARD LVCMOS33 [get_ports i_reset]

set_property PACKAGE_PIN U17 [get_ports i_load_a]    ;# BTND
set_property IOSTANDARD LVCMOS33 [get_ports i_load_a]

set_property PACKAGE_PIN T17 [get_ports i_load_b]    ;# BTNR
set_property IOSTANDARD LVCMOS33 [get_ports i_load_b]

set_property PACKAGE_PIN W19 [get_ports i_load_c]    ;# BTNL
set_property IOSTANDARD LVCMOS33 [get_ports i_load_c]

## Switches SW8 a SW15 -> i_switches[0] a i_switches[7]
set_property PACKAGE_PIN V2 [get_ports {i_switches[0]}]
set_property PACKAGE_PIN T3 [get_ports {i_switches[1]}]
set_property PACKAGE_PIN T2 [get_ports {i_switches[2]}]
set_property PACKAGE_PIN R3 [get_ports {i_switches[3]}]
set_property PACKAGE_PIN W2 [get_ports {i_switches[4]}]
set_property PACKAGE_PIN U1 [get_ports {i_switches[5]}]
set_property PACKAGE_PIN T1 [get_ports {i_switches[6]}]
set_property PACKAGE_PIN R2 [get_ports {i_switches[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i_switches[*]}]

## LEDs LD8 a LD15 -> o_leds[0] a o_leds[7]
set_property PACKAGE_PIN V13 [get_ports {o_leds[0]}]
set_property PACKAGE_PIN V3  [get_ports {o_leds[1]}]
set_property PACKAGE_PIN W3  [get_ports {o_leds[2]}]
set_property PACKAGE_PIN U3  [get_ports {o_leds[3]}]
set_property PACKAGE_PIN P3  [get_ports {o_leds[4]}]
set_property PACKAGE_PIN N3  [get_ports {o_leds[5]}]
set_property PACKAGE_PIN P1  [get_ports {o_leds[6]}]
set_property PACKAGE_PIN L1  [get_ports {o_leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {o_leds[*]}]
