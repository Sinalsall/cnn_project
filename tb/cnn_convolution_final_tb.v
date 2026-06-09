`timescale 1ns/1ps

module cnn_convolution_final_tb;

    parameter DATA_WIDTH = 8;
    parameter OUT_WIDTH  = 32;
    parameter IMG_SIZE   = 4;

    localparam TOTAL_PIXELS = IMG_SIZE * IMG_SIZE;

    reg clk;
    reg rst_n;
    reg start;

    reg  [(TOTAL_PIXELS*DATA_WIDTH)-1:0] feature_map_in;
    wire [(TOTAL_PIXELS*OUT_WIDTH)-1:0]  feature_map_out;

    reg signed [DATA_WIDTH-1:0] kernel_0, kernel_1, kernel_2;
    reg signed [DATA_WIDTH-1:0] kernel_3, kernel_4, kernel_5;
    reg signed [DATA_WIDTH-1:0] kernel_6, kernel_7, kernel_8;
    reg signed [DATA_WIDTH-1:0] bias;

    wire busy;
    wire done;

    integer i;
    integer r;
    integer c;

    reg signed [DATA_WIDTH-1:0] input_pixels [0:TOTAL_PIXELS-1];
    reg signed [OUT_WIDTH-1:0]  output_pixels [0:TOTAL_PIXELS-1];

    // Ganti nama modul ini kalau file Anda memakai nama lain,
    // misalnya cnn_convolution_index_based.
    cnn_convolution_final #(
        .DATA_WIDTH(DATA_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .IMG_SIZE(IMG_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
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

        .busy(busy),
        .done(done),
        .feature_map_out(feature_map_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        $display("t=%0t rst_n=%b start=%b busy=%b done=%b state=%0d row=%0d col=%0d",
                 $time, rst_n, start, busy, done, uut.state, uut.row, uut.col);
    end

    initial begin
        $dumpfile("tb/cnn_convolution_final_tb.vcd");
        $dumpvars(0, cnn_convolution_final_tb);

        rst_n = 0;
        start = 0;
        feature_map_in = 0;

        kernel_0 = 0; kernel_1 = 0; kernel_2 = 0;
        kernel_3 = 0; kernel_4 = 1; kernel_5 = 0;
        kernel_6 = 0; kernel_7 = 0; kernel_8 = 0;
        bias = 0;

        #20;
        rst_n = 1;

        // Input 4x4:
        //
        // 1   2   3   4
        // 5   6   7   8
        // 9   10  11  12
        // 13  14  15  16
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            input_pixels[i] = i + 1;
        end

        // Flatten input_pixels ke feature_map_in.
        // Pixel index i masuk ke bit slice [i*DATA_WIDTH +: DATA_WIDTH].
        feature_map_in = 0;
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            feature_map_in[i*DATA_WIDTH +: DATA_WIDTH] = input_pixels[i];
        end

        // Beri start satu clock.
        @(posedge clk);
        start = 1;

        @(posedge clk);
        start = 0;

        // Tunggu convolution selesai.
        wait(done == 1'b1);

        // Ambil output dari bus feature_map_out.
        for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
            output_pixels[i] = feature_map_out[i*OUT_WIDTH +: OUT_WIDTH];
        end

        $display("\nInput frame %0dx%0d:", IMG_SIZE, IMG_SIZE);
        for (r = 0; r < IMG_SIZE; r = r + 1) begin
            for (c = 0; c < IMG_SIZE; c = c + 1) begin
                $write("%0d ", input_pixels[r*IMG_SIZE + c]);
            end
            $write("\n");
        end

        $display("\nConvolution output %0dx%0d:", IMG_SIZE, IMG_SIZE);
        for (r = 0; r < IMG_SIZE; r = r + 1) begin
            for (c = 0; c < IMG_SIZE; c = c + 1) begin
                $write("%0d ", output_pixels[r*IMG_SIZE + c]);
            end
            $write("\n");
        end

        $display("\nExpected untuk identity kernel:");
        $display("1 2 3 4");
        $display("5 6 7 8");
        $display("9 10 11 12");
        $display("13 14 15 16");

        #20;
        $finish;
    end

endmodule
