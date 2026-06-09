module cnn_maxpool_stream #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH  = 28
)(
    input wire clk,
    input wire rst_n,
    
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    // Buffer 1 baris untuk pooling 2x2
    reg signed [DATA_WIDTH-1:0] line_buf [0:IMG_WIDTH-1];
    
    reg [9:0] col_count;
    reg [9:0] row_count;
    
    reg signed [DATA_WIDTH-1:0] row_max;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            data_out <= 0;
            col_count <= 0;
            row_count <= 0;
            row_max <= 0;
            for (i=0; i<IMG_WIDTH; i=i+1) line_buf[i] <= 0;
        end else begin
            valid_out <= 0;
            
            if (valid_in) begin
                // Update tracker
                if (col_count == IMG_WIDTH - 1) begin
                    col_count <= 0;
                    row_count <= row_count + 1;
                end else begin
                    col_count <= col_count + 1;
                end
                
                // Shift register ke buffer line
                for (i=IMG_WIDTH-1; i>0; i=i-1) begin
                    line_buf[i] <= line_buf[i-1];
                end
                line_buf[0] <= data_in;
                
                // Logika komparasi (Baris genap vs Baris Ganjil)
                if (row_count[0] == 0) begin
                    if (col_count[0] == 0) begin
                        row_max <= data_in; // Simpan sementara
                    end else begin
                        if (data_in > row_max) line_buf[1] <= data_in;
                        else line_buf[1] <= row_max; // Simpan nilai max di buffer posisi khusus
                    end
                end else begin
                    // Baris ganjil: Perbandingan dengan baris atasnya yg ada di line_buf
                    if (col_count[0] == 0) begin
                        row_max <= data_in > line_buf[IMG_WIDTH-1] ? data_in : line_buf[IMG_WIDTH-1];
                    end else begin
                        valid_out <= 1; // Emit 1 maxpool output per blok 2x2
                        
                        // Perbandingan 4 elemen
                        if (data_in > row_max && data_in > line_buf[IMG_WIDTH-1]) begin
                            data_out <= data_in;
                        end else if (line_buf[IMG_WIDTH-1] > row_max) begin
                            data_out <= line_buf[IMG_WIDTH-1];
                        end else begin
                            data_out <= row_max;
                        end
                    end
                end
            end
        end
    end

endmodule
