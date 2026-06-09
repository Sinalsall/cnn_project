// ================================================================
// sram16_1024_wrapper.v
// 16-bit word wrapper built from two gf180mcu_ocd_ip_sram 1024x8
// macros. The low byte is stored in one macro and the high byte in
// the other macro.
// ================================================================

module sram16_1024_wrapper (
    input wire clk,
    input wire cen,
    input wire wen,
    input wire [9:0] addr,
    input wire [15:0] wdata,
    output wire [15:0] rdata
);

`ifdef FAST_SRAM_SIM
    reg [15:0] mem [0:1023];
    reg [15:0] q_reg;

    always @(posedge clk) begin
        if (cen) begin
            if (wen) begin
                mem[addr] <= wdata;
            end else begin
                q_reg <= mem[addr];
            end
        end
    end

    assign rdata = q_reg;
`else
    wire [7:0] q_lo;
    wire [7:0] q_hi;

    gf180mcu_ocd_ip_sram__sram1024x8m8wm1 u_sram_lo (
        .CLK(clk),
        .CEN(~cen),
        .GWEN(~wen),
        .WEN(8'h00),
        .A(addr),
        .D(wdata[7:0]),
        .Q(q_lo)
    );

    gf180mcu_ocd_ip_sram__sram1024x8m8wm1 u_sram_hi (
        .CLK(clk),
        .CEN(~cen),
        .GWEN(~wen),
        .WEN(8'h00),
        .A(addr),
        .D(wdata[15:8]),
        .Q(q_hi)
    );

    assign rdata = {q_hi, q_lo};
`endif

endmodule
