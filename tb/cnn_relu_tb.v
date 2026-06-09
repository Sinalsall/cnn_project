`timescale 1ns/1ps

module cnn_relu_tb;

    parameter DATA_WIDTH = 16;
    parameter IMG_SIZE   = 28;

    localparam TOTAL_PIXELS = IMG_SIZE * IMG_SIZE;

    reg clk;
    reg rst_n;
    reg valid_in;

    reg  signed [(TOTAL_PIXELS*DATA_WIDTH)-1:0] feature_map_in;
    wire signed [(TOTAL_PIXELS*DATA_WIDTH)-1:0] feature_map_out;
    wire valid_out;

    reg signed [DATA_WIDTH-1:0] input_pixels  [0:TOTAL_PIXELS-1];
    reg signed [DATA_WIDTH-1:0] output_pixels [0:TOTAL_PIXELS-1];

    integer i;
    integer r;
    integer c;
    integer error_count;

    cnn_relu #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_SIZE(IMG_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .feature_map_in(feature_map_in),
        .valid_out(valid_out),
        .feature_map_out(feature_map_out)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;   // 10 ns clock period

    always @(posedge clk) begin
        $display("t=%0t rst_n=%b valid_in=%b valid_out=%b",
                 $time, rst_n, valid_in, valid_out);
    end

    initial begin
        $dumpfile("tb/cnn_relu_tb.vcd");
        $dumpvars(0, cnn_relu_tb);

        rst_n = 1'b0;
        valid_in = 1'b0;
        feature_map_in = 0;
        error_count = 0;

        #20;
        rst_n = 1'b1;

        // Generate 28x28 test input with mixed negative, zero, and positive values.
        //
        // Pattern:
        //   i % 5 == 0 -> negative
        //   i % 7 == 0 -> zero
        //   otherwise  -> positive
        //
        // Note: multiples of 5 are intentionally prioritized as negative.
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            if (i % 5 == 0) begin
                input_pixels[i] = -16'sd10;
            end else if (i % 7 == 0) begin
                input_pixels[i] = 16'sd0;
            end else begin
                input_pixels[i] = i[DATA_WIDTH-1:0];
            end
        end

        // Flatten input_pixels array into feature_map_in bus.
        feature_map_in = 0;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            feature_map_in[i*DATA_WIDTH +: DATA_WIDTH] = input_pixels[i];
        end

        // Assert valid_in for one clock cycle.
        @(posedge clk);
        valid_in = 1'b1;

        @(posedge clk);
        valid_in = 1'b0;

        // Wait until output is valid.
        wait(valid_out == 1'b1);

        // Read output bus back into output_pixels array.
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            output_pixels[i] = feature_map_out[i*DATA_WIDTH +: DATA_WIDTH];
        end

        $display("\nInput frame %0dx%0d:", IMG_SIZE, IMG_SIZE);
        for (r = 0; r < IMG_SIZE; r = r + 1) begin
            for (c = 0; c < IMG_SIZE; c = c + 1) begin
                $write("%0d ", input_pixels[r*IMG_SIZE + c]);
            end
            $write("\n");
        end

        $display("\nReLU output %0dx%0d:", IMG_SIZE, IMG_SIZE);
        for (r = 0; r < IMG_SIZE; r = r + 1) begin
            for (c = 0; c < IMG_SIZE; c = c + 1) begin
                $write("%0d ", output_pixels[r*IMG_SIZE + c]);
            end
            $write("\n");
        end

        // Self-check.
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            if (input_pixels[i] < 0) begin
                if (output_pixels[i] !== 0) begin
                    $display("ERROR at index %0d: input=%0d output=%0d expected=0",
                             i, input_pixels[i], output_pixels[i]);
                    error_count = error_count + 1;
                end
            end else begin
                if (output_pixels[i] !== input_pixels[i]) begin
                    $display("ERROR at index %0d: input=%0d output=%0d expected=%0d",
                             i, input_pixels[i], output_pixels[i], input_pixels[i]);
                    error_count = error_count + 1;
                end
            end
        end

        if (error_count == 0) begin
            $display("\nPASS: ReLU 28x28 self-check complete with no errors.");
        end else begin
            $display("\nFAIL: ReLU 28x28 self-check found %0d errors.", error_count);
        end

        #20;
        $finish;
    end

endmodule
