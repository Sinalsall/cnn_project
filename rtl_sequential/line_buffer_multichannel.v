module line_buffer_multichannel #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH  = 28,
    parameter CHANNELS   = 10
)(
    input wire clk,
    input wire rst_n,
    
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg valid_out,
    // Output jendela 3x3 untuk 1 channel saat ini
    output reg signed [DATA_WIDTH-1:0] w00, output reg signed [DATA_WIDTH-1:0] w01, output reg signed [DATA_WIDTH-1:0] w02,
    output reg signed [DATA_WIDTH-1:0] w10, output reg signed [DATA_WIDTH-1:0] w11, output reg signed [DATA_WIDTH-1:0] w12,
    output reg signed [DATA_WIDTH-1:0] w20, output reg signed [DATA_WIDTH-1:0] w21, output reg signed [DATA_WIDTH-1:0] w22
);

    // Karena 1 pixel memiliki N channel, panjang buffer baris dikalikan N
    localparam LINE_DEPTH = IMG_WIDTH * CHANNELS;
    
    // RAM berbasis reg untuk menampung dua baris matriks piksel * channel
    reg signed [DATA_WIDTH-1:0] line1 [0:LINE_DEPTH-1];
    reg signed [DATA_WIDTH-1:0] line2 [0:LINE_DEPTH-1];
    
    reg [15:0] count;
    reg [4:0]  ch_idx;
    integer i;

    wire signed [DATA_WIDTH-1:0] out_line1 = line1[LINE_DEPTH-1];
    wire signed [DATA_WIDTH-1:0] out_line2 = line2[LINE_DEPTH-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            count <= 0;
            ch_idx <= 0;
            w00<=0; w01<=0; w02<=0; w10<=0; w11<=0; w12<=0; w20<=0; w21<=0; w22<=0;
            for(i=0; i<LINE_DEPTH; i=i+1) begin
                line1[i] <= 0;
                line2[i] <= 0;
            end
        end else begin
            valid_out <= 0;
            
            if (valid_in) begin
                // Update Line Buffers
                for (i=LINE_DEPTH-1; i>0; i=i-1) begin
                    line2[i] <= line2[i-1];
                    line1[i] <= line1[i-1];
                end
                line2[0] <= out_line1;
                line1[0] <= data_in;
                
                // Ambil window sesuai jeda channel spacing
                // Jendela berjarak CHANNELS pergeserannya untuk mendapat pixel tetangga secara spasial
                w00 <= line2[CHANNELS*2 - 1]; w01 <= line2[CHANNELS - 1]; w02 <= out_line2;
                w10 <= line1[CHANNELS*2 - 1]; w11 <= line1[CHANNELS - 1]; w12 <= out_line1;
                w20 <= data_in;               w21 <= line1[0];            w22 <= line1[CHANNELS - 1]; // Offset spasial

                if (count >= LINE_DEPTH * 2) begin
                    valid_out <= 1; // Telah aman 2 baris
                end else begin
                    count <= count + 1;
                end
                
                if (ch_idx == CHANNELS - 1) ch_idx <= 0;
                else ch_idx <= ch_idx + 1;
            end
        end
    end

endmodule
