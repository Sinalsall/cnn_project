// ================================================================
// cnn_fc_bias_sram_wrapper.v
// Thin wrapper around gf180mcu_ocd_ip_sram__sram256x8m8wm1.
//
// Purpose in this project:
//   Store FC bias bytes as proof-of-concept SRAM-backed parameter storage.
//   10 bias values x 16-bit = 20 bytes.
//
// Byte layout recommendation:
//   address 2*i     = bias[i][7:0]   // low byte
//   address 2*i + 1 = bias[i][15:8]  // high byte
// ================================================================

module cnn_fc_bias_sram_wrapper (
    input clk,
    input rst_n,

    // External access port. Use this before starting inference.
    input        ext_en,
    input        ext_we,
    input  [7:0] ext_addr,
    input  [7:0] ext_wdata,
    output [7:0] ext_rdata,

    // Internal read port used by cnn_top before fully-connected stage.
    input        int_rd_en,
    input  [7:0] int_addr,
    output [7:0] int_rdata
);

    wire [7:0] sram_q;

    wire access_en = ext_en | int_rd_en;

    wire [7:0] sram_a = int_rd_en ? int_addr  : ext_addr;
    wire [7:0] sram_d = int_rd_en ? 8'h00     : ext_wdata;

    // Active-low SRAM controls.
    // Keep CEN high during reset so the simulation model sees a falling CEN later.
    wire sram_cen  = rst_n ? ~access_en : 1'b1;
    wire sram_gwen = int_rd_en ? 1'b1 : (ext_we ? 1'b0 : 1'b1);
    wire [7:0] sram_wen = (!int_rd_en && ext_we) ? 8'h00 : 8'hff;

    gf180mcu_ocd_ip_sram__sram256x8m8wm1 u_fc_bias_sram (
        .CLK(clk),
        .CEN(sram_cen),
        .GWEN(sram_gwen),
        .WEN(sram_wen),
        .A(sram_a),
        .D(sram_d),
        .Q(sram_q)
    );

    assign ext_rdata = sram_q;
    assign int_rdata = sram_q;

endmodule
