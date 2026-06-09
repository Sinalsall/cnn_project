`timescale 1ns/1ps

// ================================================================
// Multi-channel MaxPool wrapper.
// Wrapper ini membungkus cnn_maxpool.v untuk beberapa channel.
//
// Port dibuat konsisten dengan testbench:
//   valid_in        -> start untuk semua channel
//   feature_map_in  -> packed input bus
//   valid_out       -> done semua channel
//   feature_map_out -> packed output bus
//
// Channel packing:
//   input channel ch:
//     feature_map_in[ch*IN_PIXELS*DATA_WIDTH +: IN_PIXELS*DATA_WIDTH]
//
//   output channel ch:
//     feature_map_out[ch*OUT_PIXELS*DATA_WIDTH +: OUT_PIXELS*DATA_WIDTH]
// ================================================================
module cnn_multi_channel_maxpool #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_SIZE = 28,
    parameter POOL_SIZE  = 2,
    parameter CH         = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,

    input  wire signed [(CH*INPUT_SIZE*INPUT_SIZE*DATA_WIDTH)-1:0] feature_map_in,

    output wire valid_out,
    output wire signed [(CH*(INPUT_SIZE/POOL_SIZE)*(INPUT_SIZE/POOL_SIZE)*DATA_WIDTH)-1:0] feature_map_out
);

    localparam OUTPUT_SIZE = INPUT_SIZE / POOL_SIZE;
    localparam IN_PIXELS   = INPUT_SIZE * INPUT_SIZE;
    localparam OUT_PIXELS  = OUTPUT_SIZE * OUTPUT_SIZE;

    wire [CH-1:0] busy_ch;
    wire [CH-1:0] done_ch;

    genvar ch;
    generate
        for (ch = 0; ch < CH; ch = ch + 1) begin : GEN_MAXPOOL_CH
            cnn_maxpool #(
                .DATA_WIDTH(DATA_WIDTH),
                .INPUT_SIZE(INPUT_SIZE),
                .POOL_SIZE(POOL_SIZE)
            ) u_maxpool (
                .clk(clk),
                .rst_n(rst_n),
                .start(valid_in),

                .frame_in(feature_map_in[ch*IN_PIXELS*DATA_WIDTH +: IN_PIXELS*DATA_WIDTH]),

                .busy(busy_ch[ch]),
                .done(done_ch[ch]),

                .frame_out(feature_map_out[ch*OUT_PIXELS*DATA_WIDTH +: OUT_PIXELS*DATA_WIDTH])
            );
        end
    endgenerate

    // Semua channel diberi start yang sama, jadi done seharusnya serempak.
    // Pakai AND agar valid_out hanya naik saat semua channel selesai.
    assign valid_out = &done_ch;

endmodule
