module cnn_top_serial #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    // Antarmuka Stream Input
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    output wire ready_out,
    input wire last_in, // end of frame
    
    // Antarmuka Akses Memori untuk Bobot
    output wire [15:0] weight_addr,
    input wire signed [DATA_WIDTH-1:0] weight_in,
    input wire signed [DATA_WIDTH-1:0] bias_in,

    // Antarmuka Output (Hasil Prediksi Kelas 0-9)
    output wire valid_out,
    output wire [3:0] class_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    // ============================================
    // PIPELINE INTERCONNECT WIRES
    // ============================================
    
    // Layer 1: Line Buffer Input -> Conv1
    wire lb1_valid_out;
    wire signed [DATA_WIDTH-1:0] w00_1, w01_1, w02_1, w10_1, w11_1, w12_1, w20_1, w21_1, w22_1;
    
    line_buffer #(.DATA_WIDTH(16), .IMG_WIDTH(28)) line_buf1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(pixel_in),
        .valid_out(lb1_valid_out),
        .w00(w00_1), .w01(w01_1), .w02(w02_1),
        .w10(w10_1), .w11(w11_1), .w12(w12_1),
        .w20(w20_1), .w21(w21_1), .w22(w22_1)
    );
    
    wire conv1_valid_out, conv1_ready_in;
    wire signed [DATA_WIDTH-1:0] conv1_data_out;
    
    cnn_convolution_serial #(.DATA_WIDTH(16)) conv1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(lb1_valid_out),
        .ready_out(ready_out), // Backpressure cascade ke sistem luar
        .w00(w00_1), .w01(w01_1), .w02(w02_1),
        .w10(w10_1), .w11(w11_1), .w12(w12_1),
        .w20(w20_1), .w21(w21_1), .w22(w22_1),
        .weight_in(weight_in), .bias_in(bias_in),
        // .weight_idx(), // Diabaikan untuk simplifikasi sambungan top saat ini
        .valid_out(conv1_valid_out),
        .data_out(conv1_data_out)
    );
    
    // Layer 2: ReLU
    wire relu1_valid_out, relu1_ready_in;
    wire signed [DATA_WIDTH-1:0] relu1_data_out;
    
    cnn_relu_stream #(.DATA_WIDTH(16)) relu1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(conv1_valid_out),
        .ready_in(relu1_ready_in), // Dipandu siap atau tidaknya maxpool
        .data_in(conv1_data_out),
        .ready_out(conv1_ready_in),
        .valid_out(relu1_valid_out),
        .data_out(relu1_data_out)
    );
    
    // Layer 3: MaxPool
    wire pool1_valid_out;
    wire signed [DATA_WIDTH-1:0] pool1_data_out;
    
    cnn_maxpool_stream #(.DATA_WIDTH(16), .IMG_WIDTH(28)) pool1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(relu1_valid_out),
        .data_in(relu1_data_out),
        .valid_out(pool1_valid_out),
        .data_out(pool1_data_out)
    );
    assign relu1_ready_in = 1; // Memastikan aliran ke MaxPool tak tetahan

    // ============================================
    // Layer Output: Fully Connected
    // ============================================
    // (Dalam praktiknya, design dipanjangkan untuk Block 2 Conv/ReLU/Pool sebelum FC)
    
    cnn_fully_connected_serial #(
        .IN_FEATURES(490),
        .OUT_CLASSES(10)
    ) fc (
        .clk(clk), .rst_n(rst_n),
        .valid_in(pool1_valid_out),
        .last_in(last_in),
        .data_in(pool1_data_out),
        .weight_addr(weight_addr),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .valid_out(valid_out),
        .score_out(score_out),
        .class_idx(class_idx)
    );

endmodule
