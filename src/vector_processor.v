// Basic Vector Processor for Shader Operations
// Supports 4-element vectors with fixed-point arithmetic

module vector_processor #(
    parameter VECTOR_WIDTH = 4,
    parameter DATA_WIDTH = 16,  // 16-bit fixed point (8.8 format)
    parameter FRAC_BITS = 8
)(
    input clk,
    input rst_n,
    
    // Control interface
    input start,
    input [3:0] operation,
    output reg busy,
    output reg done,
    
    // Vector inputs
    input [VECTOR_WIDTH*DATA_WIDTH-1:0] vec_a,
    input [VECTOR_WIDTH*DATA_WIDTH-1:0] vec_b,
    input [DATA_WIDTH-1:0] scalar,
    
    // Vector output
    output reg [VECTOR_WIDTH*DATA_WIDTH-1:0] result,
    output reg result_valid
);

// Operation codes
localparam OP_ADD      = 4'h0;  // vec_a + vec_b
localparam OP_SUB      = 4'h1;  // vec_a - vec_b
localparam OP_MUL      = 4'h2;  // vec_a * vec_b (element-wise)
localparam OP_DOT      = 4'h3;  // dot product
localparam OP_SCALE    = 4'h4;  // vec_a * scalar
localparam OP_LENGTH   = 4'h5;  // |vec_a|
localparam OP_NORMALIZE = 4'h6; // vec_a / |vec_a|
localparam OP_LERP     = 4'h7;  // linear interpolate: vec_a + scalar * (vec_b - vec_a)

// Internal signals
reg [DATA_WIDTH-1:0] a_elem [0:VECTOR_WIDTH-1];
reg [DATA_WIDTH-1:0] b_elem [0:VECTOR_WIDTH-1];
reg [DATA_WIDTH-1:0] result_elem [0:VECTOR_WIDTH-1];

// Pipeline registers
reg [3:0] op_stage1, op_stage2;
reg [DATA_WIDTH-1:0] scalar_stage1, scalar_stage2;
reg busy_stage1, busy_stage2;

// Intermediate results
reg [2*DATA_WIDTH-1:0] mult_results [0:VECTOR_WIDTH-1];
reg [2*DATA_WIDTH-1:0] dot_accumulator;
reg [DATA_WIDTH-1:0] length_result;

integer i;

// Unpack input vectors
always @(*) begin
    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
        a_elem[i] = vec_a[i*DATA_WIDTH +: DATA_WIDTH];
        b_elem[i] = vec_b[i*DATA_WIDTH +: DATA_WIDTH];
    end
end

// Pack output vector
always @(*) begin
    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
        result[i*DATA_WIDTH +: DATA_WIDTH] = result_elem[i];
    end
end

// Pipeline Stage 1: Setup and basic arithmetic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy_stage1 <= 1'b0;
        op_stage1 <= 4'h0;
        scalar_stage1 <= 16'h0;
        for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            mult_results[i] <= 32'h0;
        end
        dot_accumulator <= 32'h0;
    end else begin
        busy_stage1 <= start;
        op_stage1 <= operation;
        scalar_stage1 <= scalar;
        
        if (start) begin
            // Perform multiplications for various operations
            for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                case (operation)
                    OP_MUL, OP_DOT: mult_results[i] <= a_elem[i] * b_elem[i];
                    OP_SCALE: mult_results[i] <= a_elem[i] * scalar;
                    OP_LENGTH: mult_results[i] <= a_elem[i] * a_elem[i];
                    default: mult_results[i] <= 32'h0;
                endcase
            end
            
            // Dot product accumulation
            if (operation == OP_DOT) begin
                dot_accumulator <= (a_elem[0] * b_elem[0]) + 
                                 (a_elem[1] * b_elem[1]) + 
                                 (a_elem[2] * b_elem[2]) + 
                                 (a_elem[3] * b_elem[3]);
            end else if (operation == OP_LENGTH) begin
                dot_accumulator <= (a_elem[0] * a_elem[0]) + 
                                 (a_elem[1] * a_elem[1]) + 
                                 (a_elem[2] * a_elem[2]) + 
                                 (a_elem[3] * a_elem[3]);
            end
        end
    end
end

// Pipeline Stage 2: Final computation and output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy_stage2 <= 1'b0;
        op_stage2 <= 4'h0;
        scalar_stage2 <= 16'h0;
        result_valid <= 1'b0;
        for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
            result_elem[i] <= 16'h0;
        end
        length_result <= 16'h0;
    end else begin
        busy_stage2 <= busy_stage1;
        op_stage2 <= op_stage1;
        scalar_stage2 <= scalar_stage1;
        result_valid <= busy_stage1;
        
        if (busy_stage1) begin
            case (op_stage1)
                OP_ADD: begin
                    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                        result_elem[i] <= a_elem[i] + b_elem[i];
                    end
                end
                
                OP_SUB: begin
                    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                        result_elem[i] <= a_elem[i] - b_elem[i];
                    end
                end
                
                OP_MUL, OP_SCALE: begin
                    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                        result_elem[i] <= mult_results[i] >> FRAC_BITS; // Fixed-point adjustment
                    end
                end
                
                OP_DOT: begin
                    result_elem[0] <= dot_accumulator >> FRAC_BITS;
                    result_elem[1] <= 16'h0;
                    result_elem[2] <= 16'h0;
                    result_elem[3] <= 16'h0;
                end
                
                OP_LENGTH: begin
                    // Simplified square root approximation
                    length_result <= dot_accumulator >> (FRAC_BITS + 1); // Rough approximation
                    result_elem[0] <= length_result;
                    result_elem[1] <= 16'h0;
                    result_elem[2] <= 16'h0;
                    result_elem[3] <= 16'h0;
                end
                
                OP_LERP: begin
                    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                        // a + t * (b - a)
                        result_elem[i] <= a_elem[i] + ((scalar_stage1 * (b_elem[i] - a_elem[i])) >> FRAC_BITS);
                    end
                end
                
                default: begin
                    for (i = 0; i < VECTOR_WIDTH; i = i + 1) begin
                        result_elem[i] <= 16'h0;
                    end
                end
            endcase
        end
    end
end

// Control signals
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        busy <= 1'b0;
        done <= 1'b0;
    end else begin
        busy <= start || busy_stage1 || busy_stage2;
        done <= result_valid;
    end
end

endmodule