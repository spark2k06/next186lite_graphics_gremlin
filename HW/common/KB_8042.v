//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: KB_8042.v
// Description: Part of the Next186 SoC PC project, keyboard/mouse PS2 controller
//		Simplified 8042 implementation
// Version 1.0
// Creation date: Jan2013
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2013 Nicolae Dumitrache
// 
// This source file may be used and distributed without 
// restriction provided that this copyright statement is not 
// removed from the file and that any derivative work contains 
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it 
// and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any 
// later version. 
// 
// This source is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
// PURPOSE. See the GNU Lesser General Public License for more 
// details. 
// 
// You should have received a copy of the GNU Lesser General 
// Public License along with this source; if not, download it 
// from http://www.opencores.org/lgpl.shtml 
// 
///////////////////////////////////////////////////////////////////////////////////
// Additional Comments: 
//
// http://www.computer-engineering.org/ps2keyboard/
// http://wiki.osdev.org/%228042%22_PS/2_Controller
// http://wiki.osdev.org/Mouse_Input
//
//	Primary connection
//		NET "PS2_CLK1" LOC = "W12" | IOSTANDARD = LVCMOS33 | DRIVE = 8 | SLEW = SLOW ;
//		NET "PS2_DATA1" LOC = "V11" | IOSTANDARD = LVCMOS33 | DRIVE = 8 | SLEW = SLOW ;
//	Secondary connection (requires Y-splitter cable)
//		NET "PS2_CLK2" LOC = "U11" | IOSTANDARD = LVCMOS33 | DRIVE = 8 | SLEW = SLOW ;
//		NET "PS2_DATA2" LOC = "Y12" | IOSTANDARD = LVCMOS33 | DRIVE = 8 | SLEW = SLOW ;
//////////////////////////////////////////////////////////////////////////////////
// 12Feb2018 - fix KB connection issue
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module KB_Mouse_8042(
    input CS,
	 input WR,
    input cmd,			// 0x60 = data, 0x64 = cmd
	 input [7:0]din,
	 output [7:0]dout, 
	 input clk,			// cpu CLK
	 output I_KB,		// interrupt keyboard
	 output I_MOUSE,  // interrupt mouse
	 output reg CPU_RST = 0,
	 inout PS2_CLK1,
	 inout PS2_CLK2,
	 inout PS2_DATA1,
	 inout PS2_DATA2,
	 output reg [1:0] monochrome_switcher,
	 output reg [1:0] cpu_speed_switcher,
	 output reg kbd_mreset,
	 output reg kbd_creset,
	 output reg nmi_button,
	 input cpu_speed_io,
	 input [1:0] cpu_speed,
	 input  wire joy_up,
	 input  wire joy_down,
	 input  wire joy_left,
	 input  wire joy_right,
	 input  wire joy_fire1,
	 input  wire joy_fire2,
	 input coreset
	 
    );
	 
	 initial begin
        monochrome_switcher = 2'b00;
		  nmi_button = 1'b0;
		  cpu_speed_switcher = 2'd1;
		  kbd_mreset = 1'b1;
		  kbd_creset = 1'b1;
    end
	 
