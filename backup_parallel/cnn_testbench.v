// ==========================================
// CNN RTL Simulation Testbench
// ==========================================
// Tests basic functionality of CNN modules
`timescale 1ns/1ps

module cnn_testbench;

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 8;

    // Signals
    reg clk;
    reg rst_n;
    
    // Convolution signals
    reg conv_valid_in;
    reg signed [DATA_WIDTH-1:0] conv_pixel_in;
    reg signed [DATA_WIDTH-1:0] kernel [0:8];
    reg signed [15:0] bias;
    wire conv_valid_out;
    wire signed [15:0] conv_pixel_out;
    
    // MaxPool signals
    reg pool_valid_in;
    reg signed [DATA_WIDTH-1:0] pool_pixel_in;
    wire pool_valid_out;
    wire signed [DATA_WIDTH-1:0] pool_pixel_out;
    
    // ReLU signals
    reg relu_valid_in;
    reg signed [15:0] relu_data_in;
    wire relu_valid_out;
    wire signed [15:0] relu_data_out;

    // Instantiate modules
    cnn_convolution #(.DATA_WIDTH(DATA_WIDTH), .IMG_SIZE(28)) 
    conv_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(conv_valid_in),
        .pixel_in(conv_pixel_in),
        .kernel(kernel),
        .bias(bias),
        .valid_out(conv_valid_out),
        .pixel_out(conv_pixel_out)
    );

    cnn_maxpool #(.DATA_WIDTH(DATA_WIDTH), .INPUT_SIZE(28))
    pool_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(pool_valid_in),
        .pixel_in(pool_pixel_in),
        .valid_out(pool_valid_out),
        .pixel_out(pool_pixel_out)
    );

    cnn_relu #(.DATA_WIDTH(16))
    relu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(relu_valid_in),
        .data_in(relu_data_in),
        .valid_out(relu_valid_out),
        .data_out(relu_data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        conv_valid_in = 0;
        pool_valid_in = 0;
        relu_valid_in = 0;

        // Initialize kernel (3x3 Sobel-like kernel)
        kernel[0] = -1;  kernel[1] = 0;  kernel[2] = 1;
        kernel[3] = -2;  kernel[4] = 1;  kernel[5] = 2;
        kernel[6] = -1;  kernel[7] = 0;  kernel[8] = 1;
        bias = 16'h0000;

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Test 1: Convolution
        #(CLK_PERIOD * 2);
        $display("=== Test 1: Convolution ===");
        conv_valid_in = 1;
        conv_pixel_in = 8'd50;
        #(CLK_PERIOD);
        conv_pixel_in = 8'd60;
        #(CLK_PERIOD);
        conv_valid_in = 0;

        // Test 2: MaxPool
        #(CLK_PERIOD * 2);
        $display("=== Test 2: MaxPool ===");
        pool_valid_in = 1;
        pool_pixel_in = 8'd20;
        #(CLK_PERIOD);
        pool_pixel_in = 8'd30;
        #(CLK_PERIOD);
        pool_pixel_in = 8'd25;
        #(CLK_PERIOD);
        pool_pixel_in = 8'd15;
        #(CLK_PERIOD);
        pool_valid_in = 0;

        // Test 3: ReLU
        #(CLK_PERIOD * 2);
        $display("=== Test 3: ReLU ===");
        relu_valid_in = 1;
        relu_data_in = 16'h0100;  // Positive value
        #(CLK_PERIOD);
        $display("ReLU Input: %d, Output: %d", relu_data_in, relu_data_out);
        relu_data_in = 16'hFF00;  // Negative value (two's complement)
        #(CLK_PERIOD);
        $display("ReLU Input: %d, Output: %d", relu_data_in, relu_data_out);
        relu_valid_in = 0;

        #(CLK_PERIOD * 1000);
        $display("=== Simulation Complete ===");
        $finish;
    end

    // Monitor signals
    initial begin
        $monitor("Time=%0t | Conv: valid=%b out=%d | Pool: valid=%b out=%d | ReLU: valid=%b out=%d",
                 $time, conv_valid_out, conv_pixel_out, 
                 pool_valid_out, pool_pixel_out,
                 relu_valid_out, relu_data_out);
    end

    // VCD file generation for GTKWave
    initial begin
        $dumpfile("cnn_simulation.vcd");
        $dumpvars(0, cnn_testbench);
    end
    initial begin
        #10000;
        $display("Force end at 10us");
        $finish;
    end
endmodule
