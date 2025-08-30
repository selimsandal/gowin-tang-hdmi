// Shader Execution Pipeline
// Manages shader programs and coordinates vector operations for pixel rendering

module shader_pipeline #(
    parameter DATA_WIDTH = 16,
    parameter VECTOR_WIDTH = 4,
    parameter SHADER_MEM_DEPTH = 256,
    parameter SHADER_ADDR_WIDTH = 8
)(
    input clk,
    input rst_n,
    
    // Pixel coordinates from display controller
    input [9:0] pixel_x,
    input [9:0] pixel_y,
    input pixel_valid,
    
    // Shader program selection
    input [3:0] shader_select,
    
    // Output color
    output reg [7:0] red_out,
    output reg [7:0] green_out,
    output reg [7:0] blue_out,
    output reg color_valid,
    
    // Vector processor interface
    output reg vp_start,
    output reg [3:0] vp_operation,
    output reg [VECTOR_WIDTH*DATA_WIDTH-1:0] vp_vec_a,
    output reg [VECTOR_WIDTH*DATA_WIDTH-1:0] vp_vec_b,
    output reg [DATA_WIDTH-1:0] vp_scalar,
    input vp_busy,
    input vp_done,
    input [VECTOR_WIDTH*DATA_WIDTH-1:0] vp_result,
    input vp_result_valid
);

// Shader programs
localparam SHADER_GRADIENT_H = 4'h0;    // Horizontal gradient
localparam SHADER_GRADIENT_V = 4'h1;    // Vertical gradient
localparam SHADER_RADIAL     = 4'h2;    // Radial pattern
localparam SHADER_CHECKER    = 4'h3;    // Checkerboard
localparam SHADER_SINE_WAVE  = 4'h4;    // Sine wave pattern
localparam SHADER_SPIRAL     = 4'h5;    // Spiral pattern
localparam SHADER_TRIANGLE   = 4'h6;    // Rotating triangle
localparam SHADER_ROTATING_COLORS = 4'h7; // Rotating color wheel
localparam SHADER_PULSING_CIRCLES = 4'h8; // Pulsing concentric circles

// Pipeline states
localparam IDLE = 3'h0;
localparam NORMALIZE_COORDS = 3'h1;
localparam EXECUTE_SHADER = 3'h2;
localparam WAIT_RESULT = 3'h3;
localparam OUTPUT_COLOR = 3'h4;

reg [2:0] state, next_state;

// Coordinate normalization (convert to 0.0-1.0 range in fixed point)
reg [DATA_WIDTH-1:0] norm_x, norm_y;
reg [DATA_WIDTH-1:0] center_x, center_y;

// Animation counter for time-based effects
reg [23:0] frame_counter;
reg [DATA_WIDTH-1:0] time_var;

// Fixed-point constants
localparam FP_ONE = 16'h0100;      // 1.0 in 8.8 fixed point
localparam FP_HALF = 16'h0080;     // 0.5 in 8.8 fixed point
localparam SCREEN_WIDTH = 640;
localparam SCREEN_HEIGHT = 480;

// Temporary vectors for computation
reg [VECTOR_WIDTH*DATA_WIDTH-1:0] temp_vec;
reg [DATA_WIDTH-1:0] temp_scalar;

// Simple triangle using distance-based method
reg triangle_inside;
reg [15:0] distance_to_center;
reg [15:0] triangle_radius;
reg signed [15:0] dx, dy;
reg [15:0] center_x_px, center_y_px;
reg signed [15:0] v0x, v0y, v1x, v1y, v2x, v2y;
reg signed [31:0] edge1, edge2, edge3;

// Animation parameters
reg [7:0] rotation_phase;
reg [15:0] color_rotation;
reg [15:0] pulse_phase;
reg [15:0] circle_radius;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_counter <= 24'h0;
        rotation_phase <= 8'h0;
        color_rotation <= 16'h0;
        pulse_phase <= 16'h0;
    end else begin
        frame_counter <= frame_counter + 1;
        rotation_phase <= frame_counter[23:18]; // Much slower animation - ~26 seconds per rotation
        color_rotation <= frame_counter[23:8];  // Color rotation - 10x slower, now very smooth
        pulse_phase <= frame_counter[21:6];     // Pulse animation - 10x slower, now very smooth
    end
end

