// Shader Demo Controller
// Simple button-controlled shader selection

module shader_demo (
    input clk,
    input rst_n,
    input button_next,
    output reg [3:0] shader_select,
    output reg [1:0] conv_kernel_select
);

// Button debouncing - 25MHz clock, ~20ms debounce time
localparam DEBOUNCE_CYCLES = 500000; // 20ms at 25MHz
reg [19:0] debounce_counter;
reg button_stable;
reg button_prev;
wire button_press = button_prev && !button_stable; // Falling edge detection on stable signal

// Current shader index and convolution kernel index
reg [2:0] current_shader;
reg [1:0] conv_kernel_index;
reg conv_processing_complete;

// Button debouncing and shader switching
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_shader <= 3'h0;
        conv_kernel_index <= 2'h0;
        conv_processing_complete <= 1'b0;
        shader_select <= 4'h0;
        conv_kernel_select <= 2'h0;
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
        
        // Shader/kernel switching on debounced button press
        if (button_press) begin
            // Check if we're currently in convolution mode
            if (current_shader == 3'h6) begin // Convolution shader
                // In convolution mode - cycle through kernels instead of shaders
                conv_kernel_index <= conv_kernel_index + 1;
                // After all 4 kernels (0,1,2,3), advance to next shader
                if (conv_kernel_index == 2'h3) begin
                    conv_kernel_index <= 2'h0;
                    current_shader <= current_shader + 1;
                    // Reset counter after cycling through all shaders
                    if (current_shader == 3'h6) begin
                        current_shader <= 3'h0;
                    end
                end
            end else begin
                // Normal mode - advance to next shader
                current_shader <= current_shader + 1;
                // Reset counter after cycling through all shaders
                if (current_shader == 3'h6) begin
                    current_shader <= 3'h0;
                end
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
            3'h6: begin
                // Convolution processing - shader_select stays 4'h9, kernel comes from conv_kernel_index
                shader_select <= 4'h9; // Convolution shader
            end
            default: shader_select <= 4'h6;
        endcase
        
        // Always output the current convolution kernel selection
        conv_kernel_select <= conv_kernel_index;
    end
end

endmodule