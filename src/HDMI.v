// (c) fpga4fun.com & KNJN LLC 2013-2023

////////////////////////////////////////////////////////////////////////
module HDMI_test(
	input clk,  // 25MHz
	output [2:0] TMDSp, TMDSn,
	output TMDSp_clock, TMDSn_clock
);
////////////////////////////////////////////////////////////////////////
wire [9:0] sx, sy;
wire hsync, vsync, de;
wire [7:0] red, green, blue;

// Shader selection from demo controller
wire [3:0] shader_select;
shader_demo demo_ctrl (
    .clk(clk),
    .rst_n(1'b1),
    .shader_select(shader_select)
);
simple480p s480p(
    .clk(clk),
    .sx(sx),
    .sy(sy),
    .hsync(hsync),
    .vsync(vsync),
    .de(de)
); 


////////////////
//wire [7:0] W = {8{sx[7:0]==sy[7:0]}};
//wire [7:0] A = {8{sx[7:5]==3'h2 && sy[7:5]==3'h2}};

localparam	WHITE	= {8'd255 , 8'd255 , 8'd255 };//{B,G,R}
localparam	YELLOW	= {8'd0   , 8'd255 , 8'd255 };
localparam	CYAN	= {8'd255 , 8'd255 , 8'd0   };
localparam	GREEN	= {8'd0   , 8'd255 , 8'd0   };
localparam	MAGENTA	= {8'd255 , 8'd0   , 8'd255 };
localparam	RED		= {8'd0   , 8'd0   , 8'd255 };
localparam	BLUE	= {8'd255 , 8'd0   , 8'd0   };
localparam	BLACK	= {8'd0   , 8'd0   , 8'd0   };


// Vector processor for shader operations
wire vp_start, vp_busy, vp_done, vp_result_valid;
wire [3:0] vp_operation;
wire [63:0] vp_vec_a, vp_vec_b, vp_result;
wire [15:0] vp_scalar;

vector_processor vpu (
    .clk(clk),
    .rst_n(1'b1),
    .start(vp_start),
    .operation(vp_operation),
    .busy(vp_busy),
    .done(vp_done),
    .vec_a(vp_vec_a),
    .vec_b(vp_vec_b),
    .scalar(vp_scalar),
    .result(vp_result),
    .result_valid(vp_result_valid)
);

// Shader pipeline for generating colors
wire shader_color_valid;
shader_pipeline shader_pipe (
    .clk(clk),
    .rst_n(1'b1),
    .pixel_x(sx),
    .pixel_y(sy),
    .pixel_valid(de),
    .shader_select(shader_select),
    .red_out(red),
    .green_out(green),
    .blue_out(blue),
    .color_valid(shader_color_valid),
    .vp_start(vp_start),
    .vp_operation(vp_operation),
    .vp_vec_a(vp_vec_a),
    .vp_vec_b(vp_vec_b),
    .vp_scalar(vp_scalar),
    .vp_busy(vp_busy),
    .vp_done(vp_done),
    .vp_result(vp_result),
    .vp_result_valid(vp_result_valid)
);

//reg [7:0] red, green, blue;

//localparam H_RES = 640;  // horizontal screen resolution
//localparam V_RES = 480;  // vertical screen resolution

//reg frame;  // high for one clock tick at the start of vertical blanking
//always @(posedge clk)  frame = (sy == V_RES && sx == 0);

//localparam FRAME_NUM = 1;  // slow-mo: animate every N frames
//reg [$clog2(FRAME_NUM):0] cnt_frame;  // frame counter

//always @(posedge clk) begin
//    if (frame) cnt_frame <= (cnt_frame == FRAME_NUM-1) ? 0 : cnt_frame + 1;
//end
//localparam CORDW = 10;
//localparam Q_SIZE = 200;   // size in pixels
//reg [CORDW-1:0] qx, qy;  // position (origin at top left)
//reg qdx, qdy;            // direction: 0 is right/down
//reg [CORDW-1:0] qs = 2;   // speed in pixels/frame


//always @(posedge clk) begin
//    if (frame && cnt_frame == 0) begin

//        if (qdx == 0) begin  // moving right
//            if (qx + Q_SIZE + qs >= H_RES-1) begin  // hitting right of screen?
//                qx <= H_RES - Q_SIZE - 1;  // move right as far as we can
//                qdx <= 1;  // move left next frame
//            end else qx <= qx + qs;  // continue moving right
//        end else begin  // moving left
//            if (qx < qs) begin  // hitting left of screen?
//                qx <= 0;  // move left as far as we can
//                qdx <= 0;  // move right next frame
//            end else qx <= qx - qs;  // continue moving left
//        end


//        if (qdy == 0) begin  // moving down
//            if (qy + Q_SIZE + qs >= V_RES-1) begin  // hitting bottom of screen?
//                qy <= V_RES - Q_SIZE - 1;  // move down as far as we can
//                qdy <= 1;  // move up next frame
//            end else qy <= qy + qs;  // continue moving down
//        end else begin  // moving up
//            if (qy < qs) begin  // hitting top of screen?
//                qy <= 0;  // move up as far as we can
//                qdy <= 0;  // move down next frame
//            end else qy <= qy - qs;  // continue moving up
//        end
//    end
//end

//reg square;
//always @(posedge clk) begin
//    square = (sx >= qx) && (sx < qx + Q_SIZE) && (sy >= qy) && (sy < qy + Q_SIZE);
//end


//always @(posedge clk) begin
//    red <= (square) ? 8'd0 : 8'd0;
//    green <= (square) ? 8'd0 : 8'd0;
//    blue <= (square) ? 8'd255 : 8'd0;
//end


////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(clk), .VD(red  ), .CD(2'b00)        , .VDE(de), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(clk), .VD(green), .CD(2'b00)        , .VDE(de), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(clk), .VD(blue ), .CD({vsync,hsync}), .VDE(de), .TMDS(TMDS_blue));

////////////////////////////////////////////////////////////////////////
wire clk_TMDS; 
wire PLL_CLKFX;  // 25MHz x 10 = 250MHz



    Gowin_rPLL rPLL(
        .clkout(PLL_CLKFX), //output clkout
        .clkin(clk) //input clkin
    );


BUFG uut(
    .O(clk_TMDS),
    .I(PLL_CLKFX)
);

////////////////////////////////////////////////////////////////////////
reg [3:0] TMDS_mod10=0;  // modulus 10 counter
reg [9:0] TMDS_shift_red=0, TMDS_shift_green=0, TMDS_shift_blue=0;
reg TMDS_shift_load=0;
always @(posedge clk_TMDS) TMDS_shift_load <= (TMDS_mod10==4'd9);

always @(posedge clk_TMDS)
begin
	TMDS_shift_red   <= TMDS_shift_load ? TMDS_red   : TMDS_shift_red  [9:1];
	TMDS_shift_green <= TMDS_shift_load ? TMDS_green : TMDS_shift_green[9:1];
	TMDS_shift_blue  <= TMDS_shift_load ? TMDS_blue  : TMDS_shift_blue [9:1];	
	TMDS_mod10 <= (TMDS_mod10==4'd9) ? 4'd0 : TMDS_mod10+4'd1;
end

TLVDS_OBUF   OBUFDS_red (
    .O(TMDSp[2]),
    .OB(TMDSn[2]),
    .I(TMDS_shift_red[0])
);

TLVDS_OBUF   OBUFDS_green (
    .O(TMDSp[1]),
    .OB(TMDSn[1]),
    .I(TMDS_shift_green[0])
);

TLVDS_OBUF  OBUFDS_blue (
    .O(TMDSp[0]),
    .OB(TMDSn[0]),
    .I(TMDS_shift_blue[0])
);

TLVDS_OBUF  OBUFDS_clock (
    .O(TMDSp_clock),
    .OB(TMDSn_clock),
    .I(clk)
);


endmodule

