// Shader Demo Controller
// Simple button-controlled shader selection

module shader_demo (
    input clk,
    input rst_n,
    input button_next,
    output reg [3:0] shader_select
);

// Button edge detection
reg button_prev;
wire button_press = button_prev && !button_next; // Falling edge detection

// Current shader index
reg [2:0] current_shader;

// Button edge detection and shader switching
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_shader <= 3'h0;
        shader_select <= 4'h0;
        button_prev <= 1'b1; // Button is active low with pullup
    end else begin
        button_prev <= button_next;
        
        if (button_press) begin
            current_shader <= current_shader + 1;
            // Reset counter after cycling through all shaders
            if (current_shader == 3'h6) begin
                current_shader <= 3'h0;
            end
        end
        
        // Map shader index to shader programs
        case (current_shader)
            3'h0: shader_select <= 4'h0; // Horizontal gradient
            3'h1: shader_select <= 4'h1; // Vertical gradient  
            3'h2: shader_select <= 4'h2; // Radial pattern
            3'h3: shader_select <= 4'h3; // Checkerboard
            3'h4: shader_select <= 4'h4; // Sine wave
            3'h5: shader_select <= 4'h5; // Spiral
            3'h6: shader_select <= 4'h6; // Triangle
            default: shader_select <= 4'h0;
        endcase
    end
end

endmodule