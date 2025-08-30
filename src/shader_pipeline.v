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

// Triangle computation with rotation
reg triangle_inside;
reg signed [31:0] edge1_test, edge2_test, edge3_test; // Use wider precision for edge tests

// Rotation parameters  
reg signed [DATA_WIDTH-1:0] cos_theta, sin_theta;
reg signed [DATA_WIDTH-1:0] v0_x, v0_y, v1_x, v1_y, v2_x, v2_y; // Rotated vertices in normalized coordinates

// Base triangle vertices (centered at origin, larger and more visible)
localparam signed [DATA_WIDTH-1:0] BASE_V0_X = 16'h0000;  // Top vertex (0, 0.25)
localparam signed [DATA_WIDTH-1:0] BASE_V0_Y = 16'h0040;  // 0.25 in 8.8 fixed point
localparam signed [DATA_WIDTH-1:0] BASE_V1_X = -16'h0040; // Bottom left (-0.25, -0.2)
localparam signed [DATA_WIDTH-1:0] BASE_V1_Y = -16'h0033; // -0.2 in 8.8 fixed point
localparam signed [DATA_WIDTH-1:0] BASE_V2_X = 16'h0040;  // Bottom right (0.25, -0.2)
localparam signed [DATA_WIDTH-1:0] BASE_V2_Y = -16'h0033;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_counter <= 24'h0;
        time_var <= 16'h0;
    end else begin
        frame_counter <= frame_counter + 1;
        time_var <= frame_counter[23:16]; // Much slower rotation - ~2.6 seconds per full rotation at 25MHz
    end
end

// Enhanced trigonometric lookup for smoother rotation (32 positions)
always @(*) begin
    case (time_var[7:3]) // Use 5 bits for 32 discrete rotation positions
        5'h00: begin cos_theta = 16'h0100; sin_theta = 16'h0000; end    // 0°
        5'h01: begin cos_theta = 16'h00FB; sin_theta = 16'h0019; end    // 11.25°
        5'h02: begin cos_theta = 16'h00EC; sin_theta = 16'h0031; end    // 22.5°
        5'h03: begin cos_theta = 16'h00D4; sin_theta = 16'h0047; end    // 33.75°
        5'h04: begin cos_theta = 16'h00B5; sin_theta = 16'h00B5; end    // 45°
        5'h05: begin cos_theta = 16'h0047; sin_theta = 16'h00D4; end    // 56.25°
        5'h06: begin cos_theta = 16'h0031; sin_theta = 16'h00EC; end    // 67.5°
        5'h07: begin cos_theta = 16'h0019; sin_theta = 16'h00FB; end    // 78.75°
        5'h08: begin cos_theta = 16'h0000; sin_theta = 16'h0100; end    // 90°
        5'h09: begin cos_theta = -16'h0019; sin_theta = 16'h00FB; end   // 101.25°
        5'h0A: begin cos_theta = -16'h0031; sin_theta = 16'h00EC; end   // 112.5°
        5'h0B: begin cos_theta = -16'h0047; sin_theta = 16'h00D4; end   // 123.75°
        5'h0C: begin cos_theta = -16'h00B5; sin_theta = 16'h00B5; end   // 135°
        5'h0D: begin cos_theta = -16'h00D4; sin_theta = 16'h0047; end   // 146.25°
        5'h0E: begin cos_theta = -16'h00EC; sin_theta = 16'h0031; end   // 157.5°
        5'h0F: begin cos_theta = -16'h00FB; sin_theta = 16'h0019; end   // 168.75°
        5'h10: begin cos_theta = -16'h0100; sin_theta = 16'h0000; end   // 180°
        5'h11: begin cos_theta = -16'h00FB; sin_theta = -16'h0019; end  // 191.25°
        5'h12: begin cos_theta = -16'h00EC; sin_theta = -16'h0031; end  // 202.5°
        5'h13: begin cos_theta = -16'h00D4; sin_theta = -16'h0047; end  // 213.75°
        5'h14: begin cos_theta = -16'h00B5; sin_theta = -16'h00B5; end  // 225°
        5'h15: begin cos_theta = -16'h0047; sin_theta = -16'h00D4; end  // 236.25°
        5'h16: begin cos_theta = -16'h0031; sin_theta = -16'h00EC; end  // 247.5°
        5'h17: begin cos_theta = -16'h0019; sin_theta = -16'h00FB; end  // 258.75°
        5'h18: begin cos_theta = 16'h0000; sin_theta = -16'h0100; end   // 270°
        5'h19: begin cos_theta = 16'h0019; sin_theta = -16'h00FB; end   // 281.25°
        5'h1A: begin cos_theta = 16'h0031; sin_theta = -16'h00EC; end   // 292.5°
        5'h1B: begin cos_theta = 16'h0047; sin_theta = -16'h00D4; end   // 303.75°
        5'h1C: begin cos_theta = 16'h00B5; sin_theta = -16'h00B5; end   // 315°
        5'h1D: begin cos_theta = 16'h00D4; sin_theta = -16'h0047; end   // 326.25°
        5'h1E: begin cos_theta = 16'h00EC; sin_theta = -16'h0031; end   // 337.5°
        5'h1F: begin cos_theta = 16'h00FB; sin_theta = -16'h0019; end   // 348.75°
    endcase
