// ================================================================
// cnn_top_multichannel_serial.v
// Sequential/TDM CNN top with parameter SRAM interface and internal
// activation SRAM bank.
//
// Architecture:
//   Conv1 1->10, ReLU, Conv2 10->10, ReLU, Pool1 28->14,
//   Conv3 10->10, ReLU, Conv4 10->10, ReLU, Pool2 14->7,
//   FC 490->10.
//
// Parameters are requested through mem_req_* and supplied with 1-cycle
// synchronous SRAM latency. Activations are stored in cnn_activation_sram_bank.
// ================================================================

module cnn_top_multichannel_serial #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 48
)(
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
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

    localparam BUF_A = 16'd0;
    localparam BUF_B = 16'd8192;

    localparam S_LOAD             = 6'd0;
    localparam S_LOAD_FLUSH       = 6'd1;
    localparam S_CONV_START       = 6'd2;
    localparam S_CONV_W_REQ       = 6'd6;
    localparam S_CONV_W_WAIT      = 6'd7;
    localparam S_CONV_W_CAP       = 6'd8;
    localparam S_POOL_START       = 6'd9;
    localparam S_POOL_REQ         = 6'd10;
    localparam S_POOL_WAIT        = 6'd11;
    localparam S_POOL_CAP         = 6'd12;
    localparam S_FC_START         = 6'd13;
    localparam S_FC_W_REQ         = 6'd17;
    localparam S_FC_W_WAIT        = 6'd18;
    localparam S_FC_W_CAP         = 6'd19;
    localparam S_OUTPUT           = 6'd20;
    localparam S_DONE             = 6'd21;
    localparam S_BIAS_PRELOAD_START = 6'd22;
    localparam S_BIAS_PRELOAD_REQ   = 6'd23;
    localparam S_BIAS_PRELOAD_WAIT  = 6'd24;
    localparam S_BIAS_PRELOAD_CAP   = 6'd25;

    reg [5:0] state;
    reg [2:0] conv_layer;

    reg [10:0] load_count;
    reg [4:0]  out_ch;
    reg [4:0]  in_ch;
    reg [3:0]  k_idx;
    reg [4:0]  row;
    reg [4:0]  col;
    reg [9:0]  feat_idx;
    reg [3:0]  fc_class;
    reg [3:0]  out_idx;
    reg [1:0]  pool_idx;
    reg [3:0]  bias_idx;
    reg [2:0]  bias_layer;
    reg signed [DATA_WIDTH-1:0] pool_max;
    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [DATA_WIDTH-1:0] bias_regs [0:9];
    reg signed [DATA_WIDTH-1:0] scores [0:9];

    reg act_rd_en;
    reg [15:0] act_rd_addr;
    wire [15:0] act_rd_data_raw;
    wire signed [DATA_WIDTH-1:0] act_rd_data = act_rd_data_raw;
    reg act_wr_en;
    reg [15:0] act_wr_addr;
    reg [15:0] act_wr_data;
    wire act_same_bank_conflict;
    wire _unused_act_conflict = act_same_bank_conflict;
    wire [15:0] load_act_addr = BUF_A + {5'd0, load_count};

    integer src_row;
    integer src_col;
    integer i;

    cnn_activation_sram_bank u_activation_sram (
`ifdef USE_POWER_PINS
        .VDD(VDD),
        .VSS(VSS),
`endif
        .clk(clk),
        .rd_en(act_rd_en),
        .rd_addr(act_rd_addr),
        .rd_data(act_rd_data_raw),
        .wr_en(act_wr_en),
        .wr_addr(act_wr_addr),
        .wr_data(act_wr_data),
        .same_bank_conflict(act_same_bank_conflict)
    );

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

    function [4:0] conv_width_last;
        input [2:0] layer;
        begin
            if (layer == L_CONV1 || layer == L_CONV2) conv_width_last = 5'd27;
            else conv_width_last = 5'd13;
        end
    endfunction

    function [4:0] pool_width_last;
        input [2:0] layer;
        begin
            if (layer == L_CONV2) pool_width_last = 5'd13;
            else pool_width_last = 5'd6;
        end
    endfunction

    function [4:0] conv_in_ch_last;
        input [2:0] layer;
        begin
            if (layer == L_CONV1) conv_in_ch_last = 5'd0;
            else conv_in_ch_last = 5'd9;
        end
    endfunction

    function [15:0] conv_src_base;
        input [2:0] layer;
        begin
            if (layer == L_CONV1) conv_src_base = BUF_A;
            else if (layer == L_CONV2) conv_src_base = BUF_B;
            else if (layer == L_CONV3) conv_src_base = BUF_B;
            else conv_src_base = BUF_A;
        end
    endfunction

    function [15:0] conv_dst_base;
        input [2:0] layer;
        begin
            if (layer == L_CONV1) conv_dst_base = BUF_B;
            else if (layer == L_CONV2) conv_dst_base = BUF_A;
            else if (layer == L_CONV3) conv_dst_base = BUF_A;
            else conv_dst_base = BUF_B;
        end
    endfunction

/* verilator lint_off BLKSEQ */
/* verilator lint_off UNUSEDSIGNAL */
    function [15:0] tensor_addr;
        input [15:0] base;
        input [4:0] ch;
        input [4:0] r;
        input [4:0] c;
        input integer width;
        integer addr_calc;
        integer base_i;
        integer ch_i;
        integer r_i;
        integer c_i;
        begin
            base_i = {16'd0, base};
            ch_i = {27'd0, ch};
            r_i = {27'd0, r};
            c_i = {27'd0, c};
            if (width == 28) begin
                addr_calc = base_i + (ch_i << 9) + (ch_i << 8) + (ch_i << 4) + (r_i << 5) - (r_i << 2) + c_i;
            end else if (width == 14) begin
                addr_calc = base_i + (ch_i << 7) + (ch_i << 6) + (ch_i << 2) + (r_i << 4) - (r_i << 1) + c_i;
            end else begin
                addr_calc = base_i + (ch_i << 5) + (ch_i << 4) + ch_i + (r_i << 3) - r_i + c_i;
            end
            tensor_addr = addr_calc[15:0];
        end
    endfunction

    function integer kernel_row_offset;
        input [3:0] kernel_index;
        begin
            if (kernel_index < 3) kernel_row_offset = -1;
            else if (kernel_index < 6) kernel_row_offset = 0;
            else kernel_row_offset = 1;
        end
    endfunction

    function integer kernel_col_offset;
        input [3:0] kernel_index;
        begin
            if (kernel_index == 0 || kernel_index == 3 || kernel_index == 6) kernel_col_offset = -1;
            else if (kernel_index == 1 || kernel_index == 4 || kernel_index == 7) kernel_col_offset = 0;
            else kernel_col_offset = 1;
        end
    endfunction

    function [15:0] conv_weight_addr;
        input [2:0] layer;
        input [4:0] out_channel;
        input [4:0] in_channel;
        input [3:0] kernel_index;
        integer addr_calc;
        integer out_i;
        integer in_i;
        integer kernel_i;
        begin
            out_i = {27'd0, out_channel};
            in_i = {27'd0, in_channel};
            kernel_i = {28'd0, kernel_index};
            if (layer == L_CONV1) begin
                addr_calc = (out_i << 3) + out_i + kernel_i;
            end else begin
                addr_calc = (out_i << 6) + (out_i << 4) + (out_i << 3) + (out_i << 1) +
                            (in_i << 3) + in_i + kernel_i;
            end
            conv_weight_addr = addr_calc[15:0];
        end
    endfunction

    function [15:0] fc_weight_addr;
        input [3:0] class_num;
        input [9:0] feature_num;
        integer addr_calc;
        integer class_i;
        integer feature_i;
        begin
            class_i = {28'd0, class_num};
            feature_i = {22'd0, feature_num};
            addr_calc = (class_i << 9) - (class_i << 4) - (class_i << 2) - (class_i << 1) + feature_i;
            fc_weight_addr = addr_calc[15:0];
        end
    endfunction

    function signed [DATA_WIDTH-1:0] relu16;
        input signed [DATA_WIDTH-1:0] value;
        begin
            if (value[DATA_WIDTH-1]) relu16 = {DATA_WIDTH{1'b0}};
            else relu16 = value;
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
            q8_8_product = {{(ACC_WIDTH-(DATA_WIDTH*2)){product[(DATA_WIDTH*2)-1]}}, product} >>> 8;
        end
    endfunction

    function [15:0] conv_read_addr;
        input [2:0] layer;
        input [4:0] ch;
        input integer r;
        input integer c;
        begin
            conv_read_addr = tensor_addr(conv_src_base(layer), ch, r[4:0], c[4:0], conv_width(layer));
        end
    endfunction

    function [15:0] conv_write_addr;
        input [2:0] layer;
        input [4:0] ch;
        input [4:0] r;
        input [4:0] c;
        begin
            conv_write_addr = tensor_addr(conv_dst_base(layer), ch, r, c, conv_width(layer));
        end
    endfunction

    function [15:0] pool_src_addr;
        input [2:0] layer;
        input [4:0] ch;
        input [4:0] r;
        input [4:0] c;
        input [1:0] idx;
        integer src_w;
        integer rr;
        integer cc;
        reg [15:0] base;
        begin
            src_w = conv_width(layer);
            base = (layer == L_CONV2) ? BUF_A : BUF_B;
            rr = (r * 2) + (idx[1] ? 1 : 0);
            cc = (c * 2) + (idx[0] ? 1 : 0);
            pool_src_addr = tensor_addr(base, ch, rr[4:0], cc[4:0], src_w);
        end
    endfunction

    function [15:0] pool_dst_addr;
        input [2:0] layer;
        input [4:0] ch;
        input [4:0] r;
        input [4:0] c;
        reg [15:0] base;
        begin
            base = (layer == L_CONV2) ? BUF_B : BUF_A;
            pool_dst_addr = tensor_addr(base, ch, r, c, conv_width(layer)/2);
        end
    endfunction
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on BLKSEQ */

/* verilator lint_off BLKSEQ */
    task start_bias_preload;
        input [2:0] layer;
        begin
            bias_layer <= layer;
            bias_idx <= 4'd0;
            state <= S_BIAS_PRELOAD_START;
        end
    endtask

    task issue_conv_fetch;
        input [2:0] layer;
        input [4:0] out_channel;
        input [4:0] in_channel;
        input [3:0] kernel_index;
        input [4:0] dst_row;
        input [4:0] dst_col;
        integer rr;
        integer cc;
        begin
            mem_req_valid <= 1'b1;
            mem_req_layer <= layer;
            mem_req_kind <= MEM_KIND_WEIGHT;
            mem_req_addr <= conv_weight_addr(layer, out_channel, in_channel, kernel_index);

            rr = {27'd0, dst_row} + kernel_row_offset(kernel_index);
            cc = {27'd0, dst_col} + kernel_col_offset(kernel_index);
            if (rr < 0 || cc < 0 || rr >= conv_width(layer) || cc >= conv_width(layer)) begin
                act_rd_en <= 1'b0;
                act_rd_addr <= 16'd0;
            end else begin
                act_rd_en <= 1'b1;
                act_rd_addr <= conv_read_addr(layer, in_channel, rr, cc);
            end
        end
    endtask

    task issue_pool_fetch;
        input [2:0] layer;
        input [4:0] channel;
        input [4:0] dst_row;
        input [4:0] dst_col;
        input [1:0] idx;
        begin
            act_rd_en <= 1'b1;
            act_rd_addr <= pool_src_addr(layer, channel, dst_row, dst_col, idx);
        end
    endtask

    task issue_fc_fetch;
        input [3:0] class_num;
        input [9:0] feature_num;
        begin
            mem_req_valid <= 1'b1;
            mem_req_layer <= L_FC;
            mem_req_kind <= MEM_KIND_WEIGHT;
            mem_req_addr <= fc_weight_addr(class_num, feature_num);
            act_rd_en <= 1'b1;
            act_rd_addr <= BUF_A + {6'd0, feature_num};
        end
    endtask
/* verilator lint_on BLKSEQ */

    task advance_conv_position;
        begin
            if (out_ch == 9) begin
                out_ch <= 0;
                if (col == conv_width_last(conv_layer)) begin
                    col <= 0;
                    if (row == conv_width_last(conv_layer)) begin
                        row <= 0;
                        if (conv_layer == L_CONV2 || conv_layer == L_CONV4) begin
                            state <= S_POOL_START;
                        end else begin
                            conv_layer <= conv_layer + 1'b1;
                            start_bias_preload(conv_layer + 1'b1);
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
                if (col == pool_width_last(conv_layer)) begin
                    col <= 0;
                    if (row == pool_width_last(conv_layer)) begin
                        row <= 0;
                        if (conv_layer == L_CONV2) begin
                            conv_layer <= L_CONV3;
                            start_bias_preload(L_CONV3);
                        end else begin
                            start_bias_preload(L_FC);
                        end
                    end else begin
                        row <= row + 1'b1;
                        state <= S_POOL_START;
                    end
                end else begin
                    col <= col + 1'b1;
                    state <= S_POOL_START;
                end
            end else begin
                out_ch <= out_ch + 1'b1;
                state <= S_POOL_START;
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
            pool_idx <= 2'd0;
            bias_idx <= 4'd0;
            bias_layer <= L_CONV1;
            pool_max <= {DATA_WIDTH{1'b0}};
            acc <= {ACC_WIDTH{1'b0}};
            act_rd_en <= 1'b0;
            act_rd_addr <= 16'd0;
            act_wr_en <= 1'b0;
            act_wr_addr <= 16'd0;
            act_wr_data <= 16'd0;
            for (i = 0; i < 10; i = i + 1) begin
                bias_regs[i] <= {DATA_WIDTH{1'b0}};
                scores[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            mem_req_valid <= 1'b0;
            valid_out <= 1'b0;
            last_out <= 1'b0;
            act_rd_en <= 1'b0;
            act_wr_en <= 1'b0;

            case (state)
                S_LOAD: begin
                    ready_out <= 1'b1;
                    if (valid_in) begin
                        act_wr_en <= 1'b1;
                        act_wr_addr <= load_act_addr;
                        act_wr_data <= pixel_in;
                        if (last_in || load_count == 11'd783) begin
                            ready_out <= 1'b0;
                            load_count <= 11'd0;
                            conv_layer <= L_CONV1;
                            out_ch <= 5'd0;
                            in_ch <= 5'd0;
                            k_idx <= 4'd0;
                            row <= 5'd0;
                            col <= 5'd0;
                            state <= S_LOAD_FLUSH;
                        end else begin
                            load_count <= load_count + 1'b1;
                        end
                    end
                end

                S_LOAD_FLUSH: begin
                    start_bias_preload(L_CONV1);
                end


                S_BIAS_PRELOAD_START: begin
                    bias_idx <= 4'd0;
                    state <= S_BIAS_PRELOAD_REQ;
                end

                S_BIAS_PRELOAD_REQ: begin
                    mem_req_valid <= 1'b1;
                    mem_req_layer <= bias_layer;
                    mem_req_kind <= MEM_KIND_BIAS;
                    mem_req_addr <= {12'd0, bias_idx};
                    state <= S_BIAS_PRELOAD_WAIT;
                end

                S_BIAS_PRELOAD_WAIT: begin
                    state <= S_BIAS_PRELOAD_CAP;
                end

                S_BIAS_PRELOAD_CAP: begin
                    bias_regs[bias_idx] <= mem_resp_data;
                    if (bias_idx == 4'd9) begin
                        bias_idx <= 4'd0;
                        if (bias_layer == L_FC) begin
                            state <= S_FC_START;
                        end else begin
                            state <= S_CONV_START;
                        end
                    end else begin
                        bias_idx <= bias_idx + 1'b1;
                        state <= S_BIAS_PRELOAD_REQ;
                    end
                end

                S_CONV_START: begin
/* verilator lint_off BLKSEQ */
                    in_ch <= 5'd0;
                    k_idx <= 4'd0;
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){bias_regs[out_ch[3:0]][DATA_WIDTH-1]}}, bias_regs[out_ch[3:0]]};
                    src_row = {27'd0, row} - 32'd1;
                    src_col = {27'd0, col} - 32'd1;
/* verilator lint_on BLKSEQ */
                    if (src_row < 0 || src_col < 0 || src_row >= conv_width(conv_layer) || src_col >= conv_width(conv_layer)) begin
                        k_idx <= 4'd1;
                        state <= S_CONV_W_REQ;
                    end else begin
                        issue_conv_fetch(conv_layer, out_ch, 0, 0, row, col);
                        state <= S_CONV_W_WAIT;
                    end
                end

                S_CONV_W_REQ: begin
/* verilator lint_off BLKSEQ */
                    src_row = {27'd0, row};
                    src_col = {27'd0, col};
                    src_row = src_row + kernel_row_offset(k_idx);
                    src_col = src_col + kernel_col_offset(k_idx);
/* verilator lint_on BLKSEQ */
                    if (src_row < 0 || src_col < 0 || src_row >= conv_width(conv_layer) || src_col >= conv_width(conv_layer)) begin
                        if (k_idx == 4'd8) begin
                            k_idx <= 4'd0;
                            if (in_ch == conv_in_ch_last(conv_layer)) begin
                                act_wr_en <= 1'b1;
                                act_wr_addr <= conv_write_addr(conv_layer, out_ch, row, col);
                                act_wr_data <= relu16(trunc_acc(acc));
                                in_ch <= 5'd0;
                                advance_conv_position();
                            end else begin
                                in_ch <= in_ch + 5'd1;
                                state <= S_CONV_W_REQ;
                            end
                        end else begin
                            k_idx <= k_idx + 4'd1;
                            state <= S_CONV_W_REQ;
                        end
                    end else begin
                        issue_conv_fetch(conv_layer, out_ch, in_ch, k_idx, row, col);
                        state <= S_CONV_W_WAIT;
                    end
                end

                S_CONV_W_WAIT: begin
                    state <= S_CONV_W_CAP;
                end

                S_CONV_W_CAP: begin
/* verilator lint_off BLKSEQ */
                    src_row = {27'd0, row};
                    src_col = {27'd0, col};
                    src_row = src_row + kernel_row_offset(k_idx);
                    src_col = src_col + kernel_col_offset(k_idx);
/* verilator lint_on BLKSEQ */
                    if (src_row < 0 || src_col < 0 || src_row >= conv_width(conv_layer) || src_col >= conv_width(conv_layer)) begin
                        acc <= acc;
                    end else begin
                        acc <= acc + q8_8_product(act_rd_data, mem_resp_data);
                    end

                    if (k_idx == 4'd8) begin
                        k_idx <= 4'd0;
                        if (in_ch == conv_in_ch_last(conv_layer)) begin
                            act_wr_en <= 1'b1;
                            act_wr_addr <= conv_write_addr(conv_layer, out_ch, row, col);
                            if (src_row < 0 || src_col < 0 || src_row >= conv_width(conv_layer) || src_col >= conv_width(conv_layer)) begin
                                act_wr_data <= relu16(trunc_acc(acc));
                            end else begin
                                act_wr_data <= relu16(trunc_acc(acc + q8_8_product(act_rd_data, mem_resp_data)));
                            end
                            in_ch <= 5'd0;
                            advance_conv_position();
                        end else begin
                            in_ch <= in_ch + 5'd1;
                            issue_conv_fetch(conv_layer, out_ch, in_ch + 5'd1, 4'd0, row, col);
                            state <= S_CONV_W_WAIT;
                        end
                    end else begin
                        k_idx <= k_idx + 4'd1;
                        issue_conv_fetch(conv_layer, out_ch, in_ch, k_idx + 4'd1, row, col);
                        state <= S_CONV_W_WAIT;
                    end
                end

                S_POOL_START: begin
                    pool_idx <= 2'd0;
                    issue_pool_fetch(conv_layer, out_ch, row, col, 2'd0);
                    state <= S_POOL_WAIT;
                end

                S_POOL_REQ: begin
                    issue_pool_fetch(conv_layer, out_ch, row, col, pool_idx);
                    state <= S_POOL_WAIT;
                end

                S_POOL_WAIT: begin
                    state <= S_POOL_CAP;
                end

                S_POOL_CAP: begin
                    if (pool_idx == 2'd0) begin
                        pool_max <= act_rd_data;
                        pool_idx <= 2'd1;
                        issue_pool_fetch(conv_layer, out_ch, row, col, 2'd1);
                        state <= S_POOL_WAIT;
                    end else if (pool_idx == 2'd3) begin
                        act_wr_en <= 1'b1;
                        act_wr_addr <= pool_dst_addr(conv_layer, out_ch, row, col);
                        act_wr_data <= max2(pool_max, act_rd_data);
                        pool_idx <= 2'd0;
                        advance_pool_position();
                    end else begin
                        pool_max <= max2(pool_max, act_rd_data);
                        pool_idx <= pool_idx + 2'd1;
                        issue_pool_fetch(conv_layer, out_ch, row, col, pool_idx + 2'd1);
                        state <= S_POOL_WAIT;
                    end
                end

                S_FC_START: begin
                    fc_class <= 4'd0;
                    feat_idx <= 10'd0;
                    acc <= {{(ACC_WIDTH-DATA_WIDTH){bias_regs[0][DATA_WIDTH-1]}}, bias_regs[0]};
                    issue_fc_fetch(0, 0);
                    state <= S_FC_W_WAIT;
                end

                S_FC_W_REQ: begin
                    issue_fc_fetch(fc_class, feat_idx);
                    state <= S_FC_W_WAIT;
                end

                S_FC_W_WAIT: begin
                    state <= S_FC_W_CAP;
                end

                S_FC_W_CAP: begin
                    acc <= acc + q8_8_product(act_rd_data, mem_resp_data);
                    if (feat_idx == 10'd489) begin
                        scores[fc_class] <= trunc_acc(acc + q8_8_product(act_rd_data, mem_resp_data));
                        feat_idx <= 10'd0;
                        if (fc_class == 4'd9) begin
                            out_idx <= 4'd0;
                            state <= S_OUTPUT;
                        end else begin
                            fc_class <= fc_class + 4'd1;
                            feat_idx <= 10'd0;
                            acc <= {{(ACC_WIDTH-DATA_WIDTH){bias_regs[fc_class + 4'd1][DATA_WIDTH-1]}}, bias_regs[fc_class + 4'd1]};
                            issue_fc_fetch(fc_class + 4'd1, 10'd0);
                            state <= S_FC_W_WAIT;
                        end
                    end else begin
                        feat_idx <= feat_idx + 10'd1;
                        issue_fc_fetch(fc_class, feat_idx + 10'd1);
                        state <= S_FC_W_WAIT;
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
