module cnn_convolution_index_based #(
    parameter DATA_WIDTH = 8,
    parameter OUT_WIDTH  = 16,
    parameter IMG_SIZE   = 28
)(
    input clk,
    input rst_n,
    input valid_in,
    
    // Input Paralel
    input [(IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_in,

    // Kernel & Bias
    input signed [DATA_WIDTH-1:0] kernel_0, kernel_1, kernel_2,
    input signed [DATA_WIDTH-1:0] kernel_3, kernel_4, kernel_5,
    input signed [DATA_WIDTH-1:0] kernel_6, kernel_7, kernel_8,
    input signed [15:0] bias,

    output reg valid_out,
    output reg [(IMG_SIZE*IMG_SIZE*OUT_WIDTH)-1:0] feature_map_out
);

    localparam TOTAL_PIXELS = IMG_SIZE * IMG_SIZE;

    // =========================
    // BUFER MEMORI INTERNAL
    // =========================
    // Alokasi memori penuh untuk 784 piksel input dan 784 piksel output
    reg signed [DATA_WIDTH-1:0] input_buffer [0:TOTAL_PIXELS-1];
    reg signed [OUT_WIDTH-1:0]  output_buffer [0:TOTAL_PIXELS-1];

    // State Machine
    localparam IDLE    = 2'd0;
    localparam LOAD    = 2'd1;
    localparam COMPUTE = 2'd2;
    localparam DONE    = 2'd3;
    reg [1:0] state;

    reg [4:0] row, col;
    integer i;

    // =========================
    // JENDELA 9 PIKSEL
    // =========================
    reg signed [DATA_WIDTH-1:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;

    // Logika Pengambilan Data (Multiplexer Raksasa Kombinasional)
    // Blok ini akan membaca 9 nilai dari memori secara serentak berdasarkan koordinat
    always @(*) begin
        // Nilai default 0 untuk mensimulasikan Zero Padding
        p0 = 0; p1 = 0; p2 = 0;
        p3 = 0; p4 = 0; p5 = 0;
        p6 = 0; p7 = 0; p8 = 0;

        if (state == COMPUTE) begin
            // Baris Atas
            if (row > 0 && col > 0)                   p0 = input_buffer[(row-1)*IMG_SIZE + (col-1)];
            if (row > 0)                              p1 = input_buffer[(row-1)*IMG_SIZE + col];
            if (row > 0 && col < IMG_SIZE-1)          p2 = input_buffer[(row-1)*IMG_SIZE + (col+1)];

            // Baris Tengah
            if (col > 0)                              p3 = input_buffer[row*IMG_SIZE + (col-1)];
                                                      p4 = input_buffer[row*IMG_SIZE + col]; // Center
            if (col < IMG_SIZE-1)                     p5 = input_buffer[row*IMG_SIZE + (col+1)];

            // Baris Bawah
            if (row < IMG_SIZE-1 && col > 0)          p6 = input_buffer[(row+1)*IMG_SIZE + (col-1)];
            if (row < IMG_SIZE-1)                     p7 = input_buffer[(row+1)*IMG_SIZE + col];
            if (row < IMG_SIZE-1 && col < IMG_SIZE-1) p8 = input_buffer[(row+1)*IMG_SIZE + (col+1)];
        end
    end

    // =========================
    // MULTIPLIER-ACCUMULATOR (MAC)
    // =========================
    // 9 Multiplier yang berjalan secara paralel dalam 1 clock
    wire signed [31:0] mac_sum_wide =
        (($signed(p0) * $signed(kernel_0)) >>> 8) +
        (($signed(p1) * $signed(kernel_1)) >>> 8) +
        (($signed(p2) * $signed(kernel_2)) >>> 8) +
        (($signed(p3) * $signed(kernel_3)) >>> 8) +
        (($signed(p4) * $signed(kernel_4)) >>> 8) +
        (($signed(p5) * $signed(kernel_5)) >>> 8) +
        (($signed(p6) * $signed(kernel_6)) >>> 8) +
        (($signed(p7) * $signed(kernel_7)) >>> 8) +
        (($signed(p8) * $signed(kernel_8)) >>> 8) +
        $signed(bias);

    wire signed [15:0] mac_sum = mac_sum_wide[15:0];

    
    //KONTROL STATE & KURSOR
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 0;
            feature_map_out <= 0;
            row <= 0;
            col <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Salin data dari port input paralel ke dalam array input_buffer
                    for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                        input_buffer[i] <= feature_map_in[(i*DATA_WIDTH) +: DATA_WIDTH];
                    end
                    row <= 0;
                    col <= 0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // 1. Simpan hasil MAC ke buffer output pada indeks yang tepat
                    output_buffer[row*IMG_SIZE + col] <= mac_sum;

                    // 2. Geser indeks (kursor) ke kanan, atau pindah baris
                    if (col == IMG_SIZE - 1) begin
                        col <= 0;
                        if (row == IMG_SIZE - 1) begin
                            state <= DONE; // Selesai 784 piksel
                        end else begin
                            row <= row + 1;
                        end
                    end else begin
                        col <= col + 1;
                    end
                end

                DONE: begin
                    // Salin data dari array output_buffer ke port output paralel
                    for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                        feature_map_out[(i*OUT_WIDTH) +: OUT_WIDTH] <= output_buffer[i];
                    end
                    valid_out <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
