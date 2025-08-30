// Shader Demo Controller
// Automatically cycles through different shader programs for demonstration

module shader_demo (
    input clk,
    input rst_n,
    output reg [3:0] shader_select
);

// Counter for automatic shader switching
reg [23:0] demo_counter;
reg [2:0] current_shader;

// Switch shaders every ~0.5 seconds at 25MHz
localparam SWITCH_PERIOD = 24'd12_500_000; // 0.5 seconds at 25MHz

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        demo_counter <= 24'h0;
        current_shader <= 3'h0;
        shader_select <= 4'h0;
    end else begin
        demo_counter <= demo_counter + 1;
        
        if (demo_counter >= SWITCH_PERIOD) begin
            demo_counter <= 24'h0;
            current_shader <= current_shader + 1;
            
            // Map shader index to shader programs
            case (current_shader)
                3'h0: shader_select <= 4'h0; // Horizontal gradient
                3'h1: shader_select <= 4'h1; // Vertical gradient  
                3'h2: shader_select <= 4'h2; // Radial pattern
                3'h3: shader_select <= 4'h3; // Checkerboard
                3'h4: shader_select <= 4'h4; // Sine wave
                3'h5: shader_select <= 4'h5; // Spiral
                default: shader_select <= 4'h0;
            endcase
        end
    end
end

endmodule