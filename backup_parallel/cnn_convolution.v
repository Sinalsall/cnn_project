module cnn_convolution_final #(
    parameter DATA_WIDTH = 8,
    parameter OUT_WIDTH  = 32,
    parameter IMG_SIZE   = 28
)(
    input clk,
    input rst_n,
    input start,  // start frame

    input [(IMG_SIZE*IMG_SIZE*DATA_WIDTH)-1:0] feature_map_in, // paralel frame input

    // Kernel 3x3
    input signed [DATA_WIDTH-1:0] kernel_0, kernel_1, kernel_2,
    input signed [DATA_WIDTH-1:0] kernel_3, kernel_4, kernel_5,
    input signed [DATA_WIDTH-1:0] kernel_6, kernel_7, kernel_8,
    input signed [DATA_WIDTH-1:0] bias,

    output reg busy,
    output reg done,
    output reg [(IMG_SIZE*IMG_SIZE*OUT_WIDTH)-1:0] feature_map_out
);

    localparam TOTAL_PIXELS  = IMG_SIZE*IMG_SIZE;

    reg signed [DATA_WIDTH-1:0]  input_buffer [0:TOTAL_PIXELS-1];
    reg signed [OUT_WIDTH-1:0]   output_buffer [0:TOTAL_PIXELS-1];

    localparam S_IDLE    = 2'd0;
    localparam S_LOAD    = 2'd1;
    localparam S_COMPUTE = 2'd2;
    localparam S_DONE    = 2'd3;
    reg [1:0] state;

    integer i;
    reg [15:0] row, col;
    reg signed [DATA_WIDTH-1:0] p0,p1,p2,p3,p4,p5,p6,p7,p8;
    reg signed [OUT_WIDTH-1:0] mac_sum;

    // =========================
    // Window 3x3 multiplexer
    // =========================
    always @(*) begin
        p0 = 0; p1 = 0; p2 = 0;
        p3 = 0; p4 = 0; p5 = 0;
        p6 = 0; p7 = 0; p8 = 0;

        if (state == S_COMPUTE) begin
            if (row > 0 && col > 0)                   p0 = input_buffer[(row-1)*IMG_SIZE + (col-1)];
            if (row > 0)                              p1 = input_buffer[(row-1)*IMG_SIZE + col];
            if (row > 0 && col < IMG_SIZE-1)          p2 = input_buffer[(row-1)*IMG_SIZE + (col+1)];

            if (col > 0)                              p3 = input_buffer[row*IMG_SIZE + (col-1)];
                                                       p4 = input_buffer[row*IMG_SIZE + col];
            if (col < IMG_SIZE-1)                     p5 = input_buffer[row*IMG_SIZE + (col+1)];

            if (row < IMG_SIZE-1 && col > 0)          p6 = input_buffer[(row+1)*IMG_SIZE + (col-1)];
            if (row < IMG_SIZE-1)                     p7 = input_buffer[(row+1)*IMG_SIZE + col];
            if (row < IMG_SIZE-1 && col < IMG_SIZE-1) p8 = input_buffer[(row+1)*IMG_SIZE + (col+1)];
        end
    end

    // =========================
    // MAC
    // =========================
    always @(*) begin
        mac_sum = (p0*kernel_0) + (p1*kernel_1) + (p2*kernel_2) +
                  (p3*kernel_3) + (p4*kernel_4) + (p5*kernel_5) +
                  (p6*kernel_6) + (p7*kernel_7) + (p8*kernel_8) + bias;
    end

    // =========================
    // FSM
    // =========================
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy <= 0;
            done <= 0;
            feature_map_out <= 0;
            row <= 0; col <= 0;
            for (i=0;i<TOTAL_PIXELS;i=i+1) begin
                input_buffer[i] <= 0;
                output_buffer[i] <= 0;
            end
        end else begin
            case(state)
                S_IDLE: begin
                    busy <= 0;
                    done <= 0;
                    if (start) state <= S_LOAD;
                end

                S_LOAD: begin
                    busy <= 1;
                    for (i=0;i<TOTAL_PIXELS;i=i+1)
                        input_buffer[i] <= feature_map_in[i*DATA_WIDTH +: DATA_WIDTH];
                    row <= 0; col <= 0;
                    state <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    output_buffer[row*IMG_SIZE + col] <= mac_sum;
                    // Update cursor
                    if (col == IMG_SIZE-1) begin
                        col <= 0;
                        if (row == IMG_SIZE-1)
                            state <= S_DONE;
                        else
                            row <= row + 1;
                    end else begin
                        col <= col + 1;
                    end
                end

                S_DONE: begin
                    for (i=0;i<TOTAL_PIXELS;i=i+1)
                        feature_map_out[i*OUT_WIDTH +: OUT_WIDTH] <= output_buffer[i];
                    busy <= 0;
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
