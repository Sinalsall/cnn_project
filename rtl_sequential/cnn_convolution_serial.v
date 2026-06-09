module cnn_convolution_serial #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    // Handshaking
    input wire valid_in,
    output reg ready_out,
    
    // Data input dari Line Buffer (3x3 Window)
    input wire signed [DATA_WIDTH-1:0] w00, input wire signed [DATA_WIDTH-1:0] w01, input wire signed [DATA_WIDTH-1:0] w02,
    input wire signed [DATA_WIDTH-1:0] w10, input wire signed [DATA_WIDTH-1:0] w11, input wire signed [DATA_WIDTH-1:0] w12,
    input wire signed [DATA_WIDTH-1:0] w20, input wire signed [DATA_WIDTH-1:0] w21, input wire signed [DATA_WIDTH-1:0] w22,
    
    // Streaming Weights dari controller
    input wire signed [DATA_WIDTH-1:0] weight_in,
    input wire signed [DATA_WIDTH-1:0] bias_in,
    output reg [3:0] weight_idx, // Meminta index weight (0 - 8)
    
    // Stream Output
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    // FSM States
    localparam IDLE = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam DONE = 2'd2;
    
    reg [1:0] state;
    
    // Single MAC unit registers
    reg signed [DATA_WIDTH*2-1:0] accumulator;
    reg signed [DATA_WIDTH-1:0] current_pixel;
    
    // Multiplexer untuk memilih pixel berdasarkan cycle/index TDM
    always @(*) begin
        case(weight_idx)
            4'd0: current_pixel = w00;
            4'd1: current_pixel = w01;
            4'd2: current_pixel = w02;
            4'd3: current_pixel = w10;
            4'd4: current_pixel = w11;
            4'd5: current_pixel = w12;
            4'd6: current_pixel = w20;
            4'd7: current_pixel = w21;
            4'd8: current_pixel = w22;
            default: current_pixel = 0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready_out <= 1;
            valid_out <= 0;
            data_out <= 0;
            weight_idx <= 0;
            accumulator <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    weight_idx <= 0;
                    if (valid_in) begin
                        ready_out <= 0; // Berhenti menerima input dari line buffer
                        state <= COMPUTE;
                        accumulator <= bias_in; // Inisialisasi awal dengan bias
                    end
                end
                
                COMPUTE: begin
                    // ---- Time Division Multiplexed MAC (1 Multiplier diputar 9 kali) ----
                    accumulator <= accumulator + (current_pixel * weight_in);
                    
                    if (weight_idx == 4'd8) begin
                        state <= DONE;
                    end else begin
                        weight_idx <= weight_idx + 1;
                    end
                end
                
                DONE: begin
                    // Keluarkan hasil (dengan bit truncation / fixed_point rescale)
                    // Asumsi: Q8.8 format => geser 8 bit untuk kembali ke Q8.8
                    data_out <= accumulator[DATA_WIDTH+7 : 8]; 
                    valid_out <= 1;
                    ready_out <= 1; // Siap menerima pixel window berikutnya
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
