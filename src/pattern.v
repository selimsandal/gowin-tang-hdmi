module pattern (
    input clk,
    input wire [9:0] sx, sy,
    output reg [7:0] red, green, blue
);
localparam H_RES = 640;  // horizontal screen resolution
localparam V_RES = 480;  // vertical screen resolution

reg frame;  // high for one clock tick at the start of vertical blanking
always @(posedge clk)  frame = (sy == V_RES && sx == 0);

localparam FRAME_NUM = 1;  // slow-mo: animate every N frames
reg [$clog2(FRAME_NUM):0] cnt_frame;  // frame counter

always @(posedge clk) begin
    if (frame) cnt_frame <= (cnt_frame == FRAME_NUM-1) ? 0 : cnt_frame + 1;
end
localparam CORDW = 10;
localparam Q_SIZE = 200;   // size in pixels
reg [CORDW-1:0] qx, qy;  // position (origin at top left)
reg qdx, qdy;            // direction: 0 is right/down
reg [CORDW-1:0] qs = 2;   // speed in pixels/frame


always @(posedge clk) begin
    if (frame && cnt_frame == 0) begin
        // horizontal position
        if (qdx == 0) begin  // moving right
            if (qx + Q_SIZE + qs >= H_RES-1) begin  // hitting right of screen?
                qx <= H_RES - Q_SIZE - 1;  // move right as far as we can
                qdx <= 1;  // move left next frame
            end else qx <= qx + qs;  // continue moving right
        end else begin  // moving left
            if (qx < qs) begin  // hitting left of screen?
                qx <= 0;  // move left as far as we can
                qdx <= 0;  // move right next frame
            end else qx <= qx - qs;  // continue moving left
        end

        // vertical position
        if (qdy == 0) begin  // moving down
            if (qy + Q_SIZE + qs >= V_RES-1) begin  // hitting bottom of screen?
                qy <= V_RES - Q_SIZE - 1;  // move down as far as we can
                qdy <= 1;  // move up next frame
            end else qy <= qy + qs;  // continue moving down
        end else begin  // moving up
            if (qy < qs) begin  // hitting top of screen?
                qy <= 0;  // move up as far as we can
                qdy <= 0;  // move down next frame
            end else qy <= qy - qs;  // continue moving up
        end
    end
end

reg square;
always @(posedge clk) begin
    square = (sx >= qx) && (sx < qx + Q_SIZE) && (sy >= qy) && (sy < qy + Q_SIZE);
end


always @(posedge clk) begin
    red <= (square) ? 8'd0 : 8'd0;
    green <= (square) ? 8'd0 : 8'd0;
    blue <= (square) ? 8'd255 : 8'd0;
end

endmodule