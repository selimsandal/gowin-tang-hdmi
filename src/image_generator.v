// Optimized Synthetic Image Generator for Convolution Testing
// Reduced to essential patterns to minimize LUT usage

module image_generator #(
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rst_n,
    
    // Pixel position from video timing
    input [9:0] pixel_x,
    input [9:0] pixel_y,
    input pixel_valid,
    
    // Pattern selection (reduced to 2 bits)
    input [1:0] pattern_select,
    
    // Animation frame counter for moving patterns
    input [15:0] frame_counter,  // Reduced width
    
    // Output synthetic image
    output reg [DATA_WIDTH-1:0] pixel_out,
    output reg pixel_out_valid
);

// Reduced pattern selection constants
localparam PATTERN_CHECKERBOARD = 2'h0;  // High frequency checkerboard
localparam PATTERN_GRADIENT     = 2'h1;  // Linear gradients
localparam PATTERN_GEOMETRIC    = 2'h2;  // Simple geometric shapes
localparam PATTERN_STRIPES      = 2'h3;  // Vertical/horizontal stripes

// Simplified animation parameters
reg [7:0] animation_phase;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        animation_phase <= 8'h0;
    end else begin
        animation_phase <= frame_counter[15:8]; // Simple animation from high bits
    end
end

// Optimized pattern generation
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_out <= 8'h0;
        pixel_out_valid <= 1'b0;
    end else begin
        pixel_out_valid <= pixel_valid;
        
        if (pixel_valid) begin
            case (pattern_select)
                PATTERN_CHECKERBOARD: begin
                    // Simple checkerboard pattern (great for edge detection)
                    pixel_out <= ((pixel_x[4] ^ pixel_y[4]) & 1) ? 8'hFF : 8'h00;
                end
                
                PATTERN_GRADIENT: begin
                    // Simple gradients
                    case (animation_phase[7:6])
                        2'b00: pixel_out <= pixel_x[7:0]; // Horizontal
                        2'b01: pixel_out <= pixel_y[7:0]; // Vertical  
                        2'b10: pixel_out <= (pixel_x[7:0] + pixel_y[7:0]) >> 1; // Diagonal
                        2'b11: pixel_out <= pixel_x[7:0] ^ pixel_y[7:0]; // XOR
                    endcase
                end
                
                PATTERN_GEOMETRIC: begin
                    // Simple geometric shapes
                    if ((pixel_x > 100 && pixel_x < 300 && pixel_y > 100 && pixel_y < 300) ||
                        (pixel_x > 350 && pixel_x < 500 && pixel_y > 200 && pixel_y < 350)) begin
                        pixel_out <= 8'hC0 + animation_phase[5:0];
                    end else begin
                        pixel_out <= 8'h40;
                    end
                end
                
                PATTERN_STRIPES: begin
                    // Simple stripes
                    case (animation_phase[7:6])
                        2'b00: pixel_out <= pixel_x[5] ? 8'hFF : 8'h00; // Vertical
                        2'b01: pixel_out <= pixel_y[5] ? 8'hFF : 8'h00; // Horizontal
                        2'b10: pixel_out <= (pixel_x[4] ^ pixel_y[4]) ? 8'hFF : 8'h00; // Grid
                        2'b11: pixel_out <= (pixel_x[5:0] + pixel_y[5:0]) >> 1; // Ramp
                    endcase
                end
            endcase
        end else begin
            pixel_out <= 8'h00;
        end
    end
end

endmodule