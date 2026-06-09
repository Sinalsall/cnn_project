`timescale 1ns/1ps
module cnn_convolution_tb;

  reg clk;
  reg rst_n;
  reg valid_in;
  reg signed [16-1:0] pixel_in;

  reg signed [16-1:0] kernel [0:8];
  reg signed [15:0] bias;

  // Kernel bisa di-hardcode di dalam modul jika RTL Anda tidak punya port array
  wire valid_out;
  wire signed [16-1:0] pixel_out;

  // Instansiasi modul convolution sesuai RTL Anda
  cnn_convolution #(
      .DATA_WIDTH(16),
      .IMG_SIZE(4)   // gunakan 4x4 untuk test kecil
  ) uut (
      .clk(clk),
      .rst_n(rst_n),
      .valid_in(valid_in),
      .pixel_in(pixel_in),
      .kernel(kernel),
      .bias(bias),
      .valid_out(valid_out),
      .pixel_out(pixel_out)
  );

  // Clock
  initial clk = 0;
  always #5 clk = ~clk; // 10ns period

  integer i;
  reg [16-1:0] test_data [0:15]; // 4x4 input

  // Debug output ke terminal
  always @(posedge clk) begin
      $display("t=%0t rst_n=%b valid_in=%b pixel_in=%0d valid_out=%b pixel_out=%0d",
               $time, rst_n, valid_in, pixel_in, valid_out, pixel_out);
  end

  initial begin
    // Dump VCD
    $dumpfile("tb/cnn_convolution_tb.vcd");
    $dumpvars(0, cnn_convolution_tb);

    // Reset
    rst_n = 0;
    valid_in = 0;
    pixel_in = 0;
    #20 rst_n = 1;

    // Kernel identity untuk debug awal
    kernel[0] = 16'sd0; kernel[1] = 16'sd0; kernel[2] = 16'sd0;
    kernel[3] = 16'sd0; kernel[4] = 16'sd1; kernel[5] = 16'sd0;
    kernel[6] = 16'sd0; kernel[7] = 16'sd0; kernel[8] = 16'sd0;

    bias = 16'sd0;

    // Test input 4x4
    test_data[0]=1; test_data[1]=2; test_data[2]=3; test_data[3]=4;
    test_data[4]=5; test_data[5]=6; test_data[6]=7; test_data[7]=8;
    test_data[8]=9; test_data[9]=10; test_data[10]=11; test_data[11]=12;
    test_data[12]=13; test_data[13]=14; test_data[14]=15; test_data[15]=16;

    // Kirim pixel serial
    for (i=0; i<16; i=i+1) begin
      pixel_in = test_data[i];
      valid_in = 1;
      #10; // 1 clock per pixel
    end
    valid_in = 0;

    // Tunggu output stabil
    #100;
    $finish;
  end

endmodule
