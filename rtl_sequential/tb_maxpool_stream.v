`timescale 1ns/1ps

module tb_maxpool_stream;
    parameter DATA_WIDTH = 16;
    parameter IMG_WIDTH = 4; // Use small width for testing
    
    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] data_in;
    
    wire valid_out;
    wire signed [DATA_WIDTH-1:0] data_out;
    
    cnn_maxpool_stream #(
        .DATA_WIDTH(16),
        .IMG_WIDTH(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .data_out(data_out)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    initial begin
        $dumpfile("tb_maxpool.vcd");
        $dumpvars(0, tb_maxpool_stream);
        rst_n = 0;
        valid_in = 0;
        data_in = 0;
        #15 rst_n = 1;
        
        // Row 1
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd5};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd10};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd3};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd2};
        
        // Row 2
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd12};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd8};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd15};
        @(posedge clk) {valid_in, data_in} = {1'b1, 16'd6};
        
        @(posedge clk) valid_in = 0;
        #20 $finish;
    end
    
    always @(posedge clk) begin
        if(valid_out) $display("MaxPool Out: %d", data_out);
    end
endmodule
