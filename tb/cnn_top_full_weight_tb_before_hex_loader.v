`timescale 1ns/1ps

module cnn_top_full_weight_tb;

    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH  = 40;

    localparam IMG_W      = 28*28*DATA_WIDTH;
    localparam CONV1_W    = 10*1*9*DATA_WIDTH;
    localparam CONV2_W    = 10*10*9*DATA_WIDTH;
    localparam CONV3_W    = 10*10*9*DATA_WIDTH;
    localparam CONV4_W    = 10*10*9*DATA_WIDTH;
    localparam BIAS_W     = 10*DATA_WIDTH;
    localparam FC_W       = 10*490*DATA_WIDTH;
    localparam SCORE_W    = 10*DATA_WIDTH;

    reg clk;
    reg rst_n;
    reg start;

    reg signed [IMG_W-1:0] image_in;

    reg signed [CONV1_W-1:0] conv1_weights;
    reg signed [BIAS_W-1:0]  conv1_bias;

    reg signed [CONV2_W-1:0] conv2_weights;
    reg signed [BIAS_W-1:0]  conv2_bias;

    reg signed [CONV3_W-1:0] conv3_weights;
    reg signed [BIAS_W-1:0]  conv3_bias;

    reg signed [CONV4_W-1:0] conv4_weights;
    reg signed [BIAS_W-1:0]  conv4_bias;

    reg signed [FC_W-1:0] fc_weights;

    reg        fc_bias_sram_en;
    reg        fc_bias_sram_we;
    reg  [7:0] fc_bias_sram_addr;
    reg  [7:0] fc_bias_sram_wdata;
    wire [7:0] fc_bias_sram_rdata;

    wire busy;
    wire valid_out;
    wire signed [SCORE_W-1:0] class_scores;

    integer i, ch;
    integer cycle_count;
    integer error_count;

    reg signed [DATA_WIDTH-1:0] got;
    reg signed [DATA_WIDTH-1:0] expected;

    // instantiate top-level CNN
    cnn_top_parallel_sram_fc_bias #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .image_in(image_in),

        .conv1_weights(conv1_weights),
        .conv1_bias(conv1_bias),

        .conv2_weights(conv2_weights),
        .conv2_bias(conv2_bias),

        .conv3_weights(conv3_weights),
        .conv3_bias(conv3_bias),

        .conv4_weights(conv4_weights),
        .conv4_bias(conv4_bias),

        .fc_weights(fc_weights),

        .fc_bias_sram_en(fc_bias_sram_en),
        .fc_bias_sram_we(fc_bias_sram_we),
        .fc_bias_sram_addr(fc_bias_sram_addr),
        .fc_bias_sram_wdata(fc_bias_sram_wdata),
        .fc_bias_sram_rdata(fc_bias_sram_rdata),

        .busy(busy),
        .valid_out(valid_out),
        .class_scores(class_scores)
    );

    initial begin
        clk = 1'b0;
        forever #50 clk = ~clk;
    end

    task sram_write_byte;
        input [7:0] addr;
        input [7:0] data;
        begin
            @(negedge clk);
            fc_bias_sram_en    = 1'b1;
            fc_bias_sram_we    = 1'b1;
            fc_bias_sram_addr  = addr;
            fc_bias_sram_wdata = data;
            @(negedge clk);
            fc_bias_sram_en    = 1'b0;
            fc_bias_sram_we    = 1'b0;
        end
    endtask

    // start pulse
    task pulse_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    // load input, weights dari hex files
    initial begin
        $dumpfile("tb/cnn_top_full_weight_tb.vcd");
        $dumpvars(0, cnn_top_full_weight_tb);

        $display("=== CNN TOP FULL-WEIGHT TB START ===");

        rst_n = 1'b0;
        start = 1'b0;

        image_in      = {IMG_W{1'b0}};
        conv1_weights = {CONV1_W{1'b0}};
        conv1_bias    = {BIAS_W{1'b0}};
        conv2_weights = {CONV2_W{1'b0}};
        conv2_bias    = {BIAS_W{1'b0}};
        conv3_weights = {CONV3_W{1'b0}};
        conv3_bias    = {BIAS_W{1'b0}};
        conv4_weights = {CONV4_W{1'b0}};
        conv4_bias    = {BIAS_W{1'b0}};
        fc_weights    = {FC_W{1'b0}};

        fc_bias_sram_en    = 1'b0;
        fc_bias_sram_we    = 1'b0;
        fc_bias_sram_addr  = 8'd0;
        fc_bias_sram_wdata = 8'd0;

        error_count = 0;

        // Input image: bisa semua 1 atau load dari hex file
        for (i=0;i<28*28;i=i+1) begin
            image_in[i*DATA_WIDTH +: DATA_WIDTH] = 16'sd1;
        end

        // Load convolution weight / FC weight dari file hex
        // $readmemh("fc_weights_hex.txt", ...); atau conv_weights_hex.txt
        // Contoh placeholder:
        //$readmemh("conv1_weights_hex.txt", conv1_weights_array);

        // FC bias SRAM diisi 0
        for (i=0;i<20;i=i+1) sram_write_byte(i[7:0],8'h00);

        rst_n = 1'b1;
        repeat (5) @(negedge clk);

        $display("[TB] Starting full-weight inference...");
        pulse_start();

        cycle_count = 0;
        while(valid_out !== 1'b1 && cycle_count < 50000) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        $display("[TB] valid_out received after %0d cycles.", cycle_count);
        $display("[TB] class_scores:");
        for (i=0;i<10;i=i+1) begin
            got = class_scores[i*DATA_WIDTH +: DATA_WIDTH];
            $display("  class_scores[%0d] = 0x%04h signed=%0d",
                     i, got[15:0], got);
        end

        $display("[TB][INFO] Full-weight top-level test completed.");
        $finish;
    end

endmodule
