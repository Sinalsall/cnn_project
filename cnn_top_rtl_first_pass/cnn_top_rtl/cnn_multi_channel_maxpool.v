// ================================================================
// Multi-channel 2x2 maxpool wrapper.
// ================================================================
module cnn_multi_channel_maxpool #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_SIZE = 28,
    parameter CH         = 10
)(
    input clk,
    input rst_n,
    input start,
    input signed [(CH*INPUT_SIZE*INPUT_SIZE*DATA_WIDTH)-1:0] frame_in,
    output busy,
    output done,
    output signed [(CH*(INPUT_SIZE/2)*(INPUT_SIZE/2)*DATA_WIDTH)-1:0] frame_out
);

    localparam IN_PIXELS  = INPUT_SIZE * INPUT_SIZE;
    localparam OUT_SIZE   = INPUT_SIZE / 2;
    localparam OUT_PIXELS = OUT_SIZE * OUT_SIZE;

    wire [CH-1:0] busy_ch;
    wire [CH-1:0] done_ch;

    genvar ch;
    generate
        for (ch = 0; ch < CH; ch = ch + 1) begin : GEN_POOL_CH
            cnn_maxpool #(
                .DATA_WIDTH(DATA_WIDTH),
                .INPUT_SIZE(INPUT_SIZE),
                .POOL_SIZE(2)
            ) u_pool (
                .clk(clk),
                .rst_n(rst_n),
                .start(start),
                .frame_in(frame_in[ch*IN_PIXELS*DATA_WIDTH +: IN_PIXELS*DATA_WIDTH]),
                .busy(busy_ch[ch]),
                .done(done_ch[ch]),
                .frame_out(frame_out[ch*OUT_PIXELS*DATA_WIDTH +: OUT_PIXELS*DATA_WIDTH])
            );
        end
    endgenerate

    assign busy = busy_ch[0];
    assign done = done_ch[0];

endmodule
