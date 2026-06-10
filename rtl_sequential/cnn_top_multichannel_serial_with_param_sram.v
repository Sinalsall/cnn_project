// ================================================================
// cnn_top_multichannel_serial_with_param_sram.v
// Layout-oriented chip top for the sequential/TDM CNN.
//
// This wrapper keeps cnn_top_multichannel_serial as the compute core,
// instantiates on-chip parameter SRAM, and connects the core's
// mem_req_* interface to that SRAM with fixed 1-cycle read latency.
//
// Parameter SRAM is writable through param_wr_* so a testbench, bus
// wrapper, or boot controller can load weights and biases before
// inference starts.
// ================================================================

module cnn_top_multichannel_serial_with_param_sram #(
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
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    input wire last_in,

    input wire param_wr_en,
    input wire [15:0] param_wr_addr,
    input wire [15:0] param_wr_data,

    output wire valid_out,
    output wire [3:0] class_idx,
    output wire signed [DATA_WIDTH-1:0] score_out,
    output wire last_out
);

    localparam MEM_KIND_BIAS   = 2'd1;

    localparam L_CONV1 = 3'd0;
    localparam L_CONV2 = 3'd1;
    localparam L_CONV3 = 3'd2;
    localparam L_CONV4 = 3'd3;
    localparam L_FC    = 3'd4;

    localparam CONV1_W_BASE = 16'd0;     // 1*10*9
    localparam CONV1_B_BASE = 16'd90;
    localparam CONV2_W_BASE = 16'd100;   // 10*10*9
    localparam CONV2_B_BASE = 16'd1000;
    localparam CONV3_W_BASE = 16'd1010;  // 10*10*9
    localparam CONV3_B_BASE = 16'd1910;
    localparam CONV4_W_BASE = 16'd1920;  // 10*10*9
    localparam CONV4_B_BASE = 16'd2820;
    localparam FC_W_BASE    = 16'd2830;  // 10*490
    localparam FC_B_BASE    = 16'd7730;

    wire        mem_req_valid;
    wire [2:0]  mem_req_layer;
    wire [1:0]  mem_req_kind;
    wire [15:0] mem_req_addr;
    wire signed [DATA_WIDTH-1:0] mem_resp_data;

    reg [15:0] param_rd_addr;

    always @(*) begin
        case (mem_req_layer)
            L_CONV1: param_rd_addr = (mem_req_kind == MEM_KIND_BIAS) ?
                (CONV1_B_BASE + mem_req_addr) : (CONV1_W_BASE + mem_req_addr);
            L_CONV2: param_rd_addr = (mem_req_kind == MEM_KIND_BIAS) ?
                (CONV2_B_BASE + mem_req_addr) : (CONV2_W_BASE + mem_req_addr);
            L_CONV3: param_rd_addr = (mem_req_kind == MEM_KIND_BIAS) ?
                (CONV3_B_BASE + mem_req_addr) : (CONV3_W_BASE + mem_req_addr);
            L_CONV4: param_rd_addr = (mem_req_kind == MEM_KIND_BIAS) ?
                (CONV4_B_BASE + mem_req_addr) : (CONV4_W_BASE + mem_req_addr);
            L_FC: param_rd_addr = (mem_req_kind == MEM_KIND_BIAS) ?
                (FC_B_BASE + mem_req_addr) : (FC_W_BASE + mem_req_addr);
            default: param_rd_addr = 16'd0;
        endcase
    end

    cnn_param_sram_bank u_param_sram (
`ifdef USE_POWER_PINS
        .VDD(VDD),
        .VSS(VSS),
`endif
        .clk(clk),
        .rd_en(mem_req_valid),
        .rd_addr(param_rd_addr),
        .rd_data(mem_resp_data),
        .wr_en(param_wr_en),
        .wr_addr(param_wr_addr),
        .wr_data(param_wr_data)
    );

    cnn_top_multichannel_serial #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_core (
`ifdef USE_POWER_PINS
        .VDD(VDD),
        .VSS(VSS),
`endif
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .last_in(last_in),
        .mem_req_valid(mem_req_valid),
        .mem_req_layer(mem_req_layer),
        .mem_req_kind(mem_req_kind),
        .mem_req_addr(mem_req_addr),
        .mem_resp_data(mem_resp_data),
        .valid_out(valid_out),
        .class_idx(class_idx),
        .score_out(score_out),
        .last_out(last_out)
    );

endmodule
