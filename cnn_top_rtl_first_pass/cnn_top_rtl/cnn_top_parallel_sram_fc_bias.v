// ================================================================
// cnn_top_parallel_sram_fc_bias.v
// First-pass top-level CNN integration, parallel-bus version.
//
// Architecture:
//   Input 1x28x28
//   Conv1 1->10, ReLU, Conv2 10->10, ReLU, MaxPool 28->14
//   Conv3 10->10, ReLU, Conv4 10->10, ReLU, MaxPool 14->7
//   Flatten 10*7*7=490
//   Fully Connected 490->10
//
// Design choices for this first-pass RTL:
//   - Parallel input image bus.
//   - Activations are 16-bit.
//   - Convolution and FC weights are top-level input buses for now.
//   - FC bias is loaded from gf180mcu_ocd_ip_sram__sram256x8m8wm1.
//
// WARNING:
//   This is a structural/functional bring-up top-level. It is not yet
//   optimized for area/timing. It must be verified against a Python/PyTorch
//   golden model before being treated as numerically correct.
// ================================================================

module cnn_top_parallel_sram_fc_bias #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 40
)(
    input clk,
    input rst_n,
    input start,

    // Input image: 1 channel, 28x28, 16-bit per pixel.
    input signed [(28*28*DATA_WIDTH)-1:0] image_in,

    // Convolution parameters as parallel buses.
    input signed [(10*1*9*DATA_WIDTH)-1:0]   conv1_weights,
    input signed [(10*DATA_WIDTH)-1:0]       conv1_bias,

    input signed [(10*10*9*DATA_WIDTH)-1:0]  conv2_weights,
    input signed [(10*DATA_WIDTH)-1:0]       conv2_bias,

    input signed [(10*10*9*DATA_WIDTH)-1:0]  conv3_weights,
    input signed [(10*DATA_WIDTH)-1:0]       conv3_bias,

    input signed [(10*10*9*DATA_WIDTH)-1:0]  conv4_weights,
    input signed [(10*DATA_WIDTH)-1:0]       conv4_bias,

    // FC weights remain a top-level bus for this first pass.
    input signed [(10*490*DATA_WIDTH)-1:0]   fc_weights,

    // External FC-bias SRAM programming port.
    // Recommended byte layout:
    //   addr 2*i     = bias[i][7:0]
    //   addr 2*i + 1 = bias[i][15:8]
    input        fc_bias_sram_en,
    input        fc_bias_sram_we,
    input  [7:0] fc_bias_sram_addr,
    input  [7:0] fc_bias_sram_wdata,
    output [7:0] fc_bias_sram_rdata,

    output busy,
    output valid_out,
    output signed [(10*DATA_WIDTH)-1:0] class_scores
);

    localparam S_IDLE           = 3'd0;
    localparam S_READ_BIAS_ADDR = 3'd1;
    localparam S_READ_BIAS_CAP  = 3'd2;
    localparam S_RUN            = 3'd3;

    reg [2:0] state;
    reg [5:0] bias_byte_idx;
    reg [7:0] bias_sram_int_addr;
    reg       bias_sram_int_rd_en;
    wire [7:0] bias_sram_int_rdata;
    reg signed [(10*DATA_WIDTH)-1:0] fc_bias_bus;
    reg conv1_start;

    assign busy = (state != S_IDLE) || conv1_start;

    cnn_fc_bias_sram_wrapper u_fc_bias_sram_wrap (
        .clk(clk),
        .rst_n(rst_n),
        .ext_en(fc_bias_sram_en),
        .ext_we(fc_bias_sram_we),
        .ext_addr(fc_bias_sram_addr),
        .ext_wdata(fc_bias_sram_wdata),
        .ext_rdata(fc_bias_sram_rdata),
        .int_rd_en(bias_sram_int_rd_en),
        .int_addr(bias_sram_int_addr),
        .int_rdata(bias_sram_int_rdata)
    );

    // Bias pre-load FSM. Reads 20 bytes from SRAM before launching CNN.
    // This assumes SRAM read data is available after the addressed clock edge.
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            bias_byte_idx <= 0;
            bias_sram_int_addr <= 0;
            bias_sram_int_rd_en <= 1'b0;
            fc_bias_bus <= 0;
            conv1_start <= 1'b0;
        end else begin
            conv1_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    bias_sram_int_rd_en <= 1'b0;
                    if (start) begin
                        bias_byte_idx <= 0;
                        bias_sram_int_addr <= 0;
                        bias_sram_int_rd_en <= 1'b1;
                        state <= S_READ_BIAS_ADDR;
                    end
                end

                S_READ_BIAS_ADDR: begin
                    // Address has been presented; capture Q in next state.
                    bias_sram_int_rd_en <= 1'b1;
                    state <= S_READ_BIAS_CAP;
                end

                S_READ_BIAS_CAP: begin
                    fc_bias_bus[bias_byte_idx*8 +: 8] <= bias_sram_int_rdata;

                    if (bias_byte_idx == 6'd19) begin
                        bias_sram_int_rd_en <= 1'b0;
                        conv1_start <= 1'b1;
                        state <= S_RUN;
                    end else begin
                        bias_byte_idx <= bias_byte_idx + 1'b1;
                        bias_sram_int_addr <= bias_byte_idx + 1'b1;
                        bias_sram_int_rd_en <= 1'b1;
                        state <= S_READ_BIAS_ADDR;
                    end
                end

                S_RUN: begin
                    // The pipeline itself is event-driven by valid/done pulses.
                    // Return to idle when FC result becomes valid.
                    if (valid_out) begin
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    bias_sram_int_rd_en <= 1'b0;
                end
            endcase
        end
    end

    // -------------------- Layer wires --------------------
    wire conv1_valid;
    wire signed [(10*28*28*DATA_WIDTH)-1:0] conv1_out;
    wire relu1_valid;
    wire signed [(10*28*28*DATA_WIDTH)-1:0] relu1_out;

    wire conv2_valid;
    wire signed [(10*28*28*DATA_WIDTH)-1:0] conv2_out;
    wire relu2_valid;
    wire signed [(10*28*28*DATA_WIDTH)-1:0] relu2_out;

    wire pool1_busy;
    wire pool1_done;
    wire signed [(10*14*14*DATA_WIDTH)-1:0] pool1_out;

    wire conv3_valid;
    wire signed [(10*14*14*DATA_WIDTH)-1:0] conv3_out;
    wire relu3_valid;
    wire signed [(10*14*14*DATA_WIDTH)-1:0] relu3_out;

    wire conv4_valid;
    wire signed [(10*14*14*DATA_WIDTH)-1:0] conv4_out;
    wire relu4_valid;
    wire signed [(10*14*14*DATA_WIDTH)-1:0] relu4_out;

    wire pool2_busy;
    wire pool2_done;
    wire signed [(10*7*7*DATA_WIDTH)-1:0] pool2_out;

    // Flatten is wiring only: 10*7*7 = 490.
    wire signed [(490*DATA_WIDTH)-1:0] flatten_vector;
    assign flatten_vector = pool2_out;

    // -------------------- CNN pipeline --------------------
    cnn_conv_multi_channel_parallel #(
        .DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .IMG_SIZE(28), .IN_CH(1), .OUT_CH(10)
    ) u_conv1 (
        .clk(clk), .rst_n(rst_n), .valid_in(conv1_start),
        .feature_map_in(image_in),
        .weights(conv1_weights), .bias(conv1_bias),
        .valid_out(conv1_valid), .feature_map_out(conv1_out)
    );

    cnn_multi_channel_relu #(
        .DATA_WIDTH(DATA_WIDTH), .IMG_SIZE(28), .CH(10)
    ) u_relu1 (
        .clk(clk), .rst_n(rst_n), .valid_in(conv1_valid),
        .feature_map_in(conv1_out),
        .valid_out(relu1_valid), .feature_map_out(relu1_out)
    );

    cnn_conv_multi_channel_parallel #(
        .DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .IMG_SIZE(28), .IN_CH(10), .OUT_CH(10)
    ) u_conv2 (
        .clk(clk), .rst_n(rst_n), .valid_in(relu1_valid),
        .feature_map_in(relu1_out),
        .weights(conv2_weights), .bias(conv2_bias),
        .valid_out(conv2_valid), .feature_map_out(conv2_out)
    );

    cnn_multi_channel_relu #(
        .DATA_WIDTH(DATA_WIDTH), .IMG_SIZE(28), .CH(10)
    ) u_relu2 (
        .clk(clk), .rst_n(rst_n), .valid_in(conv2_valid),
        .feature_map_in(conv2_out),
        .valid_out(relu2_valid), .feature_map_out(relu2_out)
    );

    cnn_multi_channel_maxpool #(
        .DATA_WIDTH(DATA_WIDTH), .INPUT_SIZE(28), .CH(10)
    ) u_pool1 (
        .clk(clk), 
        .rst_n(rst_n), 
        .valid_in(relu2_valid),
        .feature_map_in(relu2_out),
        .valid_out(pool1_done),
        .feature_map_out(pool1_out)
        
    );

    cnn_conv_multi_channel_parallel #(
        .DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .IMG_SIZE(14), .IN_CH(10), .OUT_CH(10)
    ) u_conv3 (
        .clk(clk), .rst_n(rst_n), .valid_in(pool1_done),
        .feature_map_in(pool1_out),
        .weights(conv3_weights), .bias(conv3_bias),
        .valid_out(conv3_valid), .feature_map_out(conv3_out)
    );

    cnn_multi_channel_relu #(
        .DATA_WIDTH(DATA_WIDTH), .IMG_SIZE(14), .CH(10)
    ) u_relu3 (
        .clk(clk), .rst_n(rst_n), .valid_in(conv3_valid),
        .feature_map_in(conv3_out),
        .valid_out(relu3_valid), .feature_map_out(relu3_out)
    );

    cnn_conv_multi_channel_parallel #(
        .DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
        .IMG_SIZE(14), .IN_CH(10), .OUT_CH(10)
    ) u_conv4 (
        .clk(clk), .rst_n(rst_n), .valid_in(relu3_valid),
        .feature_map_in(relu3_out),
        .weights(conv4_weights), .bias(conv4_bias),
        .valid_out(conv4_valid), .feature_map_out(conv4_out)
    );

    cnn_multi_channel_relu #(
        .DATA_WIDTH(DATA_WIDTH), .IMG_SIZE(14), .CH(10)
    ) u_relu4 (
        .clk(clk), .rst_n(rst_n), .valid_in(conv4_valid),
        .feature_map_in(conv4_out),
        .valid_out(relu4_valid), .feature_map_out(relu4_out)
    );

    cnn_multi_channel_maxpool #(
        .DATA_WIDTH(DATA_WIDTH), .INPUT_SIZE(14), .CH(10)
    ) u_pool2 (
        .clk(clk), 
        .rst_n(rst_n), 
        .valid_in(relu4_valid),
        .feature_map_in(relu4_out),
        .valid_out(pool2_done),
        .feature_map_out(pool2_out)
    );

    cnn_fully_connected #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_DIM(490),
        .OUTPUT_DIM(10)
    ) u_fc (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(pool2_done),
        .input_vector(flatten_vector),
        .weights(fc_weights),
        .bias(fc_bias_bus),
        .valid_out(valid_out),
        .output_vector(class_scores)
    );

endmodule
