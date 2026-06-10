create_clock [get_ports clk] -period 100.000
set_input_delay 0.000 -clock [get_clocks clk] [get_ports {rst_n valid_in last_in pixel_in[*] mem_resp_data[*]}]
set_output_delay 0.000 -clock [get_clocks clk] [all_outputs]