// Simple triangle calculation using distance from center
always @(*) begin
    // Calculate distance from screen center (320, 240) to current pixel
    center_x_px = SCREEN_WIDTH >> 1;  // 320
    center_y_px = SCREEN_HEIGHT >> 1; // 240
    
    // Distance calculation
    dx = $signed({1'b0, pixel_x}) - $signed({1'b0, center_x_px});
    dy = $signed({1'b0, pixel_y}) - $signed({1'b0, center_y_px});
    
    // Simple Manhattan distance (faster than Euclidean)
    distance_to_center = (dx >= 0 ? dx : -dx) + (dy >= 0 ? dy : -dy);
    
    // Create animated triangle radius (larger size)
    triangle_radius = 50 + {10'b0, rotation_phase[4:0]}; // 50-82 pixels
    
    // Proper triangle using 3 edge tests
    // Define 3 triangle vertices in pixel space, rotating around center
    
    // Calculate rotated triangle vertices (fixed 60 pixel radius)
    case (rotation_phase[5:4]) // 4 rotation states, changes more frequently
        2'b00: begin // 0 degrees
            v0x = $signed(center_x_px);           v0y = $signed(center_y_px) - 60; // Top
            v1x = $signed(center_x_px) - 52;      v1y = $signed(center_y_px) + 30; // Bottom left  
            v2x = $signed(center_x_px) + 52;      v2y = $signed(center_y_px) + 30; // Bottom right
        end
        2'b01: begin // 90 degrees  
            v0x = $signed(center_x_px) + 60;      v0y = $signed(center_y_px);      // Right
            v1x = $signed(center_x_px) - 30;      v1y = $signed(center_y_px) - 52; // Top left
            v2x = $signed(center_x_px) - 30;      v2y = $signed(center_y_px) + 52; // Bottom left
        end
        2'b10: begin // 180 degrees
            v0x = $signed(center_x_px);           v0y = $signed(center_y_px) + 60; // Bottom
            v1x = $signed(center_x_px) + 52;      v1y = $signed(center_y_px) - 30; // Top right
            v2x = $signed(center_x_px) - 52;      v2y = $signed(center_y_px) - 30; // Top left  
        end
        2'b11: begin // 270 degrees
            v0x = $signed(center_x_px) - 60;      v0y = $signed(center_y_px);      // Left
            v1x = $signed(center_x_px) + 30;      v1y = $signed(center_y_px) + 52; // Bottom right
            v2x = $signed(center_x_px) + 30;      v2y = $signed(center_y_px) - 52; // Top right
        end
    endcase
    
    // Edge function tests (cross product for each edge)
    edge1 = (v1x - v0x) * ($signed({1'b0, pixel_y}) - v0y) - (v1y - v0y) * ($signed({1'b0, pixel_x}) - v0x);
    edge2 = (v2x - v1x) * ($signed({1'b0, pixel_y}) - v1y) - (v2y - v1y) * ($signed({1'b0, pixel_x}) - v1x);  
    edge3 = (v0x - v2x) * ($signed({1'b0, pixel_y}) - v2y) - (v0y - v2y) * ($signed({1'b0, pixel_x}) - v2x);
    
    // Point is inside triangle if all edges have same sign
    triangle_inside = (edge1 >= 0 && edge2 >= 0 && edge3 >= 0) || (edge1 <= 0 && edge2 <= 0 && edge3 <= 0);
end

// Coordinate normalization with proper bounds checking
always @(*) begin
    // Ensure coordinates are within bounds and prevent division by zero/overflow
    if (pixel_x >= SCREEN_WIDTH) begin
        norm_x = 16'h00FF; // Just under 1.0 in 8.8 fixed point
    end else begin
        norm_x = (pixel_x << 8) / SCREEN_WIDTH;   // x in [0, 1] using left shift instead of multiply
    end
    
    if (pixel_y >= SCREEN_HEIGHT) begin
        norm_y = 16'h00FF; // Just under 1.0 in 8.8 fixed point  
    end else begin
        norm_y = (pixel_y << 8) / SCREEN_HEIGHT;  // y in [0, 1] using left shift instead of multiply
    end
    
    center_x = norm_x - FP_HALF;  // x in [-0.5, 0.5]
    center_y = norm_y - FP_HALF;  // y in [-0.5, 0.5]
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (pixel_valid) begin
                next_state = NORMALIZE_COORDS;
            end
        end
        
        NORMALIZE_COORDS: begin
            next_state = EXECUTE_SHADER;
        end
        
        EXECUTE_SHADER: begin
            if (shader_select == SHADER_TRIANGLE || shader_select == SHADER_ROTATING_COLORS || shader_select == SHADER_PULSING_CIRCLES) begin
                // These shaders bypass vector processor
                next_state = OUTPUT_COLOR;
            end else if (vp_start) begin
                next_state = WAIT_RESULT;
            end
        end
        
        WAIT_RESULT: begin
            if (vp_result_valid) begin
                next_state = OUTPUT_COLOR;
            end
        end
        
        OUTPUT_COLOR: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Shader execution logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        vp_start <= 1'b0;
        vp_operation <= 4'h0;
        vp_vec_a <= 64'h0;
        vp_vec_b <= 64'h0;
        vp_scalar <= 16'h0;
        red_out <= 8'h0;
        green_out <= 8'h0;
        blue_out <= 8'h0;
        color_valid <= 1'b0;
    end else begin
        vp_start <= 1'b0;
        color_valid <= 1'b0;
        
        case (state)
            EXECUTE_SHADER: begin
                case (shader_select)
                    SHADER_GRADIENT_H: begin
                        // Horizontal gradient: red varies with x (clamped)
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'hFF00, 16'h0000, 16'h0000, 16'hFF00}; // Red vector
                        vp_scalar <= norm_x;
                    end
                    
                    SHADER_GRADIENT_V: begin
                        // Vertical gradient: green varies with y (clamped)
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'h0000, 16'hFF00, 16'h0000, 16'hFF00}; // Green vector
                        vp_scalar <= norm_y;
                    end
                    
                    SHADER_RADIAL: begin
                        // Radial pattern: distance from center (clamped coordinates)
                        vp_start <= 1'b1;
                        vp_operation <= 4'h5; // OP_LENGTH
                        vp_vec_a <= {center_x, center_y, 16'h0000, 16'h0000};
                    end
                    
                    SHADER_CHECKER: begin
                        // Checkerboard pattern with proper bounds checking
                        if (pixel_x < SCREEN_WIDTH && pixel_y < SCREEN_HEIGHT) begin
                            temp_scalar = ((pixel_x[9:5]) ^ (pixel_y[9:5])) & 1 ? FP_ONE : 16'h0000;
                        end else begin
                            temp_scalar = 16'h0000; // Black for out of bounds
                        end
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'hFF00, 16'hFF00, 16'hFF00, 16'hFF00}; // White
                        vp_scalar <= temp_scalar;
                    end
                    
                    SHADER_SINE_WAVE: begin
                        // Sine wave pattern with bounds checking
                        if (pixel_x < SCREEN_WIDTH && pixel_y < SCREEN_HEIGHT) begin
                            temp_scalar = (norm_x + {8'h00, time_var[7:0]}) & 16'h00FF; // Mask to prevent overflow
                        end else begin
                            temp_scalar = 16'h0000;
                        end
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {temp_scalar, 16'h8000, temp_scalar, 16'hFF00};
                        vp_scalar <= FP_ONE;
                    end
                    
                    SHADER_TRIANGLE: begin
                        // Triangle shader - prepare for direct triangle testing
                        // No vector processor needed, triangle test is done in OUTPUT_COLOR
                        vp_start <= 1'b0;
                        vp_operation <= 4'h0;
                        vp_vec_a <= 64'h0;
                        vp_vec_b <= 64'h0;
                    end
                    
                    SHADER_ROTATING_COLORS: begin
                        // Rotating colors shader - direct computation
                        // No vector processor needed
                        vp_start <= 1'b0;
                        vp_operation <= 4'h0;
                        vp_vec_a <= 64'h0;
                        vp_vec_b <= 64'h0;
                    end
                    
                    SHADER_PULSING_CIRCLES: begin
                        // Pulsing circles shader - direct computation
                        // No vector processor needed
                        vp_start <= 1'b0;
                        vp_operation <= 4'h0;
                        vp_vec_a <= 64'h0;
                        vp_vec_b <= 64'h0;
                    end
                    
                    default: begin
                        // Default: solid color
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'h8000, 16'h4000, 16'hC000, 16'hFF00}; // Purple-ish
                        vp_scalar <= FP_ONE;
                    end
                endcase
            end
            
            OUTPUT_COLOR: begin
                // Convert fixed-point result to 8-bit RGB
                if (shader_select == SHADER_TRIANGLE) begin
                    // Triangle with animated gradient background
                    if (triangle_inside) begin
                        // Bright triangle with color animation
                        red_out   <= 8'hFF;                                    // Bright red
                        green_out <= 8'h40 + {2'b0, rotation_phase[5:0]};     // Animated green  
                        blue_out  <= 8'h80;                                    // Blue
                    end else begin
                        // Beautiful animated gradient background
                        // Create a radial gradient with color shifting
                        red_out   <= (norm_x >> 1) + (rotation_phase >> 2);   // X-based red with animation
                        green_out <= (norm_y >> 1) + (rotation_phase >> 3);   // Y-based green with animation
                        blue_out  <= 8'h60 + ((norm_x ^ norm_y) >> 2) + (rotation_phase >> 4); // Mixed blue with animation
                    end
                end else if (shader_select == SHADER_ROTATING_COLORS) begin
                    // Rotating color wheel based on position and time
                    // Create HSV-like color wheel effect
                    temp_scalar = ((norm_x + norm_y) >> 1) + color_rotation[15:8]; // Position + rotation
                    case (temp_scalar[7:6]) // 4 color sectors
                        2'b00: begin // Red to Yellow transition
                            red_out   <= 8'hFF;
                            green_out <= temp_scalar[5:0] << 2; // Fade in green
                            blue_out  <= 8'h20;
                        end
                        2'b01: begin // Yellow to Green transition  
                            red_out   <= 8'hFF - (temp_scalar[5:0] << 2); // Fade out red
                            green_out <= 8'hFF;
                            blue_out  <= 8'h20;
                        end
                        2'b10: begin // Green to Blue transition
                            red_out   <= 8'h20;
                            green_out <= 8'hFF - (temp_scalar[5:0] << 2); // Fade out green
                            blue_out  <= temp_scalar[5:0] << 2; // Fade in blue
                        end
                        2'b11: begin // Blue to Red transition
                            red_out   <= temp_scalar[5:0] << 2; // Fade in red
                            green_out <= 8'h20;
                            blue_out  <= 8'hFF - (temp_scalar[5:0] << 2); // Fade out blue
                        end
                    endcase
                end else if (shader_select == SHADER_PULSING_CIRCLES) begin
                    // Concentric pulsing circles
                    circle_radius = 30 + (pulse_phase[10:4]); // Pulsing radius 30-158
                    temp_scalar = distance_to_center; // Reuse distance calculation from triangle
                    
                    // Create multiple concentric circles
                    if ((temp_scalar[7:0] ^ circle_radius[7:0]) < 8'd15) begin // Ring 1
                        red_out   <= 8'hFF;
                        green_out <= 8'h40;
                        blue_out  <= pulse_phase[11:4];
                    end else if (((temp_scalar[8:1] ^ circle_radius[8:1]) < 7'd10)) begin // Ring 2  
                        red_out   <= pulse_phase[10:3];
                        green_out <= 8'hFF;
                        blue_out  <= 8'h60;
                    end else if (((temp_scalar[9:2] ^ circle_radius[9:2]) < 6'd8)) begin // Ring 3
                        red_out   <= 8'h80;
                        green_out <= pulse_phase[9:2];
                        blue_out  <= 8'hFF;
                    end else begin
                        // Background with subtle animation
                        red_out   <= 8'h20 + pulse_phase[7:5];
                        green_out <= 8'h15 + pulse_phase[8:6]; 
                        blue_out  <= 8'h30 + pulse_phase[6:4];
                    end
                end else if (shader_select == SHADER_RADIAL) begin
                    // For radial, use distance as brightness
                    temp_scalar = vp_result[63:48]; // Length result
                    red_out <= temp_scalar[15:8];
                    green_out <= temp_scalar[15:8];
                    blue_out <= 8'hFF - temp_scalar[15:8]; // Inverse for blue
                end else begin
                    // Standard RGB output
                    red_out   <= vp_result[63:56];  // R component
                    green_out <= vp_result[47:40];  // G component  
                    blue_out  <= vp_result[31:24];  // B component
                end
                color_valid <= 1'b1;
            end
        endcase
    end
end

endmodule