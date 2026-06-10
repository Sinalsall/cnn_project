// ================================================================
// cnn_activation_sram_bank.v
// Activation SRAM subsystem for sequential CNN feature maps.
//
// Default capacity:
//   16 banks * 1024 words * 16 bits = 16384 activation words.
//
// Each 1024x16 bank is implemented by sram16_1024_wrapper, which maps
// to two gf180mcu_ocd_ip_sram__sram1024x8m8wm1 macros outside
// FAST_SRAM_SIM.
//
// Logical interface:
//   - one read request
//   - one write request
//   - read latency follows the wrapped SRAM model, normally 1 cycle
//
// Scheduling rule:
//   - read and write may happen in the same cycle only if they target
//     different banks. If both target the same bank, write wins and
//     same_bank_conflict is asserted.
// ================================================================

module cnn_activation_sram_bank #(
    parameter NUM_BANKS = 16
)(
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif
    input wire clk,

    input wire rd_en,
    input wire [15:0] rd_addr,
    output wire [15:0] rd_data,

    input wire wr_en,
    input wire [15:0] wr_addr,
    input wire [15:0] wr_data,

    output wire same_bank_conflict
);

    wire [3:0] rd_bank = rd_addr[13:10];
    wire [3:0] wr_bank = wr_addr[13:10];
    wire [9:0] rd_word = rd_addr[9:0];
    wire [9:0] wr_word = wr_addr[9:0];
    wire unused_addr_bits = |{rd_addr[15:14], wr_addr[15:14]};

    assign same_bank_conflict = rd_en && wr_en && (rd_bank == wr_bank);

    wire [15:0] bank_rdata [0:NUM_BANKS-1];

    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : g_bank
            wire bank_wr = wr_en && (wr_bank == b[3:0]);
            wire bank_rd = rd_en && (rd_bank == b[3:0]) && !bank_wr;
            wire bank_en = bank_wr || bank_rd;
            wire [9:0] bank_addr = bank_wr ? wr_word : rd_word;

            sram16_1024_wrapper u_bank (
`ifdef USE_POWER_PINS
                .VDD(VDD),
                .VSS(VSS),
`endif
                .clk(clk),
                .cen(bank_en),
                .wen(bank_wr),
                .addr(bank_addr),
                .wdata(wr_data),
                .rdata(bank_rdata[b])
            );
        end
    endgenerate

    assign rd_data =
        (rd_bank == 4'd0)  ? bank_rdata[0]  :
        (rd_bank == 4'd1)  ? bank_rdata[1]  :
        (rd_bank == 4'd2)  ? bank_rdata[2]  :
        (rd_bank == 4'd3)  ? bank_rdata[3]  :
        (rd_bank == 4'd4)  ? bank_rdata[4]  :
        (rd_bank == 4'd5)  ? bank_rdata[5]  :
        (rd_bank == 4'd6)  ? bank_rdata[6]  :
        (rd_bank == 4'd7)  ? bank_rdata[7]  :
        (rd_bank == 4'd8)  ? bank_rdata[8]  :
        (rd_bank == 4'd9)  ? bank_rdata[9]  :
        (rd_bank == 4'd10) ? bank_rdata[10] :
        (rd_bank == 4'd11) ? bank_rdata[11] :
        (rd_bank == 4'd12) ? bank_rdata[12] :
        (rd_bank == 4'd13) ? bank_rdata[13] :
        (rd_bank == 4'd14) ? bank_rdata[14] :
                              bank_rdata[15];

    wire _unused_ok = unused_addr_bits;

endmodule
