`timescale 1ns/1ps

module cnn_convolution_single_golden_tb;

    localparam DATA_WIDTH = 16;
    localparam OUT_WIDTH  = 16;
    localparam IMG_SIZE   = 4;
    localparam TOTAL_PIXELS = IMG_SIZE * IMG_SIZE;

    reg clk;
    reg rst_n;
    reg valid_in;

    reg signed [(TOTAL_PIXELS*DATA_WIDTH)-1:0] feature_map_in;

    reg signed [DATA_WIDTH-1:0] kernel_0;
    reg signed [DATA_WIDTH-1:0] kernel_1;
    reg signed [DATA_WIDTH-1:0] kernel_2;
    reg signed [DATA_WIDTH-1:0] kernel_3;
    reg signed [DATA_WIDTH-1:0] kernel_4;
    reg signed [DATA_WIDTH-1:0] kernel_5;
    reg signed [DATA_WIDTH-1:0] kernel_6;
    reg signed [DATA_WIDTH-1:0] kernel_7;
    reg signed [DATA_WIDTH-1:0] kernel_8;

    reg signed [15:0] bias;

    wire valid_out;
    wire signed [(TOTAL_PIXELS*OUT_WIDTH)-1:0] feature_map_out;

    reg signed [DATA_WIDTH-1:0] input_arr [0:TOTAL_PIXELS-1];
    reg signed [OUT_WIDTH-1:0]  expected_arr [0:TOTAL_PIXELS-1];

    integer i;
    integer error_count;
    integer cycle_count;

    cnn_convolution_index_based #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .IMG_SIZE(IMG_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .feature_map_in(feature_map_in),

        .kernel_0(kernel_0),
        .kernel_1(kernel_1),
        .kernel_2(kernel_2),
        .kernel_3(kernel_3),
        .kernel_4(kernel_4),
        .kernel_5(kernel_5),
        .kernel_6(kernel_6),
        .kernel_7(kernel_7),
        .kernel_8(kernel_8),
        .bias(bias),

        .valid_out(valid_out),
        .feature_map_out(feature_map_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task pack_input;
        begin
            for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                feature_map_in[(i*DATA_WIDTH) +: DATA_WIDTH] = input_arr[i];
            end
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
        input [8*80-1:0] test_name;
        reg signed [OUT_WIDTH-1:0] got;
        begin
            error_count = 0;
            $display("");
            $display("===== CHECK: %0s =====", test_name);

            for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                got = feature_map_out[(i*OUT_WIDTH) +: OUT_WIDTH];

                $display("pixel[%0d] got=%0d expected=%0d hex_got=0x%04h hex_exp=0x%04h",
                         i, got, expected_arr[i], got[15:0], expected_arr[i][15:0]);

                if (got !== expected_arr[i]) begin
                    $display("  [MISMATCH] pixel[%0d]", i);
                    error_count = error_count + 1;
                end
            end

            if (error_count == 0) begin
                $display("[TB][PASS] %0s", test_name);
            end else begin
                $display("[TB][FAIL] %0s found %0d mismatches.", test_name, error_count);
                $finish;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/cnn_convolution_single_golden_tb.vcd");
        $dumpvars(0, cnn_convolution_single_golden_tb);

        $display("=== CNN CONVOLUTION SINGLE-CHANNEL GOLDEN TB START ===");

        rst_n = 1'b0;
        valid_in = 1'b0;
        feature_map_in = {TOTAL_PIXELS*DATA_WIDTH{1'b0}};

        kernel_0 = 0;
        kernel_1 = 0;
        kernel_2 = 0;
        kernel_3 = 0;
        kernel_4 = 0;
        kernel_5 = 0;
        kernel_6 = 0;
        kernel_7 = 0;
        kernel_8 = 0;
        bias = 0;

        // Input 4x4 row-major:
        //  1  2  3  4
        //  5  6  7  8
        //  9 10 11 12
        // 13 14 15 16
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            input_arr[i] = i + 1;
        end
        pack_input();

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // ============================================================
        // TEST 1: identity kernel
        // Kernel:
        // 0 0 0
        // 0 1 0
        // 0 0 0
        // Expected output = input
        // ============================================================
        $display("");
        $display("[TB] TEST 1: identity kernel");

        kernel_0 = 0; kernel_1 = 0; kernel_2 = 0;
        kernel_3 = 0; kernel_4 = 1; kernel_5 = 0;
        kernel_6 = 0; kernel_7 = 0; kernel_8 = 0;
        bias = 0;

        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            expected_arr[i] = input_arr[i];
        end

        pulse_valid_in();
        wait_valid_out();
        check_output("identity kernel");

        repeat (5) @(negedge clk);

        // ============================================================
        // TEST 2: all-ones kernel with zero padding
        // Kernel:
        // 1 1 1
        // 1 1 1
        // 1 1 1
        //
        // Expected output:
        // 14 24 30 22
        // 33 54 63 45
        // 57 90 99 69
        // 46 72 78 54
        // ============================================================
        $display("");
        $display("[TB] TEST 2: all-ones kernel with zero padding");

        kernel_0 = 1; kernel_1 = 1; kernel_2 = 1;
        kernel_3 = 1; kernel_4 = 1; kernel_5 = 1;
        kernel_6 = 1; kernel_7 = 1; kernel_8 = 1;
        bias = 0;

        expected_arr[0]  = 14;
        expected_arr[1]  = 24;
        expected_arr[2]  = 30;
        expected_arr[3]  = 22;

        expected_arr[4]  = 33;
        expected_arr[5]  = 54;
        expected_arr[6]  = 63;
        expected_arr[7]  = 45;

        expected_arr[8]  = 57;
        expected_arr[9]  = 90;
        expected_arr[10] = 99;
        expected_arr[11] = 69;

        expected_arr[12] = 46;
        expected_arr[13] = 72;
        expected_arr[14] = 78;
        expected_arr[15] = 54;

        pulse_valid_in();
        wait_valid_out();
        check_output("all-ones kernel zero-padding");

        $display("");
        $display("=== CNN CONVOLUTION SINGLE-CHANNEL GOLDEN TB END ===");
        $finish;
    end

endmodule