//	status bit5 = MOBF (mouse to host buffer full - with OBF), bit4=INH, bit2(1-initialized ok), bit1(IBF-input buffer full - host to kb/mouse), bit0(OBF-output buffer full - kb/mouse to host)
	reg [3:0]cmdbyte = 4'b1100; // EN2,EN,INT2,INT
	reg wcfg = 0;	// write config byte
	reg next_mouse = 0;
	reg ctl_outb = 0;
	reg [9:0]wr_data;
	reg [7:0]clkdiv128 = 0;
	reg [7:0]cnt100us = 0; // single delay counter for both kb and mouse
	reg wr_mouse = 0;
	reg wr_kb = 0;
	reg rd_kb = 0;
	reg rd_mouse = 0;
	reg OBF = 0;
	reg MOBF = 0;
	reg [7:0]s_data;
	reg ctrl_pressed = 0;
	reg alt_pressed = 0;
	wire [5:0]joy_map;
	reg [5:0]joy_map_aux = 1'b111111;
	reg [5:0]joy_map_changes = 0;	
	reg kbd_mreset_req = 1'b0;
	reg kbd_creset_req = 1'b0;
	reg [20:0] monochrome_switcher_req = 0;	
	reg nmi_button_req = 1'b0;

	wire [7:0]kb_data;	
	wire [7:0]mouse_data;
	wire kb_data_out_ready;
	wire kb_data_in_ready;
	wire mouse_data_out_ready;
	wire mouse_data_in_ready;
	wire IBF = ((wr_kb | ~kb_data_in_ready) & ~cmdbyte[2]) | ((wr_mouse  | ~mouse_data_in_ready) & ~cmdbyte[3]);
	wire kb_shift;
	wire mouse_shift;
	
	assign dout = cmd ? {2'b00, MOBF, 1'b1, wcfg, 1'b1, IBF, OBF | MOBF | ctl_outb} : ctl_outb ? {2'b00, cmdbyte[3:2], 2'b00, cmdbyte[1:0]} : s_data; //MOBF ? mouse_data : kb_data;
	assign I_KB = cmdbyte[0] & OBF; 			// INT & OBF
	assign I_MOUSE = cmdbyte[1] & MOBF; 	// INT2 & MOBF
	assign joy_map = {joy_up, joy_down, joy_left, joy_right, joy_fire1, joy_fire2};
	
	PS2Interface Keyboard
	(
		.PS2_CLK(PS2_CLK1),
		.PS2_DATA(PS2_DATA1),
		.clk(clk),
		.rd(rd_kb),
		.wr(wr_kb),
		.data_in(wr_data[0]),
		.data_out(kb_data),
		.data_out_ready(kb_data_out_ready),
		.data_in_ready(kb_data_in_ready),
		.delay100us(cnt100us[7]),
		.data_shift(kb_shift),
		.clk_sample(clkdiv128[7])
	);

	PS2Interface Mouse
	(
		.PS2_CLK(PS2_CLK2),
		.PS2_DATA(PS2_DATA2),
		.clk(clk),
		.rd(rd_mouse),
		.wr(wr_mouse),
		.data_in(wr_data[0]),
		.data_out(mouse_data),
		.data_out_ready(mouse_data_out_ready),
		.data_in_ready(mouse_data_in_ready),
		.delay100us(cnt100us[7]),
		.data_shift(mouse_shift),
		.clk_sample(clkdiv128[7])
	);
	
	always @(posedge clk) begin
		if (kbd_mreset_req) kbd_mreset <= 1'b0;
		if (kbd_creset_req) begin
			kbd_creset <= ~coreset;
			kbd_creset_req <= 1'b0;
		end
		if (nmi_button_req) nmi_button <= 1'b1;
		if (nmi_button) nmi_button <= 1'b0;
		
		if (monochrome_switcher_req != 0) begin			
			if (monochrome_switcher_req == 1) monochrome_switcher <= monochrome_switcher + 1;			
			monochrome_switcher_req <= monochrome_switcher_req + 1;			
		end
		
		if (nmi_button_req) begin
			nmi_button <= 1'b1;
			nmi_button_req <= 1'b0;
		end
		
		
		CPU_RST <= 0;
		if(~kb_data_in_ready) wr_kb <= 1'b0;
		if(~kb_data_out_ready) rd_kb <= 1'b0;
		if(~mouse_data_in_ready) wr_mouse <= 0;
		if(~mouse_data_out_ready) rd_mouse <= 1'b0;
		if(cpu_speed_io) cpu_speed_switcher <= cpu_speed;

		clkdiv128 <= clkdiv128[6:0] + 1'b1;
		if(CS & WR & ~cmd & ~wcfg) cnt100us <= 0; // reset 100us counter for PS2 writing
		else if(!cnt100us[7] & clkdiv128[7]) cnt100us <= cnt100us + 1'b1;
								
		if(~OBF & ~MOBF)
			
			if (~joy_map_changes[0] & joy_map[0] != joy_map_aux[0])
				joy_map_changes[0] <= 1;
			if (~joy_map_changes[1] & joy_map[1] != joy_map_aux[1])
				joy_map_changes[1] <= 1;
			if (~joy_map_changes[2] & joy_map[2] != joy_map_aux[2])
				joy_map_changes[2] <= 1;
			if (~joy_map_changes[3] & joy_map[3] != joy_map_aux[3])
				joy_map_changes[3] <= 1;
			if (~joy_map_changes[4] & joy_map[4] != joy_map_aux[4])
				joy_map_changes[4] <= 1;
			if (~joy_map_changes[5] & joy_map[5] != joy_map_aux[5])
				joy_map_changes[5] <= 1;
		
			if(kb_data_out_ready & ~rd_kb & ~cmdbyte[2]) begin
				OBF <= 1'b1;
												
				if (s_data != 8'he0) begin					
					if (kb_data == 8'h1d) ctrl_pressed = 1'b1;
					if (kb_data == 8'h9d) ctrl_pressed = 1'b0;
					if (kb_data == 8'h38) alt_pressed = 1'b1;
					if (kb_data == 8'hb8) alt_pressed = 1'b0;				
					if (ctrl_pressed == 1'b1 && alt_pressed == 1'b1) begin
						case (kb_data)								
							// NMI (CTRL + ALT + F12)
							8'hd8: nmi_button_req <= 1'b1;
							// MasterReset (CTRL + ALT + BackSpace)
							8'h0e: kbd_mreset_req <= 1'b1;
							// MonochromeRGB (CTRL + ALT + Bloq Despl)
							8'h46: monochrome_switcher_req <= monochrome_switcher_req + 1;
							// CPU Speed -- (CTRL + ALT + KeyPad -)
							8'hca: cpu_speed_switcher <= cpu_speed_switcher < 2'd2 ? cpu_speed_switcher + 2'd1 : cpu_speed_switcher;
							// CPU Speed ++ (CTRL + ALT + KeyPad +)
							8'hce: cpu_speed_switcher <= cpu_speed_switcher > 2'd1 ? cpu_speed_switcher - 2'd1 : cpu_speed_switcher;						
						endcase
					end
				end
				else begin
					if (ctrl_pressed == 1'b1 && alt_pressed == 1'b1) begin
						case (kb_data)															
							// ColdReset (CTRL + ALT + DEL)
							8'h53: kbd_creset_req <= 1'b1;							
						endcase
					end					
				end
				
				s_data <= kb_data;
				
			end
			else if(mouse_data_out_ready & ~rd_mouse & ~cmdbyte[3]) begin
				MOBF <= 1'b1;
				s_data <= mouse_data;
			end
			else if (joy_map_changes[5]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[5] ? 8'h48 : 8'hc8; // Keypad 8
				joy_map_aux[5] <= joy_map[5];
				joy_map_changes[5] <= 0;
			end
			else if (joy_map_changes[4]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[4] ? 8'h50 : 8'hd0; // Keypad 2
				joy_map_aux[4] <= joy_map[4];
				joy_map_changes[4] <= 0;
			end
			else if (joy_map_changes[3]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[3] ? 8'h4b : 8'hcb; // Keypad 4
				joy_map_aux[3] <= joy_map[3];
				joy_map_changes[3] <= 0;
			end
			else if (joy_map_changes[2]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[2] ? 8'h4d : 8'hcd; // Keypad 6
				joy_map_aux[2] <= joy_map[2];
				joy_map_changes[2] <= 0;
			end	
			else if (joy_map_changes[1]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[1] ? 8'h52 : 8'hd2; // Keypad 0
				joy_map_aux[1] <= joy_map[1];
				joy_map_changes[1] <= 0;
			end				
			else if (joy_map_changes[0]) begin
				OBF <= 1'b1;
				s_data <= joy_map_aux[0] ? 8'h53 : 8'hd3; // Keypad .	
				joy_map_aux[0] <= joy_map[0];
				joy_map_changes[0] <= 0;
			end				
		
		if(kb_shift | mouse_shift) wr_data <= {1'b1, wr_data[9:1]};
		
		if(CS) 
			if(WR)
				if(cmd)	// 0x64 write
					case(din)
						8'h20: ctl_outb <= 1'b1;	// read config byte
						8'h60: wcfg <= 1;			// write config byte
						8'ha7: cmdbyte[3] <= 1;	// disable mouse
						8'ha8: cmdbyte[3] <= 0;	// enable mouse
						8'had: cmdbyte[2] <= 1;	// disable kb
						8'hae: cmdbyte[2] <= 0;	// enable kb
						8'hd4: next_mouse <= 1;	//	write next byte to mouse
						/*8'hf0, 8'hf2, 8'hf4, 8'hf6, 8'hf8, 8'hfa, 8'hfc,*/ 8'hfe: CPU_RST <= 1; // CPU reset
					endcase 
				else begin	// 0x60 write
					if(wcfg) cmdbyte <= {din[5:4], din[1:0]};
					else begin
						next_mouse <= 0;
						wr_mouse <= next_mouse;
						wr_kb <= ~next_mouse;
						wr_data <= {~^din, din, 1'b0};
					end
					wcfg <= 0;
				end
			else 	// read data
				if(~cmd) begin	
					ctl_outb <= 1'b0;
					if(!ctl_outb) begin
						OBF <= 1'b0;
						MOBF <= 1'b0;
						rd_kb <= OBF;
						rd_mouse <= MOBF;
					end
				end
	end
endmodule


module PS2Interface(
	 inout PS2_CLK,
	 inout PS2_DATA,
	 input clk,
	 input rd,				// enable PS2 data reading
	 input wr,				// can write data from controller to PS2
	 input data_in,		// data from controller
	 input delay100us,
	 output [7:0]data_out,	// data from PS2
	 output reg data_out_ready = 1,	// PS2 received data ready
	 output reg data_in_ready = 1,	// PS2 sent data ready
	 output data_shift,
	 input clk_sample
	);
	
	initial data_out_ready = 1;
	initial data_in_ready = 1;
	
	reg [1:0]s_clk = 2'b11;
	wire ps2_clk_fall = s_clk == 2'b10;
	reg [9:0]data = 0;
	reg rd_progress = 1'b0;
	reg s_ps2_clk = 1'b1;
	reg rclk = 1'b1;
	reg rdata = 1'b1;
	reg s_ps2_data = 1'b1;
	
	assign PS2_CLK = rclk ? 1'bz : 1'b0;
	assign PS2_DATA = rdata ? 1'bz : 1'b0;
	assign data_out = data[7:0];
	assign data_shift = ~data_in_ready && delay100us && ps2_clk_fall;

	always @(posedge clk) begin
		if(clk_sample) begin
			s_ps2_clk <= PS2_CLK; 	// debounce PS2 clock and data
			s_ps2_data <= PS2_DATA & rdata;;
		end
		
		s_clk <= {s_clk[0], s_ps2_clk};
		if(data_out_ready) rd_progress <= 1'b0;

		if(~data_in_ready) begin	// send data to PS2
			if(data_shift) data_in_ready <= data_in ^ s_ps2_data;
		end else if(wr && ~rd_progress) data_in_ready <= 1'b0;	// initiate data sending to PS2
		else if(~data_out_ready) begin	// receive data from PS2
			if(ps2_clk_fall) begin
				rd_progress <= 1'b1;
				if(rd_progress) {data, data_out_ready} <= {s_ps2_data, data[9:1], ~data[0]}; // receive is ended by data[9]
				else data <= 10'b0111111111;
			end
		end else if(rd) data_out_ready <= 1'b0; // initiate data receiving from PS2

		rclk <= ((~data_out_ready & data_in_ready) | (~data_in_ready & delay100us));
		rdata <= (data_in_ready | data_in | ~delay100us);
	end
endmodule
