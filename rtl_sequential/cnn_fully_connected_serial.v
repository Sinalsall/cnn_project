// ================================================================
// cnn_fully_connected_serial.v
// Serial/TDM fully connected layer. Captures IN_FEATURES serial
// features, then computes OUT_CLASSES scores with one iterative MAC.
// Weight/bias data is provided by a 1-cycle ROM response interface.
// ================================================================

module cnn_fully_connected_serial #(
    parameter DATA_WIDTH  = 16,
    parameter ACC_WIDTH   = 48,
    parameter IN_FEATURES = 490,
    parameter OUT_CLASSES = 10
)(
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    input wire last_in,
    output reg ready_out,
    input wire signed [DATA_WIDTH-1:0] data_in,

    output reg        mem_req_valid,
    output reg [1:0]  mem_req_kind,
    output reg [15:0] mem_req_addr,
    input wire signed [DATA_WIDTH-1:0] mem_resp_data,

    output reg valid_out,
    output reg last_out,
    output reg signed [DATA_WIDTH-1:0] score_out,
    output reg [3:0] class_idx
);

    localparam MEM_KIND_WEIGHT = 2'd0;
    localparam MEM_KIND_BIAS   = 2'd1;

    localparam S_CAPTURE  = 3'd0;
    localparam S_BIAS_REQ = 3'd1;
    localparam S_BIAS_CAP = 3'd2;
    localparam S_W_REQ    = 3'd3;
    localparam S_W_CAP    = 3'd4;
    localparam S_OUTPUT   = 3'd5;

    reg [2:0] state;
    reg [9:0] feat_count;
    reg [9:0] mac_feat;
    reg [3:0] mac_class;
    reg [3:0] out_class;
    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [DATA_WIDTH-1:0] features [0:IN_FEATURES-1];
    reg signed [DATA_WIDTH-1:0] scores [0:OUT_CLASSES-1];
    integer addr_calc;
    integer i;

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
            state <= S_CAPTURE;
            ready_out <= 1'b1;
            mem_req_valid <= 1'b0;
            mem_req_kind <= 2'd0;
            mem_req_addr <= 16'd0;
            valid_out <= 1'b0;
            last_out <= 1'b0;
            score_out <= {DATA_WIDTH{1'b0}};
            class_idx <= 4'd0;
            feat_count <= 10'd0;
            mac_feat <= 10'd0;
            mac_class <= 4'd0;
            out_class <= 4'd0;
            acc <= {ACC_WIDTH{1'b0}};
            for (i = 0; i < OUT_CLASSES; i = i + 1) scores[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            mem_req_valid <= 1'b0;
            valid_out <= 1'b0;
            last_out <= 1'b0;

            case (state)
                S_CAPTURE: begin
                    ready_out <= 1'b1;
                    if (valid_in) begin
                        features[feat_count] <= data_in;
                        if (last_in || feat_count == IN_FEATURES-1) begin
                            ready_out <= 1'b0;
                            feat_count <= 10'd0;
                            mac_class <= 4'd0;
                            state <= S_BIAS_REQ;
                        end else begin
                            feat_count <= feat_count + 1'b1;
                        end
                    end
                end

                S_BIAS_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_kind <= MEM_KIND_BIAS;
                    mem_req_addr <= {12'd0, mac_class};
                    state <= S_BIAS_CAP;
                end

                S_BIAS_CAP: begin
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){mem_resp_data[DATA_WIDTH-1]}}, mem_resp_data};
                    mac_feat <= 10'd0;
                    state <= S_W_REQ;
                end

                S_W_REQ: begin
                    addr_calc = (mac_class * IN_FEATURES) + mac_feat;
                    mem_req_valid <= 1'b1;
                    mem_req_kind <= MEM_KIND_WEIGHT;
                    mem_req_addr <= addr_calc[15:0];
                    state <= S_W_CAP;
                end

                S_W_CAP: begin
                    acc <= acc + q8_8_product(features[mac_feat], mem_resp_data);
                    if (mac_feat == IN_FEATURES-1) begin
                        scores[mac_class] <= trunc_acc(acc + q8_8_product(features[mac_feat], mem_resp_data));
                        mac_feat <= 10'd0;
                        if (mac_class == OUT_CLASSES-1) begin
                            out_class <= 4'd0;
                            state <= S_OUTPUT;
                        end else begin
                            mac_class <= mac_class + 1'b1;
                            state <= S_BIAS_REQ;
                        end
                    end else begin
                        mac_feat <= mac_feat + 1'b1;
                        state <= S_W_REQ;
                    end
                end

                S_OUTPUT: begin
                    valid_out <= 1'b1;
                    class_idx <= out_class;
                    score_out <= scores[out_class];
                    last_out <= (out_class == OUT_CLASSES-1);
                    if (out_class == OUT_CLASSES-1) begin
                        state <= S_CAPTURE;
                    end else begin
                        out_class <= out_class + 1'b1;
                    end
                end

                default: begin
                    state <= S_CAPTURE;
                end
            endcase
        end
    end

endmodule
