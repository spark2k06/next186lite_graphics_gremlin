//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: ddr_186.v
// Description: Part of the Next186 SoC PC project, main system, RAM interface
// Version 2.0
// Creation date: Apr2014
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2012 Nicolae Dumitrache
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
// 25Apr2012 - added SD card SPI support
// 15May2012 - added PIT 8253 (sound + timer INT8)
// 24May2012 - added PIC 8259  
// 28May2012 - RS232 boot loader does not depend on CPU speed anymore (uses timer0)
//	01Feb2013 - ADD 8042 PS2 Keyboard & Mouse controller
// 27Feb2013 - ADD RTC
// 04Apr2013 - ADD NMI, port 3bc for 8 leds
//
// Feb2014 - ported for SDRAM, added USB host serial communication
// 		   - added video modes 0dh, 12h
//		   - support for ModeX
// 28Dec2016 - ZX-UNO Port by DistWave (SRAM Controller)
// 27Nov2021 - Graphics Gremlin Integration by @spark2k06
//////////////////////////////////////////////////////////////////////////////////

/* ----------------- implemented ports -------------------
0001 - bit0=write RS232, bit1=write USB host out, bit2=USB host reset
	  - bit0=auto cache flush, on WORD write only
	  
0002 - 32 bit CPU data port R/W, lo first
0003 - 32 bit CPU command port W
		16'b00000cvvvvvvvvvv = set r/w pointer - 256 32bit integers, 1024 instructions. c=1 for code write, 0 for data read/write
		16'b100wwwvvvvvvvvvv = run ip - 1024 instructions, 3 bit data window offs

0021, 00a1 - interrupt controller data ports. R/W interrupt mask, 1disabled/0enabled (bit0=timer, bit1=keyboard, bit3=RTC, bit4=mouse) 

0040-0043 - PIT 8253 ports

0x60, 0x64 - 8042 keyboard/mouse data and cfg

0061 - bits1:0 speaker on/off (write only)

0070 - RTC (16bit write only counter value). RTC is incremented with 1Mhz and at set value sends INT70h, then restart from 0
		 When set, it restarts from 0. If the set value is 0, it will send INT70h only once, if it was not already 0
			
080h-08fh - memory map
								
0200h-020fh - joystick port - returns 0ffh


03C0 - VGA mode 
		index 10h:
			bit0 = graphic(1)/text(0)
			bit3 = text mode flash enabled(1)
			bit4 = half mode (EGA)
			bit6 = 320x200(1)/640x480(0)
		index 13h: bit[3:0] = hrz pan

03C4, 03C5 (Sequencer registers) - idx2[3:0] = write plane, idx4[3]=0 for planar (rw)

03C6 - DAC mask (rw)
03C7 - DAC read index (rw)
03C8 - DAC write index (rw)
03C9 - DAC color (rw)
03CB - font: write WORD = set index (8 bit), r/w BYTE = r/w font data

03CE, 03CF (Graphics registers) (rw)
	0: setres <= din[3:0];
	1: enable_setres <= din[3:0];
	2: color_compare <= din[3:0];
	3: logop <= din[4:3];
	4: rplane <= din[1:0];
	5: rwmode <= {din[3], din[1:0]};
	7: color_dont_care <= din[3:0];
	8: bitmask <= din[7:0]; (1=CPU, 0=latch)

03DA - read VGA status, bit0=1 on vblank or hblank, bit1=RS232in, bit2=USB host serial in, bit3=1 on vblank, bit4=sound queue full, bit5=DSP32 halt, bit7=1 always, bit15:8=SD SPI byte read
		 write bit7=SD SPI MOSI bit, SPI CLK 0->1 (BYTE write only), bit8 = SD card chip select (WORD write only)
		 also reset the 3C0 port index flag

03B4, 03D4 - VGA CRT write index:  
										06h: bit 7=1 for 200lines, 0 for 240 lines
										0Ah(bit 5 only): hide cursor
										0Ch: HI screen offset
										0Dh: LO screen offset
										0Eh: HI cursor pos
										0Fh: LO cursor pos
										13h: scan line offset
03B5, 03D5 - VGA CRT read/write data

*/


