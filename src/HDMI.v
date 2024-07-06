// (c) fpga4fun.com & KNJN LLC 2013-2023

////////////////////////////////////////////////////////////////////////
module HDMI_test(
	input clk,  // 25MHz
	output [2:0] TMDSp, TMDSn,
	output TMDSp_clock, TMDSn_clock
);
////////////////////////////////////////////////////////////////////////
reg [9:0] CounterX=0, CounterY=0;
reg hSync, vSync, DrawArea;
always @(posedge clk) DrawArea <= (CounterX<640) && (CounterY<480);

always @(posedge clk) CounterX <= (CounterX==799) ? 0 : CounterX+1;
always @(posedge clk) if(CounterX==799) CounterY <= (CounterY==524) ? 0 : CounterY+1;

always @(posedge clk) hSync <= (CounterX>=656) && (CounterX<752);
always @(posedge clk) vSync <= (CounterY>=490) && (CounterY<492);

////////////////
wire [7:0] W = {8{CounterX[7:0]==CounterY[7:0]}};
wire [7:0] A = {8{CounterX[7:5]==3'h2 && CounterY[7:5]==3'h2}};
reg [7:0] red, green, blue;

//always @(posedge clk) begin
//    if (CounterY >= 400) begin  // black outside the flag area
//        red = 4'h0;
//        green = 4'h0;
//        blue = 4'h0;
//    end else if (CounterY > 160 && CounterY < 240) begin  // yellow cross horizontal
//        red = 4'hF;
//        green = 4'hC;
//        blue = 4'h0;
//    end else if (CounterX > 200 && CounterX < 280) begin  // yellow cross vertical
//        red = 4'hF;
//        green = 4'hC;
//        blue = 4'h0;
//    end else begin  // blue flag background
//        red = 4'h0;
//        green = 4'h6;
//        blue = 4'hA;
//    end
//end

always @(posedge clk) red <= ({CounterX[5:0] & {6{CounterY[4:3]==~CounterX[4:3]}}, 2'b00} | W) & ~A;
always @(posedge clk) green <= (CounterX[7:0] & {8{CounterY[6]}} | W) & ~A;
always @(posedge clk) blue <= CounterY[7:0] | W | A;

////////////////////////////////////////////////////////////////////////
wire [9:0] TMDS_red, TMDS_green, TMDS_blue;
TMDS_encoder encode_R(.clk(clk), .VD(red  ), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_red));
TMDS_encoder encode_G(.clk(clk), .VD(green), .CD(2'b00)        , .VDE(DrawArea), .TMDS(TMDS_green));
TMDS_encoder encode_B(.clk(clk), .VD(blue ), .CD({vSync,hSync}), .VDE(DrawArea), .TMDS(TMDS_blue));

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

