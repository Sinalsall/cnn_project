`timescale 1ns/1ps

// ================================================================
// Multi-channel ReLU wrapper.
// Input/output memakai packed bus:
//   feature_map_in  = CH x IMG_SIZE x IMG_SIZE x DATA_WIDTH
//   feature_map_out = CH x IMG_SIZE x IMG_SIZE x DATA_WIDTH
//
// Channel packing:
//   channel ch berada pada:
//   feature_map[ch*PIXELS*DATA_WIDTH +: PIXELS*DATA_WIDTH]
// ================================================================
module cnn_multi_channel_relu #(
    parameter DATA_WIDTH = 16,
    parameter IMG_SIZE   = 28,
    parameter CH         = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,

    input  wire signed [(CH*IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_in,

    output wire valid_out,
    output wire signed [(CH*IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_out
);

    localparam PIXELS = IMG_SIZE * IMG_SIZE;

    wire [CH-1:0] valid_ch;

    genvar ch;
    generate
        for (ch = 0; ch < CH; ch = ch + 1) begin : GEN_RELU_CH
            cnn_relu #(
                .DATA_WIDTH(DATA_WIDTH),
                .IMG_SIZE(IMG_SIZE)
            ) u_relu (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(valid_in),
                .feature_map_in(feature_map_in[ch*PIXELS*DATA_WIDTH +: PIXELS*DATA_WIDTH]),
                .valid_out(valid_ch[ch]),
                .feature_map_out(feature_map_out[ch*PIXELS*DATA_WIDTH +: PIXELS*DATA_WIDTH])
            );
        end
    endgenerate

    // Karena semua channel diberi valid_in yang sama,
    // valid_out setiap channel seharusnya serempak.
    assign valid_out = valid_ch[0];

endmodule
