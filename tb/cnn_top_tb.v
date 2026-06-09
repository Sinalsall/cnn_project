`timescale 1ns/1ps

module cnn_top_tb;

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

    reg [15:0] fc_bias_mem [0:9];

    integer i;
    integer cycle_count;
    integer error_count;

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

    // 100 ns clock period.
    // This is intentionally slow enough for the GF180 SRAM simulation model timing checks.
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
            fc_bias_sram_addr  = 8'd0;
            fc_bias_sram_wdata = 8'd0;
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("tb/cnn_top_tb.vcd");
        $dumpvars(0, cnn_top_tb.clk);
        $dumpvars(0, cnn_top_tb.rst_n);
        $dumpvars(0, cnn_top_tb.start);
        $dumpvars(0, cnn_top_tb.busy);
        $dumpvars(0, cnn_top_tb.valid_out);
        $dumpvars(0, cnn_top_tb.fc_bias_sram_en);
        $dumpvars(0, cnn_top_tb.fc_bias_sram_we);
        $dumpvars(0, cnn_top_tb.fc_bias_sram_addr);
        $dumpvars(0, cnn_top_tb.fc_bias_sram_wdata);
        $dumpvars(0, cnn_top_tb.fc_bias_sram_rdata);
        $dumpvars(0, cnn_top_tb.class_scores);

        $display("=== CNN TOP TB START ===");

        // Default input stimulus.
        rst_n = 1'b0;
        start = 1'b0;

        image_in = {IMG_W{1'b0}};

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

        // Load FC bias hex file.
        // Expected path when simulation is run from:
        // /foss/designs/RTL/RTL/RTL_Design
        $readmemh("fc_bias_hex.txt", fc_bias_mem);

        repeat (5) @(negedge clk);
        rst_n = 1'b1;

        repeat (2) @(negedge clk);

        $display("[TB] Writing FC bias bytes into SRAM...");
        for (i = 0; i < 10; i = i + 1) begin
            sram_write_byte(2*i,     fc_bias_mem[i][7:0]);
            sram_write_byte(2*i + 1, fc_bias_mem[i][15:8]);

            $display("[TB] bias[%0d] = 0x%04h written as low=0x%02h high=0x%02h",
                     i, fc_bias_mem[i], fc_bias_mem[i][7:0], fc_bias_mem[i][15:8]);
        end

        repeat (5) @(negedge clk);

        $display("[TB] Starting CNN inference...");
        pulse_start();

        cycle_count = 0;
        while ((valid_out !== 1'b1) && (cycle_count < 20000)) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (valid_out !== 1'b1) begin
            $display("[TB][FAIL] Timeout waiting for valid_out.");
            $finish;
        end

        $display("[TB] valid_out received after %0d cycles.", cycle_count);
        $display("[TB] class_scores:");

        for (i = 0; i < 10; i = i + 1) begin
            $display("  class_scores[%0d] = 0x%04h signed=%0d expected_bias=0x%04h signed=%0d",
                     i,
                     class_scores[i*DATA_WIDTH +: DATA_WIDTH],
                     $signed(class_scores[i*DATA_WIDTH +: DATA_WIDTH]),
                     fc_bias_mem[i],
                     $signed(fc_bias_mem[i]));

            // Since image, conv weights, conv biases, and FC weights are zero,
            // expected FC output is only the FC bias loaded from SRAM.
            if (class_scores[i*DATA_WIDTH +: DATA_WIDTH] !== fc_bias_mem[i]) begin
                $display("  [TB][MISMATCH] class %0d: got 0x%04h expected 0x%04h",
                         i,
                         class_scores[i*DATA_WIDTH +: DATA_WIDTH],
                         fc_bias_mem[i]);
                error_count = error_count + 1;
            end
        end

        if (error_count == 0) begin
            $display("[TB][PASS] FC bias SRAM proof-of-concept passed.");
        end else begin
            $display("[TB][FAIL] Found %0d mismatches.", error_count);
        end

        $display("=== CNN TOP TB END ===");
        $finish;
    end

endmodule
