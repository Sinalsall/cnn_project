// ==========================================
// Module: Fully Connected Layer (Verilog Compatible - Fixed)
// ==========================================

module cnn_fully_connected #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_DIM = 490,  // <--- DIUBAH KE 490 UNTUK DATASET BARU
    parameter OUTPUT_DIM = 10   // 10 classes for MNIST
)(
    input clk,
    input rst_n,
    input valid_in,
    input [DATA_WIDTH*INPUT_DIM-1:0] input_vector,
    input [DATA_WIDTH*INPUT_DIM*OUTPUT_DIM-1:0] weights,
    input [DATA_WIDTH*OUTPUT_DIM-1:0] bias,
    output valid_out,
    output [DATA_WIDTH*OUTPUT_DIM-1:0] output_vector
);

    // Internal registers for computation
    reg signed [31:0] accumulator [0:OUTPUT_DIM-1];
    reg signed [DATA_WIDTH-1:0] output_hold [0:OUTPUT_DIM-1];
    reg valid_out_reg;
    integer i, j;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out_reg <= 0;
            for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
                accumulator[i] <= 0;
                output_hold[i] <= 0;
            end
        end else if (valid_in) begin
            // Compute matrix multiplication: output = input * weight + bias
            for (i = 0; i < OUTPUT_DIM; i = i + 1) begin
                // FIX BUG 1: Gunakan $signed() agar nilai bias negatif tidak rusak (sign-extension)
                accumulator[i] = $signed(bias[16*(i+1)-1-:16]);
                
                
		for (j = 0; j < INPUT_DIM; j = j + 1) begin
    		    accumulator[i] = accumulator[i] +
        		(($signed(input_vector[16*(j+1)-1-:16]) *
          		  $signed(weights[16*(i*INPUT_DIM + j + 1)-1-:16])) >>> 8);
                end
                // Store result
                output_hold[i] <= accumulator[i][DATA_WIDTH-1:0];
            end
            // Set valid after computation (next cycle)
            valid_out_reg <= 1;
        end else begin
            // FIX BUG 2: Turunkan valid_out_reg ke 0 jika valid_in sudah mati
            valid_out_reg <= 0;
        end
    end

    // Assign outputs
    assign valid_out = valid_out_reg;
    
    // Output vector assignment
    genvar k;
    generate
        for (k = 0; k < OUTPUT_DIM; k = k + 1) begin : output_assign
            assign output_vector[16*(k+1)-1:16*k] = output_hold[k];
        end
    endgenerate

endmodule
