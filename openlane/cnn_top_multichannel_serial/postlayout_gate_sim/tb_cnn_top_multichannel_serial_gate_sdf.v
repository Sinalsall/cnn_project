`timescale 1ns/1ps

module tb_cnn_top_multichannel_serial_gate_sdf;
    localparam DATA_WIDTH = 16;

    localparam BASE_CONV1_W = 16'd0;
    localparam BASE_CONV1_B = 16'd90;
    localparam BASE_CONV2_W = 16'd100;
    localparam BASE_CONV2_B = 16'd1000;
    localparam BASE_CONV3_W = 16'd1010;
    localparam BASE_CONV3_B = 16'd1910;
    localparam BASE_CONV4_W = 16'd1920;
    localparam BASE_CONV4_B = 16'd2820;
    localparam BASE_FC_W    = 16'd2830;
    localparam BASE_FC_B    = 16'd7730;

    reg clk;
    reg rst_n;
    reg valid_in;
    wire ready_out;
    reg signed [DATA_WIDTH-1:0] pixel_in;
    reg last_in;
    reg param_wr_en;
    reg [15:0] param_wr_addr;
    reg [15:0] param_wr_data;

    wire valid_out;
    wire [3:0] class_idx;
    wire signed [DATA_WIDTH-1:0] score_out;
    wire last_out;

    reg signed [15:0] image_mem [0:783];
    reg signed [15:0] conv1_w [0:89];
    reg signed [15:0] conv1_b [0:9];
    reg signed [15:0] conv2_w [0:899];
    reg signed [15:0] conv2_b [0:9];
    reg signed [15:0] conv3_w [0:899];
    reg signed [15:0] conv3_b [0:9];
    reg signed [15:0] conv4_w [0:899];
    reg signed [15:0] conv4_b [0:9];
    reg signed [15:0] fc_w [0:4899];
    reg signed [15:0] fc_b [0:9];
    reg signed [15:0] got_scores [0:9];

    integer i;
    integer cycles;
    integer best_class;
    reg signed [15:0] best_score;

    cnn_top_multichannel_serial_with_param_sram dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .last_in(last_in),
        .param_wr_en(param_wr_en),
        .param_wr_addr(param_wr_addr),
        .param_wr_data(param_wr_data),
        .valid_out(valid_out),
        .class_idx(class_idx),
        .score_out(score_out),
        .last_out(last_out)
    );

    initial begin
        clk = 1'b0;
        forever #50 clk = ~clk;
    end

    initial begin
        if ($test$plusargs("SDF")) begin
            $display("[TB] Annotating SDF...");
            $sdf_annotate(
                "openlane/cnn_top_multichannel_serial/runs/wrapper_academic_final/final/sdf/nom_tt_025C_5v00/cnn_top_multichannel_serial_with_param_sram__nom_tt_025C_5v00.sdf",
                dut
            );
        end
    end

    task write_param_word;
        input [15:0] addr;
        input [15:0] data;
        begin
            @(negedge clk);
            param_wr_en <= 1'b1;
            param_wr_addr <= addr;
            param_wr_data <= data;
            @(negedge clk);
            param_wr_en <= 1'b0;
            param_wr_addr <= 16'd0;
            param_wr_data <= 16'd0;
        end
    endtask

    task preload_param_sram;
        begin
            $display("[TB] Preloading CNN parameters through wrapper ports...");

            for (i = 0; i < 90; i = i + 1) write_param_word(BASE_CONV1_W + i, conv1_w[i]);
            for (i = 0; i < 10; i = i + 1) write_param_word(BASE_CONV1_B + i, conv1_b[i]);

            for (i = 0; i < 900; i = i + 1) write_param_word(BASE_CONV2_W + i, conv2_w[i]);
            for (i = 0; i < 10; i = i + 1) write_param_word(BASE_CONV2_B + i, conv2_b[i]);

            for (i = 0; i < 900; i = i + 1) write_param_word(BASE_CONV3_W + i, conv3_w[i]);
            for (i = 0; i < 10; i = i + 1) write_param_word(BASE_CONV3_B + i, conv3_b[i]);

            for (i = 0; i < 900; i = i + 1) write_param_word(BASE_CONV4_W + i, conv4_w[i]);
            for (i = 0; i < 10; i = i + 1) write_param_word(BASE_CONV4_B + i, conv4_b[i]);

            for (i = 0; i < 4900; i = i + 1) write_param_word(BASE_FC_W + i, fc_w[i]);
            for (i = 0; i < 10; i = i + 1) write_param_word(BASE_FC_B + i, fc_b[i]);

            $display("[TB] Parameter preload done. Last used word address = %0d", BASE_FC_B + 9);
        end
    endtask

    task send_image;
        begin
            for (i = 0; i < 784; i = i + 1) begin
                @(posedge clk);
                while (!ready_out) @(posedge clk);
                valid_in <= 1'b1;
                pixel_in <= image_mem[i];
                last_in <= (i == 783);
            end
            @(posedge clk);
            valid_in <= 1'b0;
            last_in <= 1'b0;
            pixel_in <= 16'sd0;
        end
    endtask

    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $dumpfile("openlane/cnn_top_multichannel_serial/postlayout_gate_sim/tb_gate_sdf.vcd");
            $dumpvars(0, tb_cnn_top_multichannel_serial_gate_sdf);
        end

        $display("=== CNN GATE+SDF TB START ===");
        $readmemh("generated_hex/mnist_sample_hex.txt", image_mem);
        $readmemh("generated_hex/conv1_weights_hex.txt", conv1_w);
        $readmemh("generated_hex/conv1_bias_hex.txt", conv1_b);
        $readmemh("generated_hex/conv2_weights_hex.txt", conv2_w);
        $readmemh("generated_hex/conv2_bias_hex.txt", conv2_b);
        $readmemh("generated_hex/conv3_weights_hex.txt", conv3_w);
        $readmemh("generated_hex/conv3_bias_hex.txt", conv3_b);
        $readmemh("generated_hex/conv4_weights_hex.txt", conv4_w);
        $readmemh("generated_hex/conv4_bias_hex.txt", conv4_b);
        $readmemh("generated_hex/fc_weights_hex.txt", fc_w);
        $readmemh("generated_hex/fc_bias_hex.txt", fc_b);

        rst_n = 1'b0;
        valid_in = 1'b0;
        pixel_in = 16'sd0;
        last_in = 1'b0;
        param_wr_en = 1'b0;
        param_wr_addr = 16'd0;
        param_wr_data = 16'd0;
        cycles = 0;
        best_class = 0;
        best_score = -32768;
        for (i = 0; i < 10; i = i + 1) got_scores[i] = 16'sd0;

        repeat (5) @(posedge clk);
        preload_param_sram();
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        if ($test$plusargs("SMOKE_ONLY")) begin
            $display("[PASS] Gate-level SDF smoke reached post-reset state. ready_out=%b valid_out=%b last_out=%b", ready_out, valid_out, last_out);
            #200 $finish;
        end

        send_image();

        while (!last_out && cycles < 5000000) begin
            @(posedge clk);
            cycles = cycles + 1;
            if (valid_out) begin
                got_scores[class_idx] = score_out;
                $display("class_scores[%0d] = 0x%04h signed=%0d", class_idx, score_out[15:0], score_out);
                if (score_out > best_score) begin
                    best_score = score_out;
                    best_class = class_idx;
                end
            end
        end

        if (!last_out) begin
            $display("[FAIL] Timeout waiting for last_out after %0d cycles", cycles);
            $finish;
        end

        $display("valid_out received after %0d cycles", cycles);
        $display("predicted_class = %0d, best_score = %0d / 0x%04h", best_class, best_score, best_score[15:0]);
        $display("=== CNN GATE+SDF TB DONE ===");
        #200 $finish;
    end
endmodule