`timescale 1ns / 1ps

module system_2MB
	(
		 input CLK_50MHZ,
		 output [20:0]SRAM_ADDR,
		 inout [7:0]SRAM_DATA,
		 output SRAM_WE_n,
		 output wire [5:0]VGA_R,
		 output wire [5:0]VGA_G,
		 output wire [5:0]VGA_B,
		 output wire VGA_HSYNC,
		 output wire VGA_VSYNC,
		 output LED,
		 output reg SD_n_CS = 1,
		 output wire SD_DI,
		 output reg SD_CK = 0,
		 input SD_DO,
		 
		 output AUD_L,
		 output AUD_R,
	 	 inout PS2_CLK1,
		 inout PS2_CLK2,
		 inout PS2_DATA1,
		 inout PS2_DATA2,
		 output wire [1:0] monochrome_switcher
    );
		 
	wire [15:0]sys_DIN;
	wire [15:0]sys_DOUT;
	wire sys_rd_data_valid;
	wire sys_wr_data_valid;   
	wire [12:0]waddr;
	wire [31:0] DOUT;
	wire [15:0]CPU_DOUT;
	wire [15:0]PORT_ADDR;
	wire [31:0] DRAM_dout;
	wire [20:0] ADDR;
	wire IORQ;
	wire WR;
	wire INTA;
	wire WORD;
	wire [3:0] RAM_WMASK;
	
	wire VRAM8_ENABLE;
	wire [18:0] VRAM8_ADDR;	
	wire [7:0] VRAM8_DOUT;
	
	
	reg hblnk = 0; 			// TODO: Remove this dependency (Original VGA driver)
	reg vblnk = 0;				// TODO: Remove this dependency (Original VGA driver)
	reg [9:0]hcount = 0;		// TODO: Remove this dependency (Original VGA driver)
	reg [9:0]vcount = 0;		// TODO: Remove this dependency (Original VGA driver)
	
	
	wire clk_vga;
	wire clk_25;
	wire clk_9_524;
	wire clk_4_762;	
	wire CPU_CE;	// CPU clock enable
	wire CE;
	wire CE_186;
	wire ddr_rd; 
	wire ddr_wr;
	wire TIMER_OE = PORT_ADDR[15:2] == 14'b00000000010000;	//   40h..43h	
	wire LED_PORT = PORT_ADDR[15:0] == 16'h03bc;
	wire SPEAKER_PORT = PORT_ADDR[15:0] == 16'h0061;
	wire MEMORY_MAP = PORT_ADDR[15:4] == 12'h008;	
	wire RS232_OE = PORT_ADDR[15:0] == 16'h0001;
	wire INPUT_STATUS_OE = PORT_ADDR[15:0] == 16'h03da;		// TODO: Remove this dependency (Original VGA driver)
	wire RTC_SELECT = PORT_ADDR[15:0] == 16'h0070;
	wire PIC_OE = PORT_ADDR[15:8] == 8'h00 && PORT_ADDR[6:0] == 7'b0100001;	// 21h, a1h
	wire KB_OE = PORT_ADDR[15:4] == 12'h006 && {PORT_ADDR[3], PORT_ADDR[1:0]} == 3'b000; // 60h, 64h
	wire JOYSTICK = PORT_ADDR[15:4] == 12'h020; // 0x200-0x20f	
	wire [15:0]PORT_IN;
	wire [7:0]TIMER_DOUT;
	wire [7:0]KB_DOUT;
	wire [7:0]PIC_DOUT;
	
	wire CRTC_OE;
	wire [7:0] CRTC_DOUT;
	
	wire HALT;

	reg [1:0]command = 0;
	reg [1:0]s_ddr_rd = 0;
	reg [1:0]s_ddr_wr = 0;

	reg s_RS232_DCE_RXD;
	reg s_RS232_HOST_RXD;
	reg [4:0]rstcount = 0;		
	reg [4:0]RTCDIV25 = 0;
	reg [1:0]RTCSYNC = 0;
	reg [15:0]RTC = 0;
	reg [15:0]RTCSET = 0;
	wire RTCEND = RTC == RTCSET;
	wire RTCDIVEND = RTCDIV25 == 24;
	reg [12:0]cache_hi_addr;
	wire [4:0]memmap;
	wire [4:0]memmap_mux;	
	wire oncursor;
	wire [11:0]cursorpos;
	wire [15:0]scraddr;
	reg flash_on;
	reg speaker_on = 0;	
	
	reg [18:0]sysaddr;
	reg [2:0]auto_flush = 3'b000;

	assign LED = ~SD_n_CS;
	
// SD interface
	reg [7:0]SDI;
	assign SD_DI = CPU_DOUT[7];

	assign PORT_IN[15:8] = 
		({8{INPUT_STATUS_OE}} & SDI);

	assign PORT_IN[7:0] = 							 							 
							 ({8{KB_OE}} & KB_DOUT) |							 
							 ({8{INPUT_STATUS_OE}} & {2'b1x, 1'b0, 1'b0, vblnk, 1'b0, 1'b0, hblnk | vblnk}) | //TODO: Remove this dependency from the original VGA driver
							 ({8{CRTC_OE}} & CRTC_DOUT) |
							 ({8{MEMORY_MAP}} & {3'b000, memmap[4:0]}) |
							 ({8{TIMER_OE}} & TIMER_DOUT) |
							 ({8{PIC_OE}} & PIC_DOUT) |
							 ({8{JOYSTICK}});

    // Sets up the card to generate a video signal
    // that will work with a standard VGA monitor
    // connected to the VGA port.
    parameter MDA_70HZ = 0;    

    wire[7:0] bus_out;

    wire[3:0] video;
    wire[3:0] vga_video;

    // wire composite_on;
    wire thin_font;

    wire[5:0] vga_red;
    wire[5:0] vga_green;
    wire[5:0] vga_blue;

    // Composite mode switch
    //assign composite_on = switch3; (TODO: Test in next version, from the original Graphics Gremlin sources)
	 
    // Thin font switch (TODO: switchable with Keyboard shortcut)    
	 assign thin_font = 1'b0; // Default: No thin font
    	 
    // CGA digital to analog converter
    cga_vgaport vga (
        .clk(clk_vga),
        .video(vga_video),		  
        .red(VGA_R),
        .green(VGA_G),
        .blue(VGA_B)
    );    

    cga cga1 (
        .clk(clk_vga),        
		  .bus_a(PORT_ADDR),
        .bus_ior_l(1'd0),
        .bus_iow_l(1'd0),
        .bus_memr_l(1'd0),
        .bus_memw_l(1'd0),
        .bus_d(CPU_DOUT[7:0]),
        .bus_out(CRTC_DOUT),
        .bus_dir(CRTC_OE),
        .bus_aen(~(IORQ & CPU_CE & WR)),        
        .ram_we_l(VRAM8_ENABLE),
        .ram_a(VRAM8_ADDR),
        .ram_d(VRAM8_DOUT),        
        .dbl_hsync(VGA_HSYNC),
        .vsync(VGA_VSYNC),
        .video(video),
        .dbl_video(vga_video),
        .comp_video(comp_video),
        .thin_font(thin_font)
    );

	defparam cga1.BLINK_MAX = 24'd4772727;

	dcm dcm_system 
	(
		.CLK_IN1(CLK_50MHZ), 
		.CLK_OUT1(clk_vga), 		// 28.571 Mhz (GRAPHICS GREMLIN, VGAPORT, VRAM)
		.CLK_OUT2(clk_25), 		// 25.000 Mhz (RTC, TIMER 8253)
		.CLK_OUT3(clk_9_524), 	// 9.524 Mhz  (SYSCLK x 2 [CPU])
		.CLK_OUT4(clk_4_762) 	// 4.762 Mhz  (SYSCLK, CACHE DDRCLK)
		
    );

	SRAM_8bit SRAM
	(
		.sys_CLK(clk_4_762),							// clock
		.sys_CMD(command),							// 00=nop, 01 = write 256 bytes, 11=read 256 bytes
		.sys_ADDR(sysaddr),							// byte address
		.sys_DIN(sys_DIN),							// data input
		.sys_DOUT(sys_DOUT),							// data output
		.sys_rd_data_valid(sys_rd_data_valid),	// data valid read
		.sys_wr_data_valid(sys_wr_data_valid),	// data valid write
		
		.sram_clk(clk_9_524),
		.sram_n_WE(SRAM_WE_n),						// SRAM #WE
		.sram_ADDR(SRAM_ADDR),						// SRAM address
		.sram_DATA(SRAM_DATA)						// SRAM data
	);
	
	wire MREQ;
   wire CACHE_EN = (ADDR[20:15] != 6'b010100);	
	wire CACHE_MREQ = MREQ & CACHE_EN;

	wire TXTVRAM = (ADDR[19:16] == 4'b1011);
	wire GFXVRAM = (ADDR[19:16] == 4'b1010);
	wire vram_en = (TXTVRAM | GFXVRAM) & MREQ;
	
	wire [31:0] vram_dout;
	wire [31:0] CPU_DIN;
	reg s_cache_mreq;
	assign CPU_DIN	= s_cache_mreq ? DRAM_dout : vram_dout;


	BRAM_15Kx32_2MB VRAM
	(
	  .clka(clk_9_524), // input clka
	  .ena(vram_en), // input ena
	  .wea(RAM_WMASK),
	  .addra(ADDR[15:2]), // input [13 : 0] addra
	  .dina(DOUT),
	  .douta(vram_dout), // output [31 : 0] douta
	  .clkb(clk_vga), // input clka
	  .web(1'b0),
	  .enb(VRAM8_ENABLE),
	  .addrb(VRAM8_ADDR[15:0]), // input [15 : 0] addrb
	  .dinb(8'h0),
	  .doutb(VRAM8_DOUT) // output [7 : 0] doutb  

	);
	
  
  always @(posedge clk_25) begin
  	  	if(RTCDIVEND) RTCDIV25 <= 0;	// real time clock
		else RTCDIV25 <= RTCDIV25 + 1;  
  
		// Temporal H/V position counter. TODO: Remove this dependency (Original VGA driver)
		if(hcount >= 10'd799) begin
			hcount <= 0;
			hblnk <= 0;
		end else begin
			hcount <= hcount + 1;
			hblnk <= (hcount >= 10'd639);
		end
		
		if(hcount == 10'd799) begin			
			  if (vcount >= 10'd520) begin
				vcount <= 0;
				vblnk <= 0;
			end else begin
				vcount <= vcount + 1;				
				vblnk <= (vcount >= 10'd479);
			end			
		end
		
	end		
	
	
	cache_controller_2MB cache_ctl 
	(
		 .addr(ADDR), 
		 .dout(DRAM_dout), 
		 .din(DOUT), 
		 .clk(clk_9_524), 
		 .mreq(CACHE_MREQ), 
		 .wmask(RAM_WMASK),
		 .ce(CE), 
		 .ddr_din(sys_DOUT), 
		 .ddr_dout(sys_DIN), 
		 .ddr_clk(clk_4_762), 
		 .ddr_rd(ddr_rd), 
		 .ddr_wr(ddr_wr),
		 .waddr(waddr),
		 .cache_write_data(sys_rd_data_valid), // read SRAM, write to cache
		 .cache_read_data(sys_wr_data_valid)
		 //.flush(auto_flush == 3'b101)
	);

	wire I_KB;
	wire I_MOUSE;
	wire KB_RST;
	KB_Mouse_8042 KB_Mouse 
	(
		 .CS(IORQ && CPU_CE && KB_OE), // 60h, 64h
		 .WR(WR), 
		 .cmd(PORT_ADDR[2]), // 64h
		 .din(CPU_DOUT[7:0]), 
		 .dout(KB_DOUT), 
		 .clk(clk_9_524), 
		 .I_KB(I_KB), 
		 .I_MOUSE(I_MOUSE), 
		 .CPU_RST(KB_RST), 
		 .PS2_CLK1(PS2_CLK1), 
		 .PS2_CLK2(PS2_CLK2), 
		 .PS2_DATA1(PS2_DATA1), 
		 .PS2_DATA2(PS2_DATA2),
		 .monochrome_switcher(monochrome_switcher)
	);
	
	wire [7:0]PIC_IVECT;
	wire INT;
	wire timer_int;
	PIC_8259 PIC 
	(
		 .CS(PIC_OE && IORQ && CPU_CE), // 21h, a1h
		 .WR(WR), 
		 .din(CPU_DOUT[7:0]), 
		 .dout(PIC_DOUT), 
		 .ivect(PIC_IVECT), 
		 .clk(clk_9_524), 
		 .INT(INT), 
		 .IACK(INTA & CPU_CE), 
		 .I({I_MOUSE, RTCEND, I_KB, timer_int})
    );

	unit186 CPUUnit
	(
		 .INPORT(INTA ? {8'h00, PIC_IVECT} : PORT_IN), 
		 .DIN(CPU_DIN), 
		 .CPU_DOUT(CPU_DOUT),
		 .PORT_ADDR(PORT_ADDR),
		 .DOUT(DOUT), 
		 .ADDR(ADDR), 
		 .WMASK(RAM_WMASK), 
		 .CLK(clk_9_524), 
		 .CE(CE/* & !WAITIO*/), 
		 .CPU_CE(CPU_CE),
		 .CE_186(CE_186),
		 .INTR(INT), 
		 .NMI(1'b0), 
		 .RST(!rstcount[4]), 
		 .INTA(INTA), 
		 .LOCK(LOCK), 
		 .HALT(HALT), 
		 .MREQ(MREQ),
		 .IORQ(IORQ),
		 .WR(WR),
		 .WORD(WORD),
		 
		 .PLANAR(planarreq),
		 .VGA_WPLANE(vga_wplane),
		 .VGA_RPLANE(vga_rplane),
		 .VGA_BITMASK(vga_bitmask),
		 .VGA_RWMODE(vga_rwmode),
		 .VGA_SETRES(vga_setres),
		 .VGA_ENABLE_SETRES(vga_enable_setres),
		 .VGA_LOGOP(vga_logop),
		 .VGA_COLOR_COMPARE(vga_color_compare),
		 .VGA_COLOR_DONT_CARE(vga_color_dont_care)
	);
	
	seg_map_2MB seg_mapper 
	(
		 .CLK(clk_9_524), 
		 .cpuaddr(PORT_ADDR[3:0]), 
		 .cpurdata(memmap), 
		 .cpuwdata(CPU_DOUT[4:0]), 
		 .memaddr(cache_hi_addr[12:8]), 
		 .memdata(memmap_mux), 
		 .WE(MEMORY_MAP & WR & WORD & IORQ & CPU_CE)
   );

	wire timer_spk;
	timer_8253 timer 
	(
		 .CS(TIMER_OE && IORQ && CPU_CE), 
		 .WR(WR), 
		 .addr(PORT_ADDR[1:0]), 
		 .din(CPU_DOUT[7:0]), 
		 .dout(TIMER_DOUT), 
		 .CLK_25(clk_25),		 
		 .clk(clk_9_524), 
		 .out0(timer_int), 
		 .out2(timer_spk)
   );

	always @ (posedge clk_4_762) begin
		
		s_ddr_rd <= {s_ddr_rd[0], ddr_rd};
		s_ddr_wr <= {s_ddr_wr[0], ddr_wr};
		cache_hi_addr <= s_ddr_wr[0] ? waddr : ADDR[20:8];
		sysaddr <= {memmap_mux, cache_hi_addr[7:0], 6'b000000};
		
		if(s_ddr_wr[1]) command <= 2'b01;		// write 256 bytes cache
		else if(s_ddr_rd[1]) command <= 2'b11;		// read 256 bytes cache
		else command <= 2'b00;
	end

	always @ (posedge clk_9_524) begin
		s_cache_mreq <= CACHE_MREQ;
//		s_RS232_DCE_RXD <= RS232_DCE_RXD;
//		s_RS232_HOST_RXD <= RS232_HOST_RXD;
		if(IORQ & CPU_CE) begin
/*			if(WR & RS232_OE) begin
				{RS232_HOST_RST, RS232_HOST_TXD, RS232_DCE_TXD} <= CPU_DOUT[2:0];
				if(WORD) auto_flush[2] <= CPU_DOUT[0];
			end*/			 
			if(WR & SPEAKER_PORT) speaker_on <= &CPU_DOUT[1:0];
		end
// SD
		if(CPU_CE) begin
			SD_CK <= IORQ & INPUT_STATUS_OE & WR & ~WORD;
			if(IORQ & INPUT_STATUS_OE & WR) begin
				if(WORD) SD_n_CS <= ~CPU_DOUT[8]; // SD chip select
				else SDI <= {SDI[6:0], SD_DO};
			end
		end

		if(KB_RST) rstcount <= 0;
		else if(CPU_CE && ~rstcount[4]) rstcount <= rstcount + 1;
		
// RTC		
		RTCSYNC <= {RTCSYNC[0], RTCDIVEND};
		if(IORQ && CPU_CE && WR && WORD && RTC_SELECT) begin
			RTC <= 0;
			RTCSET <= CPU_DOUT;
		end else if(RTCSYNC == 2'b01) begin
			if(RTCEND) RTC <= 0;
			else RTC <= RTC + 1;
		end
		
		//auto_flush[1:0] <= {auto_flush[0], vblnk};
	end


	assign DAC_AUDIO = 1'b0;
	assign AUD_L = (speaker_on ? timer_spk : DAC_AUDIO );
	assign AUD_R = AUD_L;
	
endmodule
