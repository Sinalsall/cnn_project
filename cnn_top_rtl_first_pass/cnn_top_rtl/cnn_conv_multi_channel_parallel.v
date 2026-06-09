// ================================================================
// cnn_conv_multi_channel_parallel.v
// Structural proof-of-concept wrapper for multi-channel convolution.
//
// Verilog-2005 compatible.
// WARNING:
//   This wrapper instantiates IN_CH*OUT_CH copies of the existing
//   cnn_convolution_index_based module. This is functional/structural
//   RTL for simulation bring-up, not an area-efficient ASIC architecture.
//
//   The existing cnn_convolution_index_based module truncates its MAC
//   result internally to OUT_WIDTH. For numerical equivalence against
//   PyTorch, that convolution module should later be revised to use a
//   wider accumulator and explicit quantization/saturation.
// ================================================================

module cnn_conv_multi_channel_parallel #(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 16,
    parameter ACC_WIDTH  = 40,
    parameter IMG_SIZE   = 28,
    parameter IN_CH      = 1,
    parameter OUT_CH     = 10
)(
    input clk,
    input rst_n,
    input valid_in,

    // Flattening order:
    //   feature_map_in[(ch*IMG_SIZE*IMG_SIZE + pixel)*DATA_WIDTH +: DATA_WIDTH]
    input signed [(IN_CH*IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_in,

    // Flattening order:
    //   weights[(((out_ch*IN_CH + in_ch)*9 + k)*DATA_WIDTH) +: DATA_WIDTH]
    input signed [(OUT_CH*IN_CH*9*DATA_WIDTH)-1:0] weights,

    // One 16-bit bias per output channel.
    input signed [(OUT_CH*DATA_WIDTH)-1:0] bias,

    output reg valid_out,
    output reg signed [(OUT_CH*IMG_SIZE*IMG_SIZE*OUT_WIDTH)-1:0] feature_map_out
);

    localparam PIXELS = IMG_SIZE * IMG_SIZE;

    wire [(OUT_CH*IN_CH*PIXELS*OUT_WIDTH)-1:0] partial_out;
    wire [(OUT_CH*IN_CH)-1:0] partial_valid;

    genvar oc, ic;
    generate
        for (oc = 0; oc < OUT_CH; oc = oc + 1) begin : GEN_OC
            for (ic = 0; ic < IN_CH; ic = ic + 1) begin : GEN_IC
                localparam integer INST_IDX = oc*IN_CH + ic;
                localparam integer W_BASE   = (INST_IDX*9*DATA_WIDTH);
                localparam integer FM_BASE  = (ic*PIXELS*DATA_WIDTH);
                localparam integer PO_BASE  = (INST_IDX*PIXELS*OUT_WIDTH);

                cnn_convolution_index_based #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .OUT_WIDTH(OUT_WIDTH),
                    .IMG_SIZE(IMG_SIZE)
                ) u_conv_single (
                    .clk(clk),
                    .rst_n(rst_n),
                    .valid_in(valid_in),
                    .feature_map_in(feature_map_in[FM_BASE +: PIXELS*DATA_WIDTH]),
                    .kernel_0(weights[W_BASE + 0*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_1(weights[W_BASE + 1*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_2(weights[W_BASE + 2*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_3(weights[W_BASE + 3*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_4(weights[W_BASE + 4*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_5(weights[W_BASE + 5*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_6(weights[W_BASE + 6*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_7(weights[W_BASE + 7*DATA_WIDTH +: DATA_WIDTH]),
                    .kernel_8(weights[W_BASE + 8*DATA_WIDTH +: DATA_WIDTH]),
                    .bias(16'sd0),
                    .valid_out(partial_valid[INST_IDX]),
                    .feature_map_out(partial_out[PO_BASE +: PIXELS*OUT_WIDTH])
                );
            end
        end
    endgenerate

    reg partial_valid_q;
    integer oc_i;
    integer ic_i;
    integer pix_i;
    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [OUT_WIDTH-1:0] partial_sample;

    always @(posedge clk) begin
        if (!rst_n) begin
            partial_valid_q <= 1'b0;
            valid_out <= 1'b0;
            feature_map_out <= 0;
        end else begin
            // All partial conv instances are launched together and should finish together.
            // Delay by one cycle so partial_out has already been registered by child modules.
            partial_valid_q <= partial_valid[0];
            valid_out <= partial_valid_q;

            if (partial_valid_q) begin
                for (oc_i = 0; oc_i < OUT_CH; oc_i = oc_i + 1) begin
                    for (pix_i = 0; pix_i < PIXELS; pix_i = pix_i + 1) begin
                        acc = $signed(bias[oc_i*DATA_WIDTH +: DATA_WIDTH]);
                        for (ic_i = 0; ic_i < IN_CH; ic_i = ic_i + 1) begin
                            partial_sample = $signed(partial_out[((oc_i*IN_CH + ic_i)*PIXELS + pix_i)*OUT_WIDTH +: OUT_WIDTH]);
                            acc = acc + partial_sample;
                        end
                        // Temporary quantization: truncate to OUT_WIDTH.
                        // Replace with explicit rounding/saturation after fixed-point format is fixed.
                        feature_map_out[(oc_i*PIXELS + pix_i)*OUT_WIDTH +: OUT_WIDTH] <= acc[OUT_WIDTH-1:0];
                    end
                end
            end
        end
    end

endmodule
