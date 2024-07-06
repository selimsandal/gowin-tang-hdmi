module gw_gao(
    \CounterX[9] ,
    \CounterX[8] ,
    \CounterX[7] ,
    \CounterX[6] ,
    \CounterX[5] ,
    \CounterX[4] ,
    \CounterX[3] ,
    \CounterX[2] ,
    \CounterX[1] ,
    \CounterX[0] ,
    \CounterY[9] ,
    \CounterY[8] ,
    \CounterY[7] ,
    \CounterY[6] ,
    \CounterY[5] ,
    \CounterY[4] ,
    \CounterY[3] ,
    \CounterY[2] ,
    \CounterY[1] ,
    \CounterY[0] ,
    \red[7] ,
    \red[6] ,
    \red[5] ,
    \red[4] ,
    \red[3] ,
    \red[2] ,
    \red[1] ,
    \red[0] ,
    \green[7] ,
    \green[6] ,
    \green[5] ,
    \green[4] ,
    \green[3] ,
    \green[2] ,
    \green[1] ,
    \green[0] ,
    \blue[7] ,
    \blue[6] ,
    \blue[5] ,
    \blue[4] ,
    \blue[3] ,
    \blue[2] ,
    \blue[1] ,
    \blue[0] ,
    hSync,
    vSync,
    clk_TMDS,
    clk,
    tms_pad_i,
    tck_pad_i,
    tdi_pad_i,
    tdo_pad_o
);

input \CounterX[9] ;
input \CounterX[8] ;
input \CounterX[7] ;
input \CounterX[6] ;
input \CounterX[5] ;
input \CounterX[4] ;
input \CounterX[3] ;
input \CounterX[2] ;
input \CounterX[1] ;
input \CounterX[0] ;
input \CounterY[9] ;
input \CounterY[8] ;
input \CounterY[7] ;
input \CounterY[6] ;
input \CounterY[5] ;
input \CounterY[4] ;
input \CounterY[3] ;
input \CounterY[2] ;
input \CounterY[1] ;
input \CounterY[0] ;
input \red[7] ;
input \red[6] ;
input \red[5] ;
input \red[4] ;
input \red[3] ;
input \red[2] ;
input \red[1] ;
input \red[0] ;
input \green[7] ;
input \green[6] ;
input \green[5] ;
input \green[4] ;
input \green[3] ;
input \green[2] ;
input \green[1] ;
input \green[0] ;
input \blue[7] ;
input \blue[6] ;
input \blue[5] ;
input \blue[4] ;
input \blue[3] ;
input \blue[2] ;
input \blue[1] ;
input \blue[0] ;
input hSync;
input vSync;
input clk_TMDS;
input clk;
input tms_pad_i;
input tck_pad_i;
input tdi_pad_i;
output tdo_pad_o;

wire \CounterX[9] ;
wire \CounterX[8] ;
wire \CounterX[7] ;
wire \CounterX[6] ;
wire \CounterX[5] ;
wire \CounterX[4] ;
wire \CounterX[3] ;
wire \CounterX[2] ;
wire \CounterX[1] ;
wire \CounterX[0] ;
wire \CounterY[9] ;
wire \CounterY[8] ;
wire \CounterY[7] ;
wire \CounterY[6] ;
wire \CounterY[5] ;
wire \CounterY[4] ;
wire \CounterY[3] ;
wire \CounterY[2] ;
wire \CounterY[1] ;
wire \CounterY[0] ;
wire \red[7] ;
wire \red[6] ;
wire \red[5] ;
wire \red[4] ;
wire \red[3] ;
wire \red[2] ;
wire \red[1] ;
wire \red[0] ;
wire \green[7] ;
wire \green[6] ;
wire \green[5] ;
wire \green[4] ;
wire \green[3] ;
wire \green[2] ;
wire \green[1] ;
wire \green[0] ;
wire \blue[7] ;
wire \blue[6] ;
wire \blue[5] ;
wire \blue[4] ;
wire \blue[3] ;
wire \blue[2] ;
wire \blue[1] ;
wire \blue[0] ;
wire hSync;
wire vSync;
wire clk_TMDS;
wire clk;
wire tms_pad_i;
wire tck_pad_i;
wire tdi_pad_i;
wire tdo_pad_o;
wire tms_i_c;
wire tck_i_c;
wire tdi_i_c;
wire tdo_o_c;
wire [9:0] control0;
wire gao_jtag_tck;
wire gao_jtag_reset;
wire run_test_idle_er1;
wire run_test_idle_er2;
wire shift_dr_capture_dr;
wire update_dr;
wire pause_dr;
wire enable_er1;
wire enable_er2;
wire gao_jtag_tdi;
wire tdo_er1;

IBUF tms_ibuf (
    .I(tms_pad_i),
    .O(tms_i_c)
);

IBUF tck_ibuf (
    .I(tck_pad_i),
    .O(tck_i_c)
);

IBUF tdi_ibuf (
    .I(tdi_pad_i),
    .O(tdi_i_c)
);

OBUF tdo_obuf (
    .I(tdo_o_c),
    .O(tdo_pad_o)
);

GW_JTAG  u_gw_jtag(
    .tms_pad_i(tms_i_c),
    .tck_pad_i(tck_i_c),
    .tdi_pad_i(tdi_i_c),
    .tdo_pad_o(tdo_o_c),
    .tck_o(gao_jtag_tck),
    .test_logic_reset_o(gao_jtag_reset),
    .run_test_idle_er1_o(run_test_idle_er1),
    .run_test_idle_er2_o(run_test_idle_er2),
    .shift_dr_capture_dr_o(shift_dr_capture_dr),
    .update_dr_o(update_dr),
    .pause_dr_o(pause_dr),
    .enable_er1_o(enable_er1),
    .enable_er2_o(enable_er2),
    .tdi_o(gao_jtag_tdi),
    .tdo_er1_i(tdo_er1),
    .tdo_er2_i(1'b0)
);

gw_con_top  u_icon_top(
    .tck_i(gao_jtag_tck),
    .tdi_i(gao_jtag_tdi),
    .tdo_o(tdo_er1),
    .rst_i(gao_jtag_reset),
    .control0(control0[9:0]),
    .enable_i(enable_er1),
    .shift_dr_capture_dr_i(shift_dr_capture_dr),
    .update_dr_i(update_dr)
);

ao_top u_ao_top(
    .control(control0[9:0]),
    .data_i({\CounterX[9] ,\CounterX[8] ,\CounterX[7] ,\CounterX[6] ,\CounterX[5] ,\CounterX[4] ,\CounterX[3] ,\CounterX[2] ,\CounterX[1] ,\CounterX[0] ,\CounterY[9] ,\CounterY[8] ,\CounterY[7] ,\CounterY[6] ,\CounterY[5] ,\CounterY[4] ,\CounterY[3] ,\CounterY[2] ,\CounterY[1] ,\CounterY[0] ,\red[7] ,\red[6] ,\red[5] ,\red[4] ,\red[3] ,\red[2] ,\red[1] ,\red[0] ,\green[7] ,\green[6] ,\green[5] ,\green[4] ,\green[3] ,\green[2] ,\green[1] ,\green[0] ,\blue[7] ,\blue[6] ,\blue[5] ,\blue[4] ,\blue[3] ,\blue[2] ,\blue[1] ,\blue[0] ,hSync,vSync,clk_TMDS}),
    .clk_i(clk)
);

endmodule
