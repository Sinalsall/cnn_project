module line_buffer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH  = 28
)(
    input wire clk,
    input wire rst_n,
    
    // Antarmuka Stream Input
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    // Antarmuka Stream Output (Window 3x3)
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] w00, output reg signed [DATA_WIDTH-1:0] w01, output reg signed [DATA_WIDTH-1:0] w02,
    output reg signed [DATA_WIDTH-1:0] w10, output reg signed [DATA_WIDTH-1:0] w11, output reg signed [DATA_WIDTH-1:0] w12,
    output reg signed [DATA_WIDTH-1:0] w20, output reg signed [DATA_WIDTH-1:0] w21, output reg signed [DATA_WIDTH-1:0] w22
);

    // Buffer baris memakan 2 baris * IMG_WIDTH = 56 register (Sangat hemat area)
    reg signed [DATA_WIDTH-1:0] line1 [0:IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] line2 [0:IMG_WIDTH-1];

    // Tracker posisi baris dan kolom 
    reg [9:0] col_count;
    reg [9:0] row_count;
    
    integer i;

    wire signed [DATA_WIDTH-1:0] out_line1 = line1[IMG_WIDTH-1];
    wire signed [DATA_WIDTH-1:0] out_line2 = line2[IMG_WIDTH-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            col_count <= 0;
            row_count <= 0;
            
            w00 <= 0; w01 <= 0; w02 <= 0;
            w10 <= 0; w11 <= 0; w12 <= 0;
            w20 <= 0; w21 <= 0; w22 <= 0;
            
            for (i=0; i<IMG_WIDTH; i=i+1) begin
                line1[i] <= 0;
                line2[i] <= 0;
            end
        end else begin
            valid_out <= 0; // Default off
            
            if (valid_in) begin
                // Update 3x3 window (Shift register geser ke kiri)
                w00 <= w01; w01 <= w02; w02 <= out_line2;
                w10 <= w11; w11 <= w12; w12 <= out_line1;
                w20 <= w21; w21 <= w22; w22 <= data_in;

                // Update Line Buffers
                for (i=IMG_WIDTH-1; i>0; i=i-1) begin
                    line2[i] <= line2[i-1];
                    line1[i] <= line1[i-1];
                end
                line2[0] <= out_line1;
                line1[0] <= data_in;

                // Logika padding validitas
                if (col_count == IMG_WIDTH - 1) begin
                    col_count <= 0;
                    if (row_count < IMG_WIDTH - 1) begin
                        row_count <= row_count + 1;
                    end
                end else begin
                    col_count <= col_count + 1;
                end
                
                // Mulai tembak valid jika minimal sudah terisi 2 baris penuh + 3 kolom saat ini
                if (row_count >= 2 && col_count >= 2) begin
                    valid_out <= 1;
                end else if (row_count >= 2 && col_count < 2) begin
                    valid_out <= 0; // Border tepi (invalid center) jika dibutuhkan padding
                end
            end
        end
    end

endmodule
