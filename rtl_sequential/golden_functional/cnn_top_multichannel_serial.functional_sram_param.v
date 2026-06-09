// ================================================================
// cnn_top_multichannel_serial.v
//
// Functional-correct sequential/TDM CNN top.
// Architecture:
//   Conv1 1->10, ReLU, Conv2 10->10, ReLU, Pool1 28->14,
//   Conv3 10->10, ReLU, Conv4 10->10, ReLU, Pool2 14->7,
//   FC 490->10.
//
// This block intentionally prioritizes golden-model equivalence over
// final OpenLane area. It uses internal activation memories and one
// iterative MAC datapath while weights/biases are supplied by a 1-cycle
// ROM/testbench response interface.
// ================================================================

module cnn_top_multichannel_serial #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 48
)(
    input wire clk,
    input wire rst_n,

    input wire valid_in,
    output reg ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    input wire last_in,

    output reg        mem_req_valid,
    output reg [2:0]  mem_req_layer,
    output reg [1:0]  mem_req_kind,
    output reg [15:0] mem_req_addr,
    input wire signed [DATA_WIDTH-1:0] mem_resp_data,

    output reg valid_out,
    output reg [3:0] class_idx,
    output reg signed [DATA_WIDTH-1:0] score_out,
    output reg last_out
);

    localparam MEM_KIND_WEIGHT = 2'd0;
    localparam MEM_KIND_BIAS   = 2'd1;

    localparam L_CONV1 = 3'd0;
    localparam L_CONV2 = 3'd1;
    localparam L_CONV3 = 3'd2;
    localparam L_CONV4 = 3'd3;
    localparam L_FC    = 3'd4;

    localparam S_LOAD          = 5'd0;
    localparam S_CONV_START    = 5'd1;
    localparam S_CONV_BIAS_REQ = 5'd2;
    localparam S_CONV_BIAS_CAP = 5'd3;
    localparam S_CONV_W_REQ    = 5'd4;
    localparam S_CONV_W_CAP    = 5'd5;
    localparam S_POOL          = 5'd6;
    localparam S_FC_START      = 5'd7;
    localparam S_FC_BIAS_REQ   = 5'd8;
    localparam S_FC_BIAS_CAP   = 5'd9;
    localparam S_FC_W_REQ      = 5'd10;
    localparam S_FC_W_CAP      = 5'd11;
    localparam S_OUTPUT        = 5'd12;
    localparam S_DONE          = 5'd13;
    localparam S_CONV_BIAS_WAIT = 5'd14;
    localparam S_CONV_W_WAIT    = 5'd15;
    localparam S_FC_BIAS_WAIT   = 5'd16;
    localparam S_FC_W_WAIT      = 5'd17;

    reg [4:0] state;
    reg [2:0] conv_layer;

    reg signed [DATA_WIDTH-1:0] image_mem [0:783];
    reg signed [DATA_WIDTH-1:0] act1_mem  [0:7839];
    reg signed [DATA_WIDTH-1:0] act2_mem  [0:7839];
    reg signed [DATA_WIDTH-1:0] pool1_mem [0:1959];
    reg signed [DATA_WIDTH-1:0] act3_mem  [0:1959];
    reg signed [DATA_WIDTH-1:0] act4_mem  [0:1959];
    reg signed [DATA_WIDTH-1:0] pool2_mem [0:489];
    reg signed [DATA_WIDTH-1:0] scores    [0:9];

    reg [10:0] load_count;
    reg [4:0]  out_ch;
    reg [4:0]  in_ch;
    reg [3:0]  k_idx;
    reg [4:0]  row;
    reg [4:0]  col;
    reg [9:0]  feat_idx;
    reg [3:0]  fc_class;
    reg [3:0]  out_idx;
    reg signed [ACC_WIDTH-1:0] acc;

    integer src_row;
    integer src_col;
    integer weight_addr_calc;
    integer i;

    function integer conv_width;
        input [2:0] layer;
        begin
            if (layer == L_CONV1 || layer == L_CONV2) conv_width = 28;
            else conv_width = 14;
        end
    endfunction

    function integer conv_in_ch;
        input [2:0] layer;
        begin
            if (layer == L_CONV1) conv_in_ch = 1;
            else conv_in_ch = 10;
        end
    endfunction

    function signed [DATA_WIDTH-1:0] relu16;
        input signed [DATA_WIDTH-1:0] value;
        begin
            if (value[DATA_WIDTH-1]) relu16 = {DATA_WIDTH{1'b0}};
            else relu16 = value;
        end
    endfunction

    function signed [DATA_WIDTH-1:0] conv_src_value;
        input [2:0] layer;
        input integer ch;
        input integer r;
        input integer c;
        integer width;
        begin
            width = conv_width(layer);
            if (r < 0 || c < 0 || r >= width || c >= width) begin
                conv_src_value = {DATA_WIDTH{1'b0}};
            end else if (layer == L_CONV1) begin
                conv_src_value = image_mem[r*28 + c];
            end else if (layer == L_CONV2) begin
                conv_src_value = act1_mem[ch*784 + r*28 + c];
            end else if (layer == L_CONV3) begin
                conv_src_value = pool1_mem[ch*196 + r*14 + c];
            end else begin
                conv_src_value = act3_mem[ch*196 + r*14 + c];
            end
        end
    endfunction

    function signed [DATA_WIDTH-1:0] max2;
        input signed [DATA_WIDTH-1:0] a;
        input signed [DATA_WIDTH-1:0] b;
        begin
            if (a > b) max2 = a;
            else max2 = b;
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

    task write_conv_dst;
        input [2:0] layer;
        input integer ch;
        input integer r;
        input integer c;
        input signed [DATA_WIDTH-1:0] value;
        begin
            if (layer == L_CONV1) begin
                act1_mem[ch*784 + r*28 + c] <= relu16(value);
            end else if (layer == L_CONV2) begin
                act2_mem[ch*784 + r*28 + c] <= relu16(value);
            end else if (layer == L_CONV3) begin
                act3_mem[ch*196 + r*14 + c] <= relu16(value);
            end else begin
                act4_mem[ch*196 + r*14 + c] <= relu16(value);
            end
        end
    endtask

    task advance_conv_position;
        begin
            if (out_ch == 9) begin
                out_ch <= 0;
                if (col == conv_width(conv_layer)-1) begin
                    col <= 0;
                    if (row == conv_width(conv_layer)-1) begin
                        row <= 0;
                        if (conv_layer == L_CONV2 || conv_layer == L_CONV4) begin
                            state <= S_POOL;
                        end else begin
                            conv_layer <= conv_layer + 1'b1;
                            state <= S_CONV_START;
                        end
                    end else begin
                        row <= row + 1'b1;
                        state <= S_CONV_START;
                    end
                end else begin
                    col <= col + 1'b1;
                    state <= S_CONV_START;
                end
            end else begin
                out_ch <= out_ch + 1'b1;
                state <= S_CONV_START;
            end
        end
    endtask

    task advance_pool_position;
        begin
            if (out_ch == 9) begin
                out_ch <= 0;
                if (col == (conv_width(conv_layer)/2)-1) begin
                    col <= 0;
                    if (row == (conv_width(conv_layer)/2)-1) begin
                        row <= 0;
                        if (conv_layer == L_CONV2) begin
                            conv_layer <= L_CONV3;
                            state <= S_CONV_START;
                        end else begin
                            state <= S_FC_START;
                        end
                    end else begin
                        row <= row + 1'b1;
                    end
                end else begin
                    col <= col + 1'b1;
                end
            end else begin
                out_ch <= out_ch + 1'b1;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_LOAD;
            ready_out <= 1'b1;
            mem_req_valid <= 1'b0;
            mem_req_layer <= 3'd0;
            mem_req_kind <= 2'd0;
            mem_req_addr <= 16'd0;
            valid_out <= 1'b0;
            class_idx <= 4'd0;
            score_out <= {DATA_WIDTH{1'b0}};
            last_out <= 1'b0;
            load_count <= 11'd0;
            conv_layer <= L_CONV1;
            out_ch <= 5'd0;
            in_ch <= 5'd0;
            k_idx <= 4'd0;
            row <= 5'd0;
            col <= 5'd0;
            feat_idx <= 10'd0;
            fc_class <= 4'd0;
            out_idx <= 4'd0;
            acc <= {ACC_WIDTH{1'b0}};
            for (i = 0; i < 10; i = i + 1) scores[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            mem_req_valid <= 1'b0;
            valid_out <= 1'b0;
            last_out <= 1'b0;

            case (state)
                S_LOAD: begin
                    ready_out <= 1'b1;
                    if (valid_in) begin
                        image_mem[load_count] <= pixel_in;
                        if (last_in || load_count == 11'd783) begin
                            ready_out <= 1'b0;
                            load_count <= 11'd0;
                            conv_layer <= L_CONV1;
                            out_ch <= 5'd0;
                            in_ch <= 5'd0;
                            k_idx <= 4'd0;
                            row <= 5'd0;
                            col <= 5'd0;
                            state <= S_CONV_START;
                        end else begin
                            load_count <= load_count + 1'b1;
                        end
                    end
                end

                S_CONV_START: begin
                    in_ch <= 5'd0;
                    k_idx <= 4'd0;
                    state <= S_CONV_BIAS_REQ;
                end

                S_CONV_BIAS_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_layer <= conv_layer;
                    mem_req_kind <= MEM_KIND_BIAS;
                    mem_req_addr <= {12'd0, out_ch[3:0]};
                    state <= S_CONV_BIAS_WAIT;
                end

                S_CONV_BIAS_WAIT: begin
                    state <= S_CONV_BIAS_CAP;
                end

                S_CONV_BIAS_CAP: begin
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){mem_resp_data[DATA_WIDTH-1]}}, mem_resp_data};
                    state <= S_CONV_W_REQ;
                end

                S_CONV_W_REQ: begin
                    weight_addr_calc = (((out_ch * conv_in_ch(conv_layer)) + in_ch) * 9) + k_idx;
                    mem_req_valid <= 1'b1;
                    mem_req_layer <= conv_layer;
                    mem_req_kind <= MEM_KIND_WEIGHT;
                    mem_req_addr <= weight_addr_calc[15:0];
                    state <= S_CONV_W_WAIT;
                end

                S_CONV_W_WAIT: begin
                    state <= S_CONV_W_CAP;
                end

                S_CONV_W_CAP: begin
                    src_row = row;
                    src_col = col;
                    src_row = src_row + (k_idx / 3) - 1;
                    src_col = src_col + (k_idx % 3) - 1;
                    acc <= acc + q8_8_product(conv_src_value(conv_layer, in_ch, src_row, src_col), mem_resp_data);

                    if (k_idx == 4'd8) begin
                        k_idx <= 4'd0;
                        if (in_ch == conv_in_ch(conv_layer)-1) begin
                            write_conv_dst(conv_layer, out_ch, row, col,
                                           trunc_acc(acc + q8_8_product(conv_src_value(conv_layer, in_ch, src_row, src_col), mem_resp_data)));
                            in_ch <= 5'd0;
                            advance_conv_position();
                        end else begin
                            in_ch <= in_ch + 1'b1;
                            state <= S_CONV_W_REQ;
                        end
                    end else begin
                        k_idx <= k_idx + 1'b1;
                        state <= S_CONV_W_REQ;
                    end
                end

                S_POOL: begin
                    if (conv_layer == L_CONV2) begin
                        pool1_mem[out_ch*196 + row*14 + col] <=
                            max2(max2(act2_mem[out_ch*784 + (row*2)*28 + (col*2)],
                                      act2_mem[out_ch*784 + (row*2)*28 + (col*2 + 1)]),
                                 max2(act2_mem[out_ch*784 + (row*2 + 1)*28 + (col*2)],
                                      act2_mem[out_ch*784 + (row*2 + 1)*28 + (col*2 + 1)]));
                    end else begin
                        pool2_mem[out_ch*49 + row*7 + col] <=
                            max2(max2(act4_mem[out_ch*196 + (row*2)*14 + (col*2)],
                                      act4_mem[out_ch*196 + (row*2)*14 + (col*2 + 1)]),
                                 max2(act4_mem[out_ch*196 + (row*2 + 1)*14 + (col*2)],
                                      act4_mem[out_ch*196 + (row*2 + 1)*14 + (col*2 + 1)]));
                    end
                    advance_pool_position();
                end

                S_FC_START: begin
                    fc_class <= 4'd0;
                    feat_idx <= 10'd0;
                    state <= S_FC_BIAS_REQ;
                end

                S_FC_BIAS_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_layer <= L_FC;
                    mem_req_kind <= MEM_KIND_BIAS;
                    mem_req_addr <= {12'd0, fc_class};
                    state <= S_FC_BIAS_WAIT;
                end

                S_FC_BIAS_WAIT: begin
                    state <= S_FC_BIAS_CAP;
                end

                S_FC_BIAS_CAP: begin
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){mem_resp_data[DATA_WIDTH-1]}}, mem_resp_data};
                    feat_idx <= 10'd0;
                    state <= S_FC_W_REQ;
                end

                S_FC_W_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_layer <= L_FC;
                    mem_req_kind <= MEM_KIND_WEIGHT;
                    mem_req_addr <= (fc_class * 490) + feat_idx;
                    state <= S_FC_W_WAIT;
                end

                S_FC_W_WAIT: begin
                    state <= S_FC_W_CAP;
                end

                S_FC_W_CAP: begin
                    acc <= acc + q8_8_product(pool2_mem[feat_idx], mem_resp_data);
                    if (feat_idx == 10'd489) begin
                        scores[fc_class] <= trunc_acc(acc + q8_8_product(pool2_mem[feat_idx], mem_resp_data));
                        feat_idx <= 10'd0;
                        if (fc_class == 4'd9) begin
                            out_idx <= 4'd0;
                            state <= S_OUTPUT;
                        end else begin
                            fc_class <= fc_class + 1'b1;
                            state <= S_FC_BIAS_REQ;
                        end
                    end else begin
                        feat_idx <= feat_idx + 1'b1;
                        state <= S_FC_W_REQ;
                    end
                end

                S_OUTPUT: begin
                    valid_out <= 1'b1;
                    class_idx <= out_idx;
                    score_out <= scores[out_idx];
                    last_out <= (out_idx == 4'd9);
                    if (out_idx == 4'd9) begin
                        state <= S_DONE;
                    end else begin
                        out_idx <= out_idx + 1'b1;
                    end
                end

                S_DONE: begin
                    ready_out <= 1'b1;
                    state <= S_LOAD;
                end

                default: begin
                    state <= S_LOAD;
                end
            endcase
        end
    end

endmodule
