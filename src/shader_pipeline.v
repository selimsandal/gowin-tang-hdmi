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
    input vp_result_valid,
    
    // Convolution engine interface (simplified)
    input [7:0] conv_pixel_in,
    input conv_valid_in,
    input [9:0] conv_processing_x,
    input [9:0] conv_processing_y,
    input [1:0] conv_kernel_select
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
localparam SHADER_CONVOLUTION = 4'h9; // Real-time convolution processing

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


// Smooth rotation lookup tables (sine/cosine approximations)
// Using 64 steps for smooth rotation (6-bit precision)
reg signed [15:0] cos_lut [0:63];
reg signed [15:0] sin_lut [0:63];
reg [5:0] rotation_angle;

// Initialize lookup tables with precomputed sine/cosine values
// Using 64 steps for smooth rotation with 60-pixel radius
initial begin
    // Hardcoded sine/cosine lookup table for 64 positions
    // Values scaled by 60 for triangle radius
    cos_lut[0] = 60; sin_lut[0] = 0;       // 0°
    cos_lut[1] = 59; sin_lut[1] = 6;       // 5.625°
    cos_lut[2] = 57; sin_lut[2] = 12;      // 11.25°
    cos_lut[3] = 54; sin_lut[3] = 18;      // 16.875°
    cos_lut[4] = 51; sin_lut[4] = 24;      // 22.5°
    cos_lut[5] = 47; sin_lut[5] = 29;      // 28.125°
    cos_lut[6] = 42; sin_lut[6] = 34;      // 33.75°
    cos_lut[7] = 37; sin_lut[7] = 38;      // 39.375°
    cos_lut[8] = 32; sin_lut[8] = 42;      // 45°
    cos_lut[9] = 27; sin_lut[9] = 46;      // 50.625°
    cos_lut[10] = 21; sin_lut[10] = 49;    // 56.25°
    cos_lut[11] = 15; sin_lut[11] = 52;    // 61.875°
    cos_lut[12] = 9; sin_lut[12] = 54;     // 67.5°
    cos_lut[13] = 3; sin_lut[13] = 56;     // 73.125°
    cos_lut[14] = -3; sin_lut[14] = 57;    // 78.75°
    cos_lut[15] = -9; sin_lut[15] = 58;    // 84.375°
    cos_lut[16] = 0; sin_lut[16] = 60;     // 90°
    cos_lut[17] = -6; sin_lut[17] = 59;    // 95.625°
    cos_lut[18] = -12; sin_lut[18] = 57;   // 101.25°
    cos_lut[19] = -18; sin_lut[19] = 54;   // 106.875°
    cos_lut[20] = -24; sin_lut[20] = 51;   // 112.5°
    cos_lut[21] = -29; sin_lut[21] = 47;   // 118.125°
    cos_lut[22] = -34; sin_lut[22] = 42;   // 123.75°
    cos_lut[23] = -38; sin_lut[23] = 37;   // 129.375°
    cos_lut[24] = -42; sin_lut[24] = 32;   // 135°
    cos_lut[25] = -46; sin_lut[25] = 27;   // 140.625°
    cos_lut[26] = -49; sin_lut[26] = 21;   // 146.25°
    cos_lut[27] = -52; sin_lut[27] = 15;   // 151.875°
    cos_lut[28] = -54; sin_lut[28] = 9;    // 157.5°
    cos_lut[29] = -56; sin_lut[29] = 3;    // 163.125°
    cos_lut[30] = -57; sin_lut[30] = -3;   // 168.75°
    cos_lut[31] = -58; sin_lut[31] = -9;   // 174.375°
    cos_lut[32] = -60; sin_lut[32] = 0;    // 180°
    cos_lut[33] = -59; sin_lut[33] = -6;   // 185.625°
    cos_lut[34] = -57; sin_lut[34] = -12;  // 191.25°
    cos_lut[35] = -54; sin_lut[35] = -18;  // 196.875°
    cos_lut[36] = -51; sin_lut[36] = -24;  // 202.5°
    cos_lut[37] = -47; sin_lut[37] = -29;  // 208.125°
    cos_lut[38] = -42; sin_lut[38] = -34;  // 213.75°
    cos_lut[39] = -37; sin_lut[39] = -38;  // 219.375°
    cos_lut[40] = -32; sin_lut[40] = -42;  // 225°
    cos_lut[41] = -27; sin_lut[41] = -46;  // 230.625°
    cos_lut[42] = -21; sin_lut[42] = -49;  // 236.25°
    cos_lut[43] = -15; sin_lut[43] = -52;  // 241.875°
    cos_lut[44] = -9; sin_lut[44] = -54;   // 247.5°
    cos_lut[45] = -3; sin_lut[45] = -56;   // 253.125°
    cos_lut[46] = 3; sin_lut[46] = -57;    // 258.75°
    cos_lut[47] = 9; sin_lut[47] = -58;    // 264.375°
    cos_lut[48] = 0; sin_lut[48] = -60;    // 270°
    cos_lut[49] = 6; sin_lut[49] = -59;    // 275.625°
    cos_lut[50] = 12; sin_lut[50] = -57;   // 281.25°
    cos_lut[51] = 18; sin_lut[51] = -54;   // 286.875°
    cos_lut[52] = 24; sin_lut[52] = -51;   // 292.5°
    cos_lut[53] = 29; sin_lut[53] = -47;   // 298.125°
    cos_lut[54] = 34; sin_lut[54] = -42;   // 303.75°
    cos_lut[55] = 38; sin_lut[55] = -37;   // 309.375°
    cos_lut[56] = 42; sin_lut[56] = -32;   // 315°
    cos_lut[57] = 46; sin_lut[57] = -27;   // 320.625°
    cos_lut[58] = 49; sin_lut[58] = -21;   // 326.25°
    cos_lut[59] = 52; sin_lut[59] = -15;   // 331.875°
    cos_lut[60] = 54; sin_lut[60] = -9;    // 337.5°
    cos_lut[61] = 56; sin_lut[61] = -3;    // 343.125°
    cos_lut[62] = 57; sin_lut[62] = 3;     // 348.75°
    cos_lut[63] = 58; sin_lut[63] = 9;     // 354.375°
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_counter <= 24'h0;
        rotation_phase <= 8'h0;
        color_rotation <= 16'h0;
        pulse_phase <= 16'h0;
        rotation_angle <= 6'h0;
    end else begin
        frame_counter <= frame_counter + 1;
        rotation_phase <= frame_counter[23:18]; // Much slower animation - ~26 seconds per rotation
        color_rotation <= frame_counter[23:8];  // Color rotation - 10x slower, now very smooth
        pulse_phase <= frame_counter[21:6];     // Pulse animation - 10x slower, now very smooth
        rotation_angle <= frame_counter[23:18]; // Smooth 64-step rotation, same speed as rotation_phase
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
    
    // Calculate smoothly rotated triangle vertices using lookup tables
    // Triangle has 3 vertices: top (0°), bottom-left (120°), bottom-right (240°)
    // Vertex 0: Top vertex
    v0x = $signed(center_x_px) + sin_lut[rotation_angle];          
    v0y = $signed(center_y_px) - cos_lut[rotation_angle];          
    
    // Vertex 1: Bottom-left vertex (120° offset)
    v1x = $signed(center_x_px) + sin_lut[(rotation_angle + 6'd21) & 6'h3F];  // +120° with wrap-around
    v1y = $signed(center_y_px) - cos_lut[(rotation_angle + 6'd21) & 6'h3F];  
    
    // Vertex 2: Bottom-right vertex (240° offset)  
    v2x = $signed(center_x_px) + sin_lut[(rotation_angle + 6'd42) & 6'h3F];  // +240° with wrap-around
    v2y = $signed(center_y_px) - cos_lut[(rotation_angle + 6'd42) & 6'h3F];
    
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
            if (shader_select == SHADER_TRIANGLE || shader_select == SHADER_ROTATING_COLORS || shader_select == SHADER_PULSING_CIRCLES || shader_select == SHADER_CONVOLUTION) begin
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
                    
                    SHADER_CONVOLUTION: begin
                        // Real-time convolution processing - direct computation
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
                end else if (shader_select == SHADER_CONVOLUTION) begin
                    // Slow block-by-block convolution visualization
                    
                    // Show the current processing cursor - bright white crosshair
                    if (((pixel_x >= conv_processing_x - 10'd5 && pixel_x <= conv_processing_x + 10'd5) && pixel_y == conv_processing_y) ||
                        ((pixel_y >= conv_processing_y - 10'd5 && pixel_y <= conv_processing_y + 10'd5) && pixel_x == conv_processing_x)) begin
                        // Bright white processing cursor
                        red_out   <= 8'hFF;
                        green_out <= 8'hFF;
                        blue_out  <= 8'hFF;
                    end
                    // Show a bright box around the current processing position (3x3 window)
                    else if ((pixel_x >= conv_processing_x - 10'd1 && pixel_x <= conv_processing_x + 10'd1) && 
                             (pixel_y >= conv_processing_y - 10'd1 && pixel_y <= conv_processing_y + 10'd1)) begin
                        // Bright colored box showing 3x3 convolution window
                        case (conv_kernel_select)
                            2'h0: begin red_out <= 8'hFF; green_out <= 8'hFF; blue_out <= 8'hFF; end // White - Identity
                            2'h1: begin red_out <= 8'hFF; green_out <= 8'h00; blue_out <= 8'h00; end // Red - Edge
                            2'h2: begin red_out <= 8'h00; green_out <= 8'h00; blue_out <= 8'hFF; end // Blue - Blur
                            2'h3: begin red_out <= 8'hFF; green_out <= 8'hFF; blue_out <= 8'h00; end // Yellow - Sharpen
                        endcase
                    end
                    // Show framebuffer results for the entire processing region (64x64 centered area)
                    else if (conv_valid_in && 
                             (pixel_x >= 10'd288 && pixel_x <= 10'd351) &&
                             (pixel_y >= 10'd208 && pixel_y <= 10'd271)) begin
                        // Display convolution result with kernel-specific coloring across entire processing region
                        case (conv_kernel_select) // Use dedicated convolution kernel select
                            2'h0: begin // Identity - grayscale
                                red_out   <= conv_pixel_in;
                                green_out <= conv_pixel_in;
                                blue_out  <= conv_pixel_in;
                            end
                            2'h1: begin // Edge detection - cyan
                                red_out   <= 8'h00;
                                green_out <= conv_pixel_in;
                                blue_out  <= conv_pixel_in;
                            end
                            2'h2: begin // Blur - blue tint
                                red_out   <= conv_pixel_in >> 1;
                                green_out <= conv_pixel_in >> 1;
                                blue_out  <= conv_pixel_in;
                            end
                            2'h3: begin // Sharpen - yellow tint
                                red_out   <= conv_pixel_in;
                                green_out <= conv_pixel_in;
                                blue_out  <= conv_pixel_in >> 1;
                            end
                        endcase
                    end
                    // Show kernel indicator in top-right corner
                    else if (pixel_x > 580 && pixel_x < 620 && pixel_y < 40) begin
                        case (conv_kernel_select)
                            2'h0: begin red_out <= 8'hFF; green_out <= 8'hFF; blue_out <= 8'hFF; end // White - Identity
                            2'h1: begin red_out <= 8'hFF; green_out <= 8'h00; blue_out <= 8'h00; end // Red - Edge
                            2'h2: begin red_out <= 8'h00; green_out <= 8'h80; blue_out <= 8'hFF; end // Blue - Blur
                            2'h3: begin red_out <= 8'hFF; green_out <= 8'hFF; blue_out <= 8'h00; end // Yellow - Sharpen
                        endcase
                    end
                    else begin
                        // Show background - test pattern inside processing region, dark outside
                        if ((pixel_x >= 10'd288 && pixel_x <= 10'd351) &&
                            (pixel_y >= 10'd208 && pixel_y <= 10'd271)) begin
                            // Inside processing region - show clear test pattern for convolution
                            case (conv_kernel_select) // Pattern selection based on kernel
                                2'h0: begin // Checkerboard for identity
                                    red_out   <= ((pixel_x[4] ^ pixel_y[4]) & 1) ? 8'hC0 : 8'h40;
                                    green_out <= ((pixel_x[4] ^ pixel_y[4]) & 1) ? 8'hC0 : 8'h40;
                                    blue_out  <= ((pixel_x[4] ^ pixel_y[4]) & 1) ? 8'hC0 : 8'h40;
                                end
                                2'h1: begin // Sharp edges for edge detection
                                    if ((pixel_x > 300 && pixel_x < 340 && pixel_y > 220 && pixel_y < 260)) begin
                                        red_out   <= 8'hE0;
                                        green_out <= 8'hE0;
                                        blue_out  <= 8'hE0;
                                    end else begin
                                        red_out   <= 8'h30;
                                        green_out <= 8'h30;
                                        blue_out  <= 8'h30;
                                    end
                                end
                                2'h2: begin // High frequency pattern for blur
                                    red_out   <= ((pixel_x[3] ^ pixel_y[3]) & 1) ? 8'hA0 : 8'h60;
                                    green_out <= ((pixel_x[3] ^ pixel_y[3]) & 1) ? 8'hA0 : 8'h60;
                                    blue_out  <= ((pixel_x[3] ^ pixel_y[3]) & 1) ? 8'hA0 : 8'h60;
                                end
                                2'h3: begin // Smooth pattern for sharpen
                                    red_out   <= 8'h80 + (pixel_x[5:3] * pixel_y[5:3]);
                                    green_out <= 8'h80 + (pixel_x[5:3] * pixel_y[5:3]);
                                    blue_out  <= 8'h80 + (pixel_x[5:3] * pixel_y[5:3]);
                                end
                            endcase
                        end else begin
                            // Outside processing region - dark background
                            red_out   <= 8'h10;
                            green_out <= 8'h10;
                            blue_out  <= 8'h10;
                        end
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