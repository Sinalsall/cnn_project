`timescale 1ns/1ps

module tb_activation_sram_bank;
    reg clk;
    reg rd_en;
    reg [15:0] rd_addr;
    wire [15:0] rd_data;
    reg wr_en;
    reg [15:0] wr_addr;
    reg [15:0] wr_data;
    wire same_bank_conflict;

    integer errors;

    cnn_activation_sram_bank dut (
        .clk(clk),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .same_bank_conflict(same_bank_conflict)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_word;
        input [15:0] addr;
        input [15:0] data;
        begin
            @(negedge clk);
            wr_en = 1'b1;
            wr_addr = addr;
            wr_data = data;
            rd_en = 1'b0;
            @(negedge clk);
            wr_en = 1'b0;
            wr_addr = 16'd0;
            wr_data = 16'd0;
        end
    endtask

    task read_expect;
        input [15:0] addr;
        input [15:0] expected;
        begin
            @(negedge clk);
            rd_en = 1'b1;
            rd_addr = addr;
            wr_en = 1'b0;
            @(negedge clk);
            rd_en = 1'b0;
            @(negedge clk);
            if (rd_data !== expected) begin
                $display("[FAIL] addr=%0d expected=0x%04h got=0x%04h", addr, expected, rd_data);
                errors = errors + 1;
            end else begin
                $display("[OK] addr=%0d data=0x%04h", addr, rd_data);
            end
        end
    endtask

    initial begin
        rd_en = 1'b0;
        rd_addr = 16'd0;
        wr_en = 1'b0;
        wr_addr = 16'd0;
        wr_data = 16'd0;
        errors = 0;

        repeat (3) @(negedge clk);

        write_word(16'd0,     16'h1234);
        write_word(16'd1023,  16'habcd);
        write_word(16'd1024,  16'h55aa);
        write_word(16'd8192,  16'h0f0f);
        write_word(16'd15360, 16'hf00d);

        read_expect(16'd0,     16'h1234);
        read_expect(16'd1023,  16'habcd);
        read_expect(16'd1024,  16'h55aa);
        read_expect(16'd8192,  16'h0f0f);
        read_expect(16'd15360, 16'hf00d);

        @(negedge clk);
        rd_en = 1'b1;
        rd_addr = 16'd1024;
        wr_en = 1'b1;
        wr_addr = 16'd1025;
        wr_data = 16'h1111;
        @(negedge clk);
        if (!same_bank_conflict) begin
            $display("[FAIL] expected same-bank conflict");
            errors = errors + 1;
        end else begin
            $display("[OK] same-bank conflict asserted");
        end
        rd_en = 1'b0;
        wr_en = 1'b0;

        if (errors == 0) begin
            $display("[PASS] activation SRAM bank test passed");
        end else begin
            $display("[FAIL] activation SRAM bank test errors=%0d", errors);
        end

        #20 $finish;
    end
endmodule
