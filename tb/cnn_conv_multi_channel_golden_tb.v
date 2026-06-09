`timescale 1ns/1ps

module cnn_conv_multi_channel_golden_tb;

    localparam DATA_WIDTH = 16;
    localparam OUT_WIDTH  = 16;
    localparam ACC_WIDTH  = 40;
    localparam IMG_SIZE   = 4;
    localparam IN_CH      = 2;
    localparam OUT_CH     = 2;
    localparam PIXELS     = IMG_SIZE * IMG_SIZE;

    localparam FM_IN_W    = IN_CH  * PIXELS * DATA_WIDTH;
    localparam WEIGHTS_W  = OUT_CH * IN_CH * 9 * DATA_WIDTH;
    localparam BIAS_W     = OUT_CH * DATA_WIDTH;
    localparam FM_OUT_W   = OUT_CH * PIXELS * OUT_WIDTH;

    reg clk;
    reg rst_n;
    reg valid_in;

    reg signed [FM_IN_W-1:0]   feature_map_in;
    reg signed [WEIGHTS_W-1:0] weights;
    reg signed [BIAS_W-1:0]    bias;

    wire valid_out;
    wire signed [FM_OUT_W-1:0] feature_map_out;

    reg signed [DATA_WIDTH-1:0] in_ch0 [0:PIXELS-1];
    reg signed [DATA_WIDTH-1:0] in_ch1 [0:PIXELS-1];

    reg signed [OUT_WIDTH-1:0] expected_oc0 [0:PIXELS-1];
    reg signed [OUT_WIDTH-1:0] expected_oc1 [0:PIXELS-1];

    integer i;
    integer error_count;
    integer cycle_count;

    cnn_conv_multi_channel_parallel #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .IMG_SIZE(IMG_SIZE),
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .feature_map_in(feature_map_in),
        .weights(weights),
        .bias(bias),
        .valid_out(valid_out),
        .feature_map_out(feature_map_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task set_input_pixel;
        input integer ch;
        input integer pix;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = (ch*PIXELS + pix) * DATA_WIDTH;
            feature_map_in[base +: DATA_WIDTH] = value;
        end
    endtask

    task set_weight;
        input integer oc;
        input integer ic;
        input integer k;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            // Flattening order mengikuti wrapper:
            // weights[(((out_ch*IN_CH + in_ch)*9 + k)*DATA_WIDTH) +: DATA_WIDTH]
            base = (((oc*IN_CH + ic)*9 + k) * DATA_WIDTH);
            weights[base +: DATA_WIDTH] = value;
        end
    endtask

    task set_bias;
        input integer oc;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = oc * DATA_WIDTH;
            bias[base +: DATA_WIDTH] = value;
        end
    endtask

    task pulse_valid_in;
        begin
            @(negedge clk);
            valid_in = 1'b1;
            @(negedge clk);
            valid_in = 1'b0;
        end
    endtask

    task wait_valid_out;
        begin
            cycle_count = 0;
            while ((valid_out !== 1'b1) && (cycle_count < 1000)) begin
                @(posedge clk);
                cycle_count = cycle_count + 1;
            end

            if (valid_out !== 1'b1) begin
                $display("[TB][FAIL] Timeout waiting for valid_out.");
                $finish;
            end

            $display("[TB] valid_out received after %0d cycles.", cycle_count);
        end
    endtask

    task check_output;
        reg signed [OUT_WIDTH-1:0] got;
        begin
            error_count = 0;

            $display("");
            $display("===== CHECK OUTPUT CHANNEL 0 =====");
            for (i = 0; i < PIXELS; i = i + 1) begin
                got = feature_map_out[(0*PIXELS + i)*OUT_WIDTH +: OUT_WIDTH];

                $display("oc0 pixel[%0d] got=%0d expected=%0d hex_got=0x%04h hex_exp=0x%04h",
                         i, got, expected_oc0[i], got[15:0], expected_oc0[i][15:0]);

                if (got !== expected_oc0[i]) begin
                    $display("  [MISMATCH] oc0 pixel[%0d]", i);
                    error_count = error_count + 1;
                end
            end

            $display("");
            $display("===== CHECK OUTPUT CHANNEL 1 =====");
            for (i = 0; i < PIXELS; i = i + 1) begin
                got = feature_map_out[(1*PIXELS + i)*OUT_WIDTH +: OUT_WIDTH];

                $display("oc1 pixel[%0d] got=%0d expected=%0d hex_got=0x%04h hex_exp=0x%04h",
                         i, got, expected_oc1[i], got[15:0], expected_oc1[i][15:0]);

                if (got !== expected_oc1[i]) begin
                    $display("  [MISMATCH] oc1 pixel[%0d]", i);
                    error_count = error_count + 1;
                end
            end

            if (error_count == 0) begin
                $display("[TB][PASS] multi-channel convolution wrapper passed.");
            end else begin
                $display("[TB][FAIL] Found %0d mismatches.", error_count);
                $finish;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/cnn_conv_multi_channel_golden_tb.vcd");
        $dumpvars(0, cnn_conv_multi_channel_golden_tb);

        $display("=== CNN MULTI-CHANNEL CONV GOLDEN TB START ===");

        rst_n = 1'b0;
        valid_in = 1'b0;

        feature_map_in = {FM_IN_W{1'b0}};
        weights        = {WEIGHTS_W{1'b0}};
        bias           = {BIAS_W{1'b0}};

        // Input:
        // ch0 = 1..16
        // ch1 = 10,20,30,...,160
        for (i = 0; i < PIXELS; i = i + 1) begin
            in_ch0[i] = i + 1;
            in_ch1[i] = (i + 1) * 10;

            set_input_pixel(0, i, in_ch0[i]);
            set_input_pixel(1, i, in_ch1[i]);
        end

        // Default all weights = 0.
        // Identity kernel means k=4 is 1:
        // 0 0 0
        // 0 1 0
        // 0 0 0

        // Output channel 0:
        // oc0 = conv(ch0, identity) + conv(ch1, identity) + 100
        set_weight(0, 0, 4, 16'sd1);
        set_weight(0, 1, 4, 16'sd1);
        set_bias(0, 16'sd100);

        // Output channel 1:
        // oc1 = conv(ch0, identity) + conv(ch1, zero) - 5
        set_weight(1, 0, 4, 16'sd1);
        set_weight(1, 1, 4, 16'sd0);
        set_bias(1, -16'sd5);

        for (i = 0; i < PIXELS; i = i + 1) begin
            expected_oc0[i] = in_ch0[i] + in_ch1[i] + 16'sd100;
            expected_oc1[i] = in_ch0[i] - 16'sd5;
        end

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        $display("[TB] Starting multi-channel convolution test...");
        pulse_valid_in();

        wait_valid_out();
        check_output();

        $display("");
        $display("=== CNN MULTI-CHANNEL CONV GOLDEN TB END ===");
        $finish;
    end

endmodule
