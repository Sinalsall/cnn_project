create_clock [get_ports clk] -period 100.000

set_false_path -from [get_ports rst_n]

set sync_inputs [get_ports {valid_in last_in pixel_in[*] param_wr_en param_wr_addr[*] param_wr_data[*]}]
set_input_delay -min 1.000 -clock [get_clocks clk] $sync_inputs
set_input_delay -max 20.000 -clock [get_clocks clk] $sync_inputs

set_output_delay -min 1.000 -clock [get_clocks clk] [all_outputs]
set_output_delay -max 20.000 -clock [get_clocks clk] [all_outputs]
