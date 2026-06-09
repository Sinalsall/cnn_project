`timescale 1ns/1ps

module cnn_top_full_dummy_tb;

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

    integer i;
    integer ch;
    integer cycle_count;
    integer error_count;

    reg signed [DATA_WIDTH-1:0] got;
    reg signed [DATA_WIDTH-1:0] expected;

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
            fc_bias_sram_addr  = 8'd0;
            fc_bias_sram_wdata = 8'd0;
        end
    endtask

    task set_image_pixel;
        input integer pix;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = pix * DATA_WIDTH;
            image_in[base +: DATA_WIDTH] = value;
        end
    endtask

    task set_conv1_weight;
        input integer oc;
        input integer k;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            // Conv1: OUT_CH=10, IN_CH=1
            // index = ((oc*1 + 0)*9 + k)
            base = ((oc*9 + k) * DATA_WIDTH);
            conv1_weights[base +: DATA_WIDTH] = value;
        end
    endtask

    task set_conv_weight_10x10;
        input integer layer_id;
        input integer oc;
        input integer ic;
        input integer k;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            // Conv2/3/4: OUT_CH=10, IN_CH=10
            // index = ((oc*10 + ic)*9 + k)
            base = (((oc*10 + ic)*9 + k) * DATA_WIDTH);

            if (layer_id == 2)
                conv2_weights[base +: DATA_WIDTH] = value;
            else if (layer_id == 3)
                conv3_weights[base +: DATA_WIDTH] = value;
            else if (layer_id == 4)
                conv4_weights[base +: DATA_WIDTH] = value;
        end
    endtask

    task set_fc_weight;
        input integer out_class;
        input integer in_idx;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            // FC packing: weight[out_class][in_idx]
            base = ((out_class*490 + in_idx) * DATA_WIDTH);
            fc_weights[base +: DATA_WIDTH] = value;
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
        $dumpfile("tb/cnn_top_full_dummy_tb.vcd");
        $dumpvars(0, cnn_top_full_dummy_tb);

        $display("=== CNN TOP FULL DUMMY TB START ===");

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

        // Input image: semua pixel = 1.
        for (i = 0; i < 28*28; i = i + 1) begin
            set_image_pixel(i, 16'sd1);
        end

        // Identity kernel index k=4:
        // 0 0 0
        // 0 1 0
        // 0 0 0

        // Conv1:
        // semua output channel 0..9 menerima image identity.
        for (ch = 0; ch < 10; ch = ch + 1) begin
            set_conv1_weight(ch, 4, 16'sd1);
        end

        // Conv2, Conv3, Conv4:
        // setiap channel dipertahankan sendiri-sendiri:
        // out[ch] = in[ch]
        for (ch = 0; ch < 10; ch = ch + 1) begin
            set_conv_weight_10x10(2, ch, ch, 4, 16'sd1);
            set_conv_weight_10x10(3, ch, ch, 4, 16'sd1);
            set_conv_weight_10x10(4, ch, ch, 4, 16'sd1);
        end

        // Setelah dua kali MaxPool:
        // setiap channel berisi 7x7 = 49 elemen bernilai 1.
        //
        // Flatten channel-major:
        // channel 0 index   0.. 48
        // channel 1 index  49.. 97
        // ...
        // channel 9 index 441..489
        //
        // FC class c menjumlahkan flatten channel c.
        for (ch = 0; ch < 10; ch = ch + 1) begin
            for (i = 0; i < 49; i = i + 1) begin
                set_fc_weight(ch, ch*49 + i, 16'sd1);
            end
        end

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // FC bias SRAM diisi 0 semua.
        $display("[TB] Writing zero FC bias into SRAM...");
        for (i = 0; i < 20; i = i + 1) begin
            sram_write_byte(i[7:0], 8'h00);
        end

        repeat (5) @(negedge clk);

        $display("[TB] Starting full dummy inference...");
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
            got = class_scores[i*DATA_WIDTH +: DATA_WIDTH];
            expected = 16'sd49;

            $display("  class_scores[%0d] = 0x%04h signed=%0d expected=%0d",
                     i, got[15:0], got, expected);

            if (got !== expected) begin
                $display("  [TB][MISMATCH] class %0d: got=%0d expected=%0d",
                         i, got, expected);
                error_count = error_count + 1;
            end
        end

        if (error_count == 0) begin
            $display("[TB][PASS] top-level full dummy 10-channel test passed.");
        end else begin
            $display("[TB][FAIL] Found %0d mismatches.", error_count);
            $finish;
        end

        $display("=== CNN TOP FULL DUMMY TB END ===");
        $finish;
    end

endmodule
