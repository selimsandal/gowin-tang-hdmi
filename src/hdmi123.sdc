//Copyright (C)2014-2025 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2025-08-30 14:36:16
create_clock -name clk -period 40 -waveform {0 20} [get_ports {clk}] -add
