
## Reloj de 100 MHz de la Basys3
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Botones: btnL carga A, btnR carga B
set_property PACKAGE_PIN W19 [get_ports btn_load_a]
set_property PACKAGE_PIN T17 [get_ports btn_load_b]

## Bus de datos compartido -> sw_data[7:0]  (SW0-SW7)
set_property PACKAGE_PIN V17 [get_ports {sw_data[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw_data[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw_data[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw_data[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw_data[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw_data[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw_data[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw_data[7]}]

## Codigo de operacion -> sw_op[5:0]  (SW8-SW13)
set_property PACKAGE_PIN V2  [get_ports {sw_op[0]}]
set_property PACKAGE_PIN T3  [get_ports {sw_op[1]}]
set_property PACKAGE_PIN T2  [get_ports {sw_op[2]}]
set_property PACKAGE_PIN R3  [get_ports {sw_op[3]}]
set_property PACKAGE_PIN W2  [get_ports {sw_op[4]}]
set_property PACKAGE_PIN U1  [get_ports {sw_op[5]}]

## LEDs -> resultado en LED0-LED7
set_property PACKAGE_PIN U16 [get_ports {led_result[0]}]
set_property PACKAGE_PIN E19 [get_ports {led_result[1]}]
set_property PACKAGE_PIN U19 [get_ports {led_result[2]}]
set_property PACKAGE_PIN V19 [get_ports {led_result[3]}]
set_property PACKAGE_PIN W18 [get_ports {led_result[4]}]
set_property PACKAGE_PIN U15 [get_ports {led_result[5]}]
set_property PACKAGE_PIN U14 [get_ports {led_result[6]}]
set_property PACKAGE_PIN V14 [get_ports {led_result[7]}]

## Flags en los ultimos 3 LEDs: LED13=carry, LED14=overflow, LED15=zero
set_property PACKAGE_PIN N3  [get_ports led_carry]
set_property PACKAGE_PIN P1  [get_ports led_overflow]
set_property PACKAGE_PIN L1  [get_ports led_zero]

## Nivel logico de todos los puertos
set_property IOSTANDARD LVCMOS33 [get_ports {btn_load_a btn_load_b sw_data[*] sw_op[*] led_result[*] led_carry led_overflow led_zero}]