end

// Rotate triangle vertices: [x'] = [cos -sin] [x]
//                           [y']   [sin  cos] [y]
// All vertices are transformed to normalized screen coordinates [0,1]
always @(*) begin
    // Vertex 0 rotation (use signed arithmetic, then shift to [0,1] range)
    v0_x = (((BASE_V0_X * cos_theta) - (BASE_V0_Y * sin_theta)) >>> 8) + FP_HALF;
    v0_y = (((BASE_V0_X * sin_theta) + (BASE_V0_Y * cos_theta)) >>> 8) + FP_HALF;
    
    // Vertex 1 rotation  
    v1_x = (((BASE_V1_X * cos_theta) - (BASE_V1_Y * sin_theta)) >>> 8) + FP_HALF;
    v1_y = (((BASE_V1_X * sin_theta) + (BASE_V1_Y * cos_theta)) >>> 8) + FP_HALF;
    
    // Vertex 2 rotation
    v2_x = (((BASE_V2_X * cos_theta) - (BASE_V2_Y * sin_theta)) >>> 8) + FP_HALF;
    v2_y = (((BASE_V2_X * sin_theta) + (BASE_V2_Y * cos_theta)) >>> 8) + FP_HALF;
end

// Coordinate normalization
always @(*) begin
    norm_x = (pixel_x * FP_ONE) / SCREEN_WIDTH;   // x in [0, 1]
    norm_y = (pixel_y * FP_ONE) / SCREEN_HEIGHT;  // y in [0, 1]
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
            if (shader_select == SHADER_TRIANGLE) begin
                // Triangle shader bypasses vector processor
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
                        // Horizontal gradient: red varies with x
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'hFF00, 16'h0000, 16'h0000, 16'hFF00}; // Red vector
                        vp_scalar <= norm_x;
                    end
                    
                    SHADER_GRADIENT_V: begin
                        // Vertical gradient: green varies with y
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'h0000, 16'hFF00, 16'h0000, 16'hFF00}; // Green vector
                        vp_scalar <= norm_y;
                    end
                    
                    SHADER_RADIAL: begin
                        // Radial pattern: distance from center
                        vp_start <= 1'b1;
                        vp_operation <= 4'h5; // OP_LENGTH
                        vp_vec_a <= {center_x, center_y, 16'h0000, 16'h0000};
                    end
                    
                    SHADER_CHECKER: begin
                        // Checkerboard pattern using XOR of coordinate bits
                        temp_scalar = ((pixel_x >> 5) ^ (pixel_y >> 5)) & 1 ? FP_ONE : 16'h0000;
                        vp_start <= 1'b1;
                        vp_operation <= 4'h4; // OP_SCALE
                        vp_vec_a <= {16'hFF00, 16'hFF00, 16'hFF00, 16'hFF00}; // White
                        vp_scalar <= temp_scalar;
                    end
                    
                    SHADER_SINE_WAVE: begin
                        // Sine wave pattern (approximated)
                        temp_scalar = (norm_x + time_var) & 16'hFF; // Simple wave approximation
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
                    // Rotating triangle using corrected edge testing
                    // All coordinates are now in the same [0,1] normalized space
                    
                    // Edge test using cross product with wider precision
                    // Edge 1: (v1 - v0) x (p - v0) 
                    edge1_test = ((v1_x - v0_x) * (norm_y - v0_y)) - ((v1_y - v0_y) * (norm_x - v0_x));
                    
                    // Edge 2: (v2 - v1) x (p - v1)
                    edge2_test = ((v2_x - v1_x) * (norm_y - v1_y)) - ((v2_y - v1_y) * (norm_x - v1_x));
                    
                    // Edge 3: (v0 - v2) x (p - v2) 
                    edge3_test = ((v0_x - v2_x) * (norm_y - v2_y)) - ((v0_y - v2_y) * (norm_x - v2_x));
                    
                    // Point is inside if all cross products have same sign
                    // For counter-clockwise triangle, all should be >= 0
                    triangle_inside = (edge1_test >= 32'sd0) && (edge2_test >= 32'sd0) && (edge3_test >= 32'sd0);
                    
                    if (triangle_inside) begin
                        // Smooth color animation based on rotation
                        red_out   <= 8'h80 + {1'b0, time_var[6:0]};        // Animated red
                        green_out <= 8'hC0 + {2'b0, time_var[5:0]};        // Bright animated green  
                        blue_out  <= 8'h40 + {2'b0, time_var[5:0]};        // Animated blue
                    end else begin
                        // Dark blue background
                        red_out   <= 8'h08;                                
                        green_out <= 8'h10; 
                        blue_out  <= 8'h30;
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