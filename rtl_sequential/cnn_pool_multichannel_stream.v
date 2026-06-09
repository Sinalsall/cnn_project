module cnn_pool_multichannel_stream #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH  = 28,
    parameter CHANNELS   = 10
)(
    input wire clk,
    input wire rst_n,
    
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    // Kebutuhan buffer baris: (Lebar/2) * CHANNELS
    // Menyimpan max dari 2 baris bagian atas
    localparam BUF_DEPTH = (IMG_WIDTH/2) * CHANNELS;
    reg signed [DATA_WIDTH-1:0] line_buf [0:BUF_DEPTH-1];
    
    // Counter Spasial & Kanal
    reg [9:0] col_count;
    reg [9:0] row_count;
    reg [4:0] ch_count;
    
    // Register penahan nilai max sementara antar kolom genap/ganjil per channel
    reg signed [DATA_WIDTH-1:0] temp_max [0:CHANNELS-1];
    
    integer i;
    wire [15:0] buf_idx = (col_count/2) * CHANNELS + ch_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            data_out <= 0;
            col_count <= 0;
            row_count <= 0;
            ch_count <= 0;
            for(i=0; i<BUF_DEPTH; i=i+1) line_buf[i] <= 0;
            for(i=0; i<CHANNELS; i=i+1) temp_max[i] <= 0;
        end else begin
            valid_out <= 0;
            
            if (valid_in) begin
                // Update indeks Spasial TDM
                if (ch_count == CHANNELS - 1) begin
                    ch_count <= 0;
                    if (col_count == IMG_WIDTH - 1) begin
                        col_count <= 0;
                        row_count <= row_count + 1;
                    end else begin
                        col_count <= col_count + 1;
                    end
                end else begin
                    ch_count <= ch_count + 1;
                end
                
                // Logika MaxPool 2x2 berbasis TDM
                if (row_count[0] == 0) begin
                    // ---- BARIS ATAS (Genap) ---- 
                    if (col_count[0] == 0) begin
                        // Kolom Kiri: Tahan ke temp_max
                        temp_max[ch_count] <= data_in;
                    end else begin
                        // Kolom Kanan: Cari max atas(kiri vs kanan), simpan ke line_buf
                        if (data_in > temp_max[ch_count]) begin
                            line_buf[buf_idx] <= data_in;
                        end else begin
                            line_buf[buf_idx] <= temp_max[ch_count];
                        end
                    end
                end else begin
                    // ---- BARIS BAWAH (Ganjil) ----
                    if (col_count[0] == 0) begin
                        // Kolom Kiri: Cari max dengan atasnya(yg ada di line_buf dari iterasi baris genap dideret ini)
                        if (data_in > line_buf[buf_idx]) begin
                            temp_max[ch_count] <= data_in;
                        end else begin
                            temp_max[ch_count] <= line_buf[buf_idx]; 
                        end
                    end else begin
                        // Kolom Kanan: Emit data sesungguhnya karena blok 2x2 sudah komplit
                        valid_out <= 1;
                        if (data_in > temp_max[ch_count]) begin
                            data_out <= data_in;
                        end else begin
                            data_out <= temp_max[ch_count];
                        end
                    end
                end
            end
        end
    end

endmodule
