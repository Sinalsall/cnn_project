`timescale 1ns/1ps

module tb_conv_pipeline;
    reg clk;
    reg rst_n;
    
    reg valid_in;
    reg signed [15:0] pixel_in;
    
    // Line buffer connections
    wire lb_valid_out;
    wire signed [15:0] w00, w01, w02;
    wire signed [15:0] w10, w11, w12;
    wire signed [15:0] w20, w21, w22;
    
    line_buffer #(.DATA_WIDTH(16), .IMG_WIDTH(4)) lb ( // Set width 4 for fast testing
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .data_in(pixel_in),
        .valid_out(lb_valid_out),
        .w00(w00), .w01(w01), .w02(w02),
        .w10(w10), .w11(w11), .w12(w12),
        .w20(w20), .w21(w21), .w22(w22)
    );
    
    wire conv_ready;
    wire conv_valid_out;
    wire signed [15:0] conv_data_out;
    wire [3:0] weight_idx;
    
    // Dummy weight feedback based on requested index
    reg signed [15:0] weight_in;
    always @(*) begin
        weight_in = weight_idx + 1; // dummy weight = index + 1
    end
    
    cnn_convolution_serial #(.DATA_WIDTH(16)) conv (
        .clk(clk), .rst_n(rst_n),
        .valid_in(lb_valid_out),
        .ready_out(conv_ready),
        .w00(w00), .w01(w01), .w02(w02),
        .w10(w10), .w11(w11), .w12(w12),
        .w20(w20), .w21(w21), .w22(w22),
        .weight_in(weight_in), .bias_in(16'd5), // static bias
        .weight_idx(weight_idx),
        .valid_out(conv_valid_out),
        .data_out(conv_data_out)
    );
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    integer i;
    initial begin
        $dumpfile("tb_conv_pipeline.vcd");
        $dumpvars(0, tb_conv_pipeline);
        
        rst_n = 0;
        valid_in = 0;
        pixel_in = 0;
        
        #15 rst_n = 1;
        
        // Feed 16 pixels (4x4 image)
        for (i=0; i<16; i=i+1) begin
            @(posedge clk);
            while(!conv_ready && lb_valid_out) @(posedge clk); // Simulate backpressure
            valid_in = 1;
            pixel_in = i + 1; // pixel value 1 to 16
        end
        @(posedge clk) valid_in = 0;
        
        // Wait flush
        #200 $finish;
    end
    
    always @(posedge clk) begin
        if (conv_valid_out) begin
            $display("Conv TDM Output valid! Out=%d", conv_data_out);
        end
    end
endmodule
