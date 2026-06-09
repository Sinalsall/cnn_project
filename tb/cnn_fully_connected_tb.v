// ==========================================
// Testbench: Fully Connected Layer (Matches Parameterized Design)
// ==========================================

`timescale 1ns/1ps

module cnn_fully_connected_tb;

    // Definisikan parameter pengetesan sesuai dataset APIC-EL4012
    localparam DATA_WIDTH = 16;
    localparam INPUT_DIM  = 490; 
    localparam OUTPUT_DIM = 10;

    // Sinyal stimulus hardware otomatis mengikuti parameter
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [DATA_WIDTH*INPUT_DIM-1:0] input_vector;
    reg [DATA_WIDTH*INPUT_DIM*OUTPUT_DIM-1:0] weights;
    reg [DATA_WIDTH*OUTPUT_DIM-1:0] bias;
    
    wire valid_out;
    wire [DATA_WIDTH*OUTPUT_DIM-1:0] output_vector;

    // Memori larik (Array Buffer) internal untuk menampung file teks eksternal
    reg signed [15:0] input_arr  [0:INPUT_DIM-1];     // 490 elemen input
    reg signed [15:0] weight_arr [0:(INPUT_DIM*OUTPUT_DIM)-1]; // 4900 elemen weights
    reg signed [15:0] bias_arr   [0:OUTPUT_DIM-1];    // 10 elemen bias
    reg signed [15:0] output_arr [0:OUTPUT_DIM-1];    // 10 elemen output hasil bongkar
    
    integer i, j, flat_idx;

    // Instansiasi DUT (Device Under Test) menghubungkan ke modul Anda
    cnn_fully_connected #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_DIM(INPUT_DIM),
        .OUTPUT_DIM(OUTPUT_DIM)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .input_vector(input_vector),
        .weights(weights),
        .bias(bias),
        .valid_out(valid_out),
        .output_vector(output_vector)
    );

    // Pembangkitan Sinyal Clock (Periode 10ns)
    always #5 clk = ~clk;

    // TASK: Mengemas susunan Array menjadi barisan Vektor Bit Tunggal (Packing)
    task pack_data;
        begin
            // 1. Mengemas Input (490 elemen)
            for (i = 0; i < INPUT_DIM; i = i + 1) begin
                input_vector[16*i +: 16] = input_arr[i];
            end
            
            // 2. Mengemas Weights (4900 elemen secara sekuensial)
            for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
                for (j = 0; j < INPUT_DIM; j = j + 1) begin
                    flat_idx = i * INPUT_DIM + j;
                    weights[16*flat_idx +: 16] = weight_arr[flat_idx];
                end
            end
            
            // 3. Mengemas Bias (10 elemen)
            for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
                bias[16*i +: 16] = bias_arr[i];
            end
        end
    endtask

    // TASK: Membongkar output_vector hasil hardware menjadi array (Unpacking)
    task unpack_output;
        begin
            for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
                output_arr[i] = output_vector[16*i +: 16];
            end
        end
    endtask

    // Alur Pengujian Utama
    initial begin
        // Inisialisasi awal nilai sirkuit
        clk = 0;
        rst_n = 0;
        valid_in = 0;
        input_vector = 0;
        weights = 0;
        bias = 0;
        
        // Membuat berkas VCD untuk visualisasi GTKWave
        $dumpfile("cnn_fully_connected.vcd");
        $dumpvars(0, cnn_fully_connected_tb);
        
        // Fase Reset Sistem
        #10;
        rst_n = 1;
        #10;
        
        $display("===== TEST: Menggunakan Data Bobot Eksperimen APIC-EL4012 =====");
        
        // Membaca file teks heksadesimal hasil konversi Python
        $readmemh("fc_weights_hex.txt", weight_arr);
        $readmemh("fc_bias_hex.txt", bias_arr);
        
        // Mengisi seluruh 490 data input dummy dengan nilai 1.0 (Format Fixed-Point Q8.8 = 16'h0100)
        for (i = 0; i < INPUT_DIM; i = i + 1) begin
            input_arr[i] = 16'h0100; 
        end
        
        // Gabungkan array memori menjadi satu baris flat register vector
        pack_data();
        
        // Berikan pulsa trigger valid_in ke modul hardware selama 1 siklus clock
        @(negedge clk);
        valid_in = 1;
        $display("Stimulus Data Sukses diaplikasikan pada waktu simulasi: %0t ns", $time);
        @(negedge clk);
        valid_in = 0;
        
        // Menunggu hardware selesai memproses perkalian matriks hingga valid_out menjadi HIGH (1)
        while (!valid_out) @(posedge clk);
        
        // Beri jeda 1 clock setelah valid_out aktif untuk memastikan data stabil di register output_hold
        @(posedge clk);
        unpack_output();
        
        // Tampilkan Hasil Eksekusi ke Console Monitor
        $display("\nSelesai Perhitungan pada Waktu: %0t ns | Status Sinyal valid_out=%b", $time, valid_out);
        $display("Hasil Komputasi Fully Connected (Nilai Probabilitas 10 Kelas):");
        for (i = 0; i < 10; i = i + 1) begin
            $display(" -> Kelas [%0d] = Bentuk Hex: %h | Nilai Desimal (Signed): %0d", i, output_arr[i], output_arr[i]);
        end
        
        #30;
        $finish;
    end

endmodule
