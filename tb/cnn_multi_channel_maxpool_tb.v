`timescale 1ns/1ps

module cnn_multi_channel_maxpool_tb;

    localparam DATA_WIDTH  = 16;
    localparam INPUT_SIZE  = 4;
    localparam OUTPUT_SIZE = INPUT_SIZE / 2;
    localparam CH          = 2;

    localparam IN_PIXELS   = INPUT_SIZE * INPUT_SIZE;
    localparam OUT_PIXELS  = OUTPUT_SIZE * OUTPUT_SIZE;

    localparam IN_BUS_W    = CH * IN_PIXELS  * DATA_WIDTH;
    localparam OUT_BUS_W   = CH * OUT_PIXELS * DATA_WIDTH;

    reg clk;
    reg rst_n;
    reg valid_in;

    reg  signed [IN_BUS_W-1:0]  feature_map_in;
    wire valid_out;
    wire signed [OUT_BUS_W-1:0] feature_map_out;

    integer i;
    integer ch;
    integer error_count;
    integer cycle_count;

    reg signed [DATA_WIDTH-1:0] got;
    reg signed [DATA_WIDTH-1:0] expected;

    cnn_multi_channel_maxpool #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_SIZE(INPUT_SIZE),
        .CH(CH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .feature_map_in(feature_map_in),
        .valid_out(valid_out),
        .feature_map_out(feature_map_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task set_input_pixel;
        input integer channel;
        input integer pix;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = (channel*IN_PIXELS + pix) * DATA_WIDTH;
            feature_map_in[base +: DATA_WIDTH] = value;
        end
    endtask

    task get_output_pixel;
        input integer channel;
        input integer pix;
        output signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = (channel*OUT_PIXELS + pix) * DATA_WIDTH;
            value = feature_map_out[base +: DATA_WIDTH];
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

    initial begin
        $dumpfile("tb/cnn_multi_channel_maxpool_tb.vcd");
        $dumpvars(0, cnn_multi_channel_maxpool_tb);

        $display("=== CNN MULTI-CHANNEL MAXPOOL TB START ===");

        rst_n = 1'b0;
        valid_in = 1'b0;
        feature_map_in = {IN_BUS_W{1'b0}};
        error_count = 0;

        // Channel 0 input 4x4:
        //  1  2  3  4
        //  5  6  7  8
        //  9 10 11 12
        // 13 14 15 16
        //
        // MaxPool 2x2 expected:
        //  6  8
        // 14 16
        for (i = 0; i < IN_PIXELS; i = i + 1) begin
            set_input_pixel(0, i, i + 1);
        end

        // Channel 1 input 4x4:
        // -1  -2  -3  -4
        // -5  -6  -7  -8
        // 10  20 -30 -40
        // 50  60 -70 -80
        //
        // MaxPool 2x2 expected:
        // -1  -3
        // 60 -30
        set_input_pixel(1, 0,  -16'sd1);
        set_input_pixel(1, 1,  -16'sd2);
        set_input_pixel(1, 2,  -16'sd3);
        set_input_pixel(1, 3,  -16'sd4);

        set_input_pixel(1, 4,  -16'sd5);
        set_input_pixel(1, 5,  -16'sd6);
        set_input_pixel(1, 6,  -16'sd7);
        set_input_pixel(1, 7,  -16'sd8);

        set_input_pixel(1, 8,   16'sd10);
        set_input_pixel(1, 9,   16'sd20);
        set_input_pixel(1, 10, -16'sd30);
        set_input_pixel(1, 11, -16'sd40);

        set_input_pixel(1, 12,  16'sd50);
        set_input_pixel(1, 13,  16'sd60);
        set_input_pixel(1, 14, -16'sd70);
        set_input_pixel(1, 15, -16'sd80);

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        $display("[TB] Starting MaxPool test...");
        pulse_valid_in();

        cycle_count = 0;
        while ((valid_out !== 1'b1) && (cycle_count < 100)) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        if (valid_out !== 1'b1) begin
            $display("[TB][FAIL] Timeout waiting for valid_out.");
            $finish;
        end

        $display("[TB] valid_out received after %0d cycles.", cycle_count);

        // Check channel 0.
        $display("");
        $display("===== CHECK CHANNEL 0 =====");

        get_output_pixel(0, 0, got); expected = 16'sd6;
        $display("ch0 out[0] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(0, 1, got); expected = 16'sd8;
        $display("ch0 out[1] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(0, 2, got); expected = 16'sd14;
        $display("ch0 out[2] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(0, 3, got); expected = 16'sd16;
        $display("ch0 out[3] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        // Check channel 1.
        $display("");
        $display("===== CHECK CHANNEL 1 =====");

        get_output_pixel(1, 0, got); expected = -16'sd1;
        $display("ch1 out[0] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(1, 1, got); expected = -16'sd3;
        $display("ch1 out[1] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(1, 2, got); expected = 16'sd60;
        $display("ch1 out[2] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        get_output_pixel(1, 3, got); expected = -16'sd30;
        $display("ch1 out[3] got=%0d expected=%0d", got, expected);
        if (got !== expected) error_count = error_count + 1;

        if (error_count == 0) begin
            $display("[TB][PASS] multi-channel MaxPool test passed.");
        end else begin
            $display("[TB][FAIL] multi-channel MaxPool test failed with %0d mismatches.", error_count);
            $finish;
        end

        $display("=== CNN MULTI-CHANNEL MAXPOOL TB END ===");
        $finish;
    end

endmodule
