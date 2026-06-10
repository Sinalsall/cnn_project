// ================================================================
// cnn_param_sram_bank.v
// Parameter SRAM subsystem for CNN weights and biases.
//
// Capacity: 8 banks * 1024 words * 16 bits = 8192 16-bit words.
// Implementation: each 1024x16 bank is two gf180mcu 1024x8 macros.
//
// Address map is global 16-bit word addresses. The top three bits of
// addr[12:10] select the bank and addr[9:0] selects the word in bank.
// ================================================================

module cnn_param_sram_bank #(
    parameter NUM_BANKS = 8
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
    input wire [15:0] wr_data
);

    wire [2:0] rd_bank = rd_addr[12:10];
    wire [2:0] wr_bank = wr_addr[12:10];
    wire [9:0] sram_addr = wr_en ? wr_addr[9:0] : rd_addr[9:0];
    wire unused_addr_bits = |{rd_addr[15:13], wr_addr[15:13]};

    wire [15:0] bank_rdata [0:NUM_BANKS-1];

    genvar b;
    generate
        for (b = 0; b < NUM_BANKS; b = b + 1) begin : g_bank
            wire bank_wr = wr_en && (wr_bank == b[2:0]);
            wire bank_rd = rd_en && (rd_bank == b[2:0]);
            wire bank_en = bank_wr || bank_rd;

            sram16_1024_wrapper u_bank (
`ifdef USE_POWER_PINS
                .VDD(VDD),
                .VSS(VSS),
`endif
                .clk(clk),
                .cen(bank_en),
                .wen(bank_wr),
                .addr(sram_addr),
                .wdata(wr_data),
                .rdata(bank_rdata[b])
            );
        end
    endgenerate

    assign rd_data =
        (rd_bank == 3'd0) ? bank_rdata[0] :
        (rd_bank == 3'd1) ? bank_rdata[1] :
        (rd_bank == 3'd2) ? bank_rdata[2] :
        (rd_bank == 3'd3) ? bank_rdata[3] :
        (rd_bank == 3'd4) ? bank_rdata[4] :
        (rd_bank == 3'd5) ? bank_rdata[5] :
        (rd_bank == 3'd6) ? bank_rdata[6] :
                            bank_rdata[7];

    wire _unused_ok = unused_addr_bits;

endmodule
