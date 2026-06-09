// ==========================================
// Module: Parallel ReLU Activation Function
// ==========================================
// Applies ReLU to every element in a full feature map.
//
// Input  : IMG_SIZE x IMG_SIZE feature map, flattened bus
// Output : IMG_SIZE x IMG_SIZE feature map, flattened bus
//
// ReLU(x) = max(0, x)
//
// Example:
// IMG_SIZE   = 28
// NUM_PIXELS = 784
// DATA_WIDTH = 16 or 32

module cnn_relu #(
    parameter DATA_WIDTH = 16,
    parameter IMG_SIZE   = 28
)(
    input clk,
    input rst_n,
    input valid_in,

    input signed [(IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_in,

    output reg valid_out,
    output reg signed [(IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_out
);

    localparam TOTAL_PIXELS = IMG_SIZE * IMG_SIZE;

    integer i;

    reg signed [DATA_WIDTH-1:0] current_pixel;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            feature_map_out <= 0;
        end else begin
            valid_out <= valid_in;

            if (valid_in) begin
                for (i = 0; i < TOTAL_PIXELS; i = i + 1) begin
                    current_pixel = feature_map_in[i*DATA_WIDTH +: DATA_WIDTH];

                    if (current_pixel[DATA_WIDTH-1] == 1'b1) begin
                        feature_map_out[i*DATA_WIDTH +: DATA_WIDTH] <= 0;
                    end else begin
                        feature_map_out[i*DATA_WIDTH +: DATA_WIDTH] <= current_pixel;
                    end
                end
            end
        end
    end

endmodule
