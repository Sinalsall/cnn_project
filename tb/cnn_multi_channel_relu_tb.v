`timescale 1ns/1ps

module cnn_multi_channel_relu_tb;

    localparam DATA_WIDTH = 16;
    localparam IMG_SIZE   = 4;
    localparam CH         = 2;
    localparam PIXELS     = IMG_SIZE * IMG_SIZE;
    localparam BUS_W      = CH * PIXELS * DATA_WIDTH;

    reg clk;
    reg rst_n;
    reg valid_in;

    reg  signed [BUS_W-1:0] feature_map_in;
    wire valid_out;
    wire signed [BUS_W-1:0] feature_map_out;

    integer i;
    integer ch;
    integer error_count;
    integer cycle_count;

    reg signed [DATA_WIDTH-1:0] val;
    reg signed [DATA_WIDTH-1:0] got;
    reg signed [DATA_WIDTH-1:0] expected;

    cnn_multi_channel_relu #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_SIZE(IMG_SIZE),
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

    task set_pixel;
        input integer channel;
        input integer pix;
        input signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = (channel*PIXELS + pix) * DATA_WIDTH;
            feature_map_in[base +: DATA_WIDTH] = value;
        end
    endtask

    task get_output_pixel;
        input integer channel;
        input integer pix;
        output signed [DATA_WIDTH-1:0] value;
        integer base;
        begin
            base = (channel*PIXELS + pix) * DATA_WIDTH;
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
        $dumpfile("tb/cnn_multi_channel_relu_tb.vcd");
        $dumpvars(0, cnn_multi_channel_relu_tb);

        $display("=== CNN MULTI-CHANNEL RELU TB START ===");

        rst_n = 1'b0;
        valid_in = 1'b0;
        feature_map_in = {BUS_W{1'b0}};
        error_count = 0;

        // Channel 0: -8 sampai +7
        // Channel 1: positif dan negatif bergantian
        for (i = 0; i < PIXELS; i = i + 1) begin
            set_pixel(0, i, $signed(i - 8));

            if (i[0] == 1'b0)
                set_pixel(1, i, $signed(i + 1));
            else
                set_pixel(1, i, -$signed(i + 1));
        end

        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        $display("[TB] Starting ReLU test...");
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

        for (ch = 0; ch < CH; ch = ch + 1) begin
            $display("");
            $display("===== CHECK CHANNEL %0d =====", ch);

            for (i = 0; i < PIXELS; i = i + 1) begin
                val = feature_map_in[(ch*PIXELS + i)*DATA_WIDTH +: DATA_WIDTH];
                get_output_pixel(ch, i, got);

                if (val < 0)
                    expected = 0;
                else
                    expected = val;

                $display("ch=%0d pixel=%0d in=%0d got=%0d expected=%0d",
                         ch, i, val, got, expected);

                if (got !== expected) begin
                    $display("  [MISMATCH] ch=%0d pixel=%0d", ch, i);
                    error_count = error_count + 1;
                end
            end
        end

        if (error_count == 0) begin
            $display("[TB][PASS] multi-channel ReLU test passed.");
        end else begin
            $display("[TB][FAIL] multi-channel ReLU test failed with %0d mismatches.", error_count);
            $finish;
        end

        $display("=== CNN MULTI-CHANNEL RELU TB END ===");
        $finish;
    end

endmodule
