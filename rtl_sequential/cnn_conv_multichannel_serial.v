// ================================================================
// cnn_conv_multichannel_serial.v
// Standalone TDM convolution core for one spatial output position.
// The caller presents a 3x3 window for each input channel serially.
// For each accepted window the core accumulates all output channels
// with one iterative MAC and a 1-cycle ROM response interface.
// ================================================================

module cnn_conv_multichannel_serial #(
    parameter DATA_WIDTH  = 16,
    parameter ACC_WIDTH   = 48,
    parameter IN_CHANNELS = 1,
    parameter OUT_CHANNELS = 10
)(
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire last_in,
    output reg ready_out,

    input wire signed [DATA_WIDTH-1:0] w00,
    input wire signed [DATA_WIDTH-1:0] w01,
    input wire signed [DATA_WIDTH-1:0] w02,
    input wire signed [DATA_WIDTH-1:0] w10,
    input wire signed [DATA_WIDTH-1:0] w11,
    input wire signed [DATA_WIDTH-1:0] w12,
    input wire signed [DATA_WIDTH-1:0] w20,
    input wire signed [DATA_WIDTH-1:0] w21,
    input wire signed [DATA_WIDTH-1:0] w22,

    output reg        mem_req_valid,
    output reg [1:0]  mem_req_kind,
    output reg [15:0] mem_req_addr,
    input wire signed [DATA_WIDTH-1:0] mem_resp_data,

    output reg valid_out,
    output reg last_out,
    output reg [4:0] out_ch_idx,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    localparam MEM_KIND_WEIGHT = 2'd0;
    localparam MEM_KIND_BIAS   = 2'd1;

    localparam S_IDLE      = 3'd0;
    localparam S_BIAS_REQ  = 3'd1;
    localparam S_BIAS_CAP  = 3'd2;
    localparam S_W_REQ     = 3'd3;
    localparam S_W_CAP     = 3'd4;
    localparam S_EMIT      = 3'd5;

    reg [2:0] state;
    reg [4:0] in_ch_idx;
    reg [3:0] kernel_idx;
    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [DATA_WIDTH-1:0] win [0:8];
    reg saved_last;
    integer addr_calc;

    function signed [DATA_WIDTH-1:0] relu16;
        input signed [DATA_WIDTH-1:0] value;
        begin
            if (value[DATA_WIDTH-1]) relu16 = {DATA_WIDTH{1'b0}};
            else relu16 = value;
        end
    endfunction

    function signed [DATA_WIDTH-1:0] trunc_acc;
        input signed [ACC_WIDTH-1:0] value;
        begin
            trunc_acc = value[DATA_WIDTH-1:0];
        end
    endfunction

    function signed [ACC_WIDTH-1:0] q8_8_product;
        input signed [DATA_WIDTH-1:0] a;
        input signed [DATA_WIDTH-1:0] b;
        reg signed [(DATA_WIDTH*2)-1:0] product;
        begin
            product = a * b;
            q8_8_product = product >>> 8;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            ready_out <= 1'b1;
            mem_req_valid <= 1'b0;
            mem_req_kind <= 2'd0;
            mem_req_addr <= 16'd0;
            valid_out <= 1'b0;
            last_out <= 1'b0;
            out_ch_idx <= 5'd0;
            in_ch_idx <= 5'd0;
            kernel_idx <= 4'd0;
            data_out <= {DATA_WIDTH{1'b0}};
            acc <= {ACC_WIDTH{1'b0}};
            saved_last <= 1'b0;
        end else begin
            mem_req_valid <= 1'b0;
            valid_out <= 1'b0;
            last_out <= 1'b0;

            case (state)
                S_IDLE: begin
                    ready_out <= 1'b1;
                    out_ch_idx <= 5'd0;
                    in_ch_idx <= 5'd0;
                    kernel_idx <= 4'd0;
                    if (valid_in) begin
                        win[0] <= w00; win[1] <= w01; win[2] <= w02;
                        win[3] <= w10; win[4] <= w11; win[5] <= w12;
                        win[6] <= w20; win[7] <= w21; win[8] <= w22;
                        saved_last <= last_in;
                        ready_out <= 1'b0;
                        state <= S_BIAS_REQ;
                    end
                end

                S_BIAS_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_kind <= MEM_KIND_BIAS;
                    mem_req_addr <= {11'd0, out_ch_idx};
                    state <= S_BIAS_CAP;
                end

                S_BIAS_CAP: begin
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){mem_resp_data[DATA_WIDTH-1]}}, mem_resp_data};
                    in_ch_idx <= 5'd0;
                    kernel_idx <= 4'd0;
                    state <= S_W_REQ;
                end

                S_W_REQ: begin
                    addr_calc = (((out_ch_idx * IN_CHANNELS) + in_ch_idx) * 9) + kernel_idx;
                    mem_req_valid <= 1'b1;
                    mem_req_kind <= MEM_KIND_WEIGHT;
                    mem_req_addr <= addr_calc[15:0];
                    state <= S_W_CAP;
                end

                S_W_CAP: begin
                    acc <= acc + q8_8_product(win[kernel_idx], mem_resp_data);
                    if (kernel_idx == 4'd8) begin
                        kernel_idx <= 4'd0;
                        if (in_ch_idx == IN_CHANNELS-1) begin
                            data_out <= relu16(trunc_acc(acc + q8_8_product(win[kernel_idx], mem_resp_data)));
                            state <= S_EMIT;
                        end else begin
                            in_ch_idx <= in_ch_idx + 1'b1;
                            state <= S_W_REQ;
                        end
                    end else begin
                        kernel_idx <= kernel_idx + 1'b1;
                        state <= S_W_REQ;
                    end
                end

                S_EMIT: begin
                    valid_out <= 1'b1;
                    last_out <= saved_last && (out_ch_idx == OUT_CHANNELS-1);
                    if (out_ch_idx == OUT_CHANNELS-1) begin
                        out_ch_idx <= 5'd0;
                        ready_out <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        out_ch_idx <= out_ch_idx + 1'b1;
                        state <= S_BIAS_REQ;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
