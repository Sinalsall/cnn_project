`timescale 1ns/1ps

module tb_cnn_relu_stream;
    parameter DATA_WIDTH = 16;
    
    reg clk;
    reg rst_n;
    reg valid_in;
    reg ready_in;
    reg signed [DATA_WIDTH-1:0] data_in;
    
    wire ready_out;
    wire valid_out;
    wire signed [DATA_WIDTH-1:0] data_out;
    
    cnn_relu_stream #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .data_in(data_in),
        .ready_out(ready_out),
        .valid_out(valid_out),
        .data_out(data_out)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("tb_relu_stream.vcd");
        $dumpvars(0, tb_cnn_relu_stream);
        
        rst_n = 0;
        valid_in = 0;
        ready_in = 1;
        data_in = 0;
        
        #20 rst_n = 1;

        // Test Positive value (pass through)
        @(posedge clk);
        valid_in = 1;
        data_in = 16'h0015; // +21
        
        // Test Negative value (clipped to 0)
        @(posedge clk);
        valid_in = 1;
        data_in = 16'hFFEA; // -22

        // Wait to observe output
        @(posedge clk);
        valid_in = 0;
        
        #20 $finish;
    end
endmodule
