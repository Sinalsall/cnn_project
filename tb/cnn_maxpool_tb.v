`timescale 1ns/1ps
module cnn_maxpool_tb;

    parameter DATA_WIDTH = 16;
    parameter INPUT_SIZE = 28;
    parameter POOL_SIZE  = 2;
    localparam OUTPUT_SIZE = INPUT_SIZE/POOL_SIZE;

    reg clk;
    reg rst_n;
    reg start;
    reg signed [DATA_WIDTH*INPUT_SIZE*INPUT_SIZE-1:0] frame_in;
    wire busy;
    wire done;
    wire signed [DATA_WIDTH*OUTPUT_SIZE*OUTPUT_SIZE-1:0] frame_out;

    integer i, j;

    // Instansiasi modul
    cnn_maxpool #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_SIZE(INPUT_SIZE),
        .POOL_SIZE(POOL_SIZE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .frame_in(frame_in),
        .busy(busy),
        .done(done),
        .frame_out(frame_out)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns period

    // Frame 4x4 test
    reg signed [DATA_WIDTH-1:0] input_pixels [0:INPUT_SIZE*INPUT_SIZE-1];
    reg signed [DATA_WIDTH-1:0] output_pixels [0:OUTPUT_SIZE*OUTPUT_SIZE-1];

    initial begin
        // VCD dump
        $dumpfile("tb/cnn_maxpool_tb.vcd");
        $dumpvars(0, cnn_maxpool_tb);

        // Reset
        rst_n = 0;
        start = 0;
        frame_in = 0;
        #20 rst_n = 1;

        // Isi frame 4x4
        // Isi frame 28x28 dengan pola sederhana.
	// Nilai pixel = index pixel, agar mudah dicek.
	for (i = 0; i < INPUT_SIZE*INPUT_SIZE; i = i + 1) begin
	    input_pixels[i] = i;
	end        

        // Flatten frame into frame_in bus
        frame_in = 0;
        for (i=0; i<INPUT_SIZE*INPUT_SIZE; i=i+1) begin
            frame_in[i*DATA_WIDTH +: DATA_WIDTH] = input_pixels[i];
        end

        // Start maxpool
        start = 1;
        #10 start = 0;

        // Tunggu done
        wait(done == 1);

        // Ambil hasil dari frame_out
        for (i=0; i<OUTPUT_SIZE*OUTPUT_SIZE; i=i+1) begin
            output_pixels[i] = frame_out[i*DATA_WIDTH +: DATA_WIDTH];
        end

        // Tampilkan output

	$display("Input frame %0dx%0d:", INPUT_SIZE, INPUT_SIZE);
	for (i=0; i<INPUT_SIZE; i=i+1) begin
	    for (j=0; j<INPUT_SIZE; j=j+1) begin
	        $write("%0d ", input_pixels[i*INPUT_SIZE + j]);
	    end
	    $write("\n");
	end

        $display("\nMaxPool 2x2 output 2x2:");
        for (i=0; i<OUTPUT_SIZE; i=i+1) begin
            for (j=0; j<OUTPUT_SIZE; j=j+1) begin
                $write("%0d ", output_pixels[i*OUTPUT_SIZE + j]);
            end
            $write("\n");
        end

        $finish;
    end
endmodule
