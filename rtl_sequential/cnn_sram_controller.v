module cnn_sram_controller #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    
    input wire start, // Flag untuk memulai inference 1 frame
    output reg done,
    
    // SRAM Interface (Sesuai `gf180mcu_ocd_ip_sram__sram256x8m8wm1`)
    output reg        sram_cen,
    output reg        sram_gwen,
    output reg [7:0]  sram_wen, // Asumsi width 64 -> 8 bytes WEN
    output reg [7:0]  sram_a,
    output reg [63:0] sram_d,
    input  wire[63:0] sram_q, // Data out
    
    // Output valid 10 skor class
    output wire valid_out,
    output wire [3:0] class_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    wire pipeline_ready;
    wire pipeline_valid_out;
    
    reg pipeline_valid_in;
    reg pipeline_last_in;
    reg signed [DATA_WIDTH-1:0] img_pixel_out;
    reg signed [DATA_WIDTH-1:0] weight_out;
    reg signed [DATA_WIDTH-1:0] bias_out;
    
    wire [15:0] weight_addr_req;
    
    // Instantiate Pipeline
    cnn_top_serial #(.DATA_WIDTH(16)) cnn_pipeline (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(pipeline_valid_in),
        .pixel_in(img_pixel_out),
        .ready_out(pipeline_ready),
        .last_in(pipeline_last_in),
        
        .weight_addr(weight_addr_req),
        .weight_in(weight_out),
        .bias_in(bias_out),
        
        .valid_out(valid_out),
        .class_idx(class_idx),
        .score_out(score_out)
    );

    // ===========================================
    // SRAM Fetch FSM
    // ===========================================
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam READ_SRAM = 3'd1;
    localparam WAIT_SRAM = 3'd2;
    localparam PUSH_TO_PIPELINE = 3'd3;
    
    reg [15:0] pixel_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            sram_cen <= 1; // Active low
            sram_gwen <= 1;
            pipeline_valid_in <= 0;
            pipeline_last_in <= 0;
            pixel_counter <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    pipeline_valid_in <= 0;
                    if (start) begin
                        state <= READ_SRAM;
                        pixel_counter <= 0;
                    end
                end
                
                READ_SRAM: begin
                    if (pipeline_ready) begin
                        // Memanggil SRAM address untuk pixel (1 frame = 784 pixel)
                        sram_cen <= 0; // Enable read
                        sram_gwen <= 1; // Read mode Disable Write
                        sram_a <= pixel_counter[7:0]; // Tentukan map address logik kita
                        state <= WAIT_SRAM;
                    end else begin
                        pipeline_valid_in <= 0; // Tunggu CNN siap
                    end
                end
                
                WAIT_SRAM: begin
                    // Latency 1 siklus SRAM terlewat, read Q di siklus berikutnya
                    state <= PUSH_TO_PIPELINE;
                end
                
                PUSH_TO_PIPELINE: begin
                    sram_cen <= 1; // Disable read SRAM
                    img_pixel_out <= sram_q[15:0]; // Lempar mux data dari Dout
                    pipeline_valid_in <= 1;
                    
                    if (pixel_counter == 783) begin // Target 28x28
                        pipeline_last_in <= 1;
                        state <= IDLE;
                        done <= 1;
                    end else begin
                        pixel_counter <= pixel_counter + 1;
                        state <= READ_SRAM;
                    end
                end
            endcase
        end
    end

endmodule