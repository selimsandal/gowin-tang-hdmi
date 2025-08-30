// Shader Demo Controller
// Simple button-controlled shader selection

module shader_demo (
    input clk,
    input rst_n,
    input button_next,
    output reg [3:0] shader_select
);

// Button debouncing - 25MHz clock, ~20ms debounce time
localparam DEBOUNCE_CYCLES = 500000; // 20ms at 25MHz
reg [19:0] debounce_counter;
reg button_stable;
reg button_prev;
wire button_press = button_prev && !button_stable; // Falling edge detection on stable signal

// Current shader index
reg [2:0] current_shader;

// Button debouncing and shader switching
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_shader <= 3'h0;
        shader_select <= 4'h0;
        button_prev <= 1'b1; // Button is active low with pullup
        button_stable <= 1'b1;
        debounce_counter <= 20'h0;
    end else begin
        // Debounce logic
        if (button_next == button_stable) begin
            // Button state matches stable state, reset counter
            debounce_counter <= 20'h0;
        end else begin
            // Button state different from stable, count up
            debounce_counter <= debounce_counter + 1;
            if (debounce_counter >= DEBOUNCE_CYCLES) begin
                // Button has been stable for debounce time, update stable state
                button_stable <= button_next;
                debounce_counter <= 20'h0;
            end
        end
        
        // Edge detection on stable signal
        button_prev <= button_stable;
        
        // Shader switching on debounced button press
        if (button_press) begin
            current_shader <= current_shader + 1;
            // Reset counter after cycling through all shaders
            if (current_shader == 3'h5) begin
                current_shader <= 3'h0;
            end
        end
        
        // Map shader index to shader programs
        case (current_shader)
            3'h0: shader_select <= 4'h6; // Triangle with gradient
            3'h1: shader_select <= 4'h3; // Checkerboard
            3'h2: shader_select <= 4'h7; // Rotating colors
            3'h3: shader_select <= 4'h8; // Pulsing circles
            3'h4: shader_select <= 4'h4; // Sine wave
            3'h5: shader_select <= 4'h2; // Radial pattern
            default: shader_select <= 4'h6;
        endcase
    end
end

endmodule