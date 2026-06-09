module cnn_maxpool #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_SIZE = 28,
    parameter POOL_SIZE  = 2
)(
    input clk,
    input rst_n,

    input start,

    input signed [DATA_WIDTH*INPUT_SIZE*INPUT_SIZE-1:0] frame_in,

    output reg busy,
    output reg done,

    output reg signed [DATA_WIDTH*(INPUT_SIZE/POOL_SIZE)*(INPUT_SIZE/POOL_SIZE)-1:0] frame_out
);

    localparam OUTPUT_SIZE  = INPUT_SIZE / POOL_SIZE;
    localparam INPUT_PIXELS = INPUT_SIZE * INPUT_SIZE;
    localparam OUTPUT_PIXELS = OUTPUT_SIZE * OUTPUT_SIZE;

    localparam S_IDLE    = 2'd0;
    localparam S_LOAD    = 2'd1;
    localparam S_COMPUTE = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0] state;

    reg signed [DATA_WIDTH-1:0] input_buffer  [0:INPUT_PIXELS-1];
    reg signed [DATA_WIDTH-1:0] output_buffer [0:OUTPUT_PIXELS-1];

    reg [15:0] load_idx;
    reg [15:0] out_idx;

    reg [15:0] out_row;
    reg [15:0] out_col;

    reg [15:0] base_row;
    reg [15:0] base_col;

    reg [15:0] idx00;
    reg [15:0] idx01;
    reg [15:0] idx10;
    reg [15:0] idx11;

    reg signed [DATA_WIDTH-1:0] p00;
    reg signed [DATA_WIDTH-1:0] p01;
    reg signed [DATA_WIDTH-1:0] p10;
    reg signed [DATA_WIDTH-1:0] p11;

    reg signed [DATA_WIDTH-1:0] max_top;
    reg signed [DATA_WIDTH-1:0] max_bottom;
    reg signed [DATA_WIDTH-1:0] max_all;

    integer i;

    always @(*) begin
        base_row = out_row * POOL_SIZE;
        base_col = out_col * POOL_SIZE;

        idx00 = base_row * INPUT_SIZE + base_col;
        idx01 = idx00 + 1;
        idx10 = (base_row + 1) * INPUT_SIZE + base_col;
        idx11 = idx10 + 1;

        p00 = input_buffer[idx00];
        p01 = input_buffer[idx01];
        p10 = input_buffer[idx10];
        p11 = input_buffer[idx11];

        max_top    = (p00 > p01) ? p00 : p01;
        max_bottom = (p10 > p11) ? p10 : p11;
        max_all    = (max_top > max_bottom) ? max_top : max_bottom;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            busy     <= 1'b0;
            done     <= 1'b0;
            load_idx <= 0;
            out_idx  <= 0;
            out_row  <= 0;
            out_col  <= 0;
            frame_out <= 0;

            for (i = 0; i < INPUT_PIXELS; i = i + 1) begin
                input_buffer[i] <= 0;
            end

            for (i = 0; i < OUTPUT_PIXELS; i = i + 1) begin
                output_buffer[i] <= 0;
            end

        end else begin
            case (state)

                S_IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    load_idx <= 0;
                    out_idx <= 0;
                    out_row <= 0;
                    out_col <= 0;

                    if (start) begin
                        busy <= 1'b1;
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    input_buffer[load_idx] <= frame_in[load_idx*DATA_WIDTH +: DATA_WIDTH];

                    if (load_idx == INPUT_PIXELS - 1) begin
                        load_idx <= 0;
                        out_idx <= 0;
                        out_row <= 0;
                        out_col <= 0;
                        state <= S_COMPUTE;
                    end else begin
                        load_idx <= load_idx + 1'b1;
                    end
                end

                S_COMPUTE: begin
                    output_buffer[out_idx] <= max_all;

                    if (out_col == OUTPUT_SIZE - 1) begin
                        out_col <= 0;

                        if (out_row == OUTPUT_SIZE - 1) begin
                            out_row <= 0;
                        end else begin
                            out_row <= out_row + 1'b1;
                        end
                    end else begin
                        out_col <= out_col + 1'b1;
                    end

                    if (out_idx == OUTPUT_PIXELS - 1) begin
                        out_idx <= 0;
                        state <= S_DONE;
                    end else begin
                        out_idx <= out_idx + 1'b1;
                    end
                end

                S_DONE: begin
                    for (i = 0; i < OUTPUT_PIXELS; i = i + 1) begin
                        frame_out[i*DATA_WIDTH +: DATA_WIDTH] <= output_buffer[i];
                    end

                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end

            endcase
        end
    end

endmodule
