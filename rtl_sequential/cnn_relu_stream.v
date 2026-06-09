module cnn_relu_stream #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    input wire valid_in,
    input wire ready_in,    // Dari modul selanjutnya (backpressure)
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg ready_out,   // Ke modul sebelumnya
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            data_out <= 0;
            ready_out <= 1;
        end else begin
            ready_out <= ready_in; // Pass-through backpressure
            
            if (valid_in && ready_in) begin
                valid_out <= 1;
                // Jika MSB = 1 (negatif), output 0. Jika tidak, pass-through.
                if (data_in[DATA_WIDTH-1]) begin
                    data_out <= 0;
                end else begin
                    data_out <= data_in;
                end
            end else if (ready_in) begin
                valid_out <= 0;
            end
        end
    end

endmodule
