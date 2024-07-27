module simple480p(
    input  wire clk, // pixel clock
    output reg [9:0] sx, // horizontal screen position
    output reg [9:0] sy,  // vertical screen position
    output reg       hsync,  // horizontal sync
    output reg       vsync,  // vertical sync
    output reg       de  // vertical data enable
);


always @(posedge clk) de <= (sx<640) && (sy<480);

always @(posedge clk) sx <= (sx==799) ? 0 : sx+1;
always @(posedge clk) if(sx==799) sy <= (sy==524) ? 0 : sy+1;

always @(posedge clk) hsync <= (sx>=656) && (sx<752);
always @(posedge clk) vsync <= (sy>=490) && (sy<492);

endmodule