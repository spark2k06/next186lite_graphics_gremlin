//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: cache_controller.v
// Description: Part of the Next186 SoC PC project, cache controller
// Version 1.0
// Creation date: Jan2012
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
// 8 lines of 256bytes each
// preloaded with bootstrap code (last 4 lines)
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps


module cache_controller_512KB(
	 input [20:0] addr,
     output [31:0] dout,
	 input [31:0]din,
	 input clk,	
	 input mreq,
	 input [3:0]wmask,
	 output ce,	// clock enable for CPU
	 input [15:0]ddr_din,
	 output reg[15:0]ddr_dout,
	 input ddr_clk,
	 input cache_write_data, // 1 when data must be written to cache, on posedge ddr_clk
	 input cache_read_data, // 1 when data must be read from cache, on posedge ddr_clk
	 output reg ddr_rd = 0,
	 output reg ddr_wr = 0,
	 output reg [12:0] waddr,
	 input flush
    );
	
	wire [7:0]fit;
	wire [7:0]free;
	wire wr = |wmask;
	reg [16:0]cache0 = 17'h00000; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache1 = 17'h00012; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache2 = 17'h00024; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache3 = 17'h00036; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache4 = 17'h0ffc9; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache5 = 17'h0ffdb; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache6 = 17'h0ffed; // 13'b:addr, 3'b:count, 1'b:dirty
	reg [16:0]cache7 = 17'h0ffff; // 13'b:addr, 3'b:count, 1'b:dirty
	
	reg dirty;	
	reg [2:0]STATE = 0;
	reg [6:0]lowaddr = 0; //cache mem address
	reg s_lowaddr5 = 0;
	wire [31:0]cache_QA;

	assign fit[0] = cache0[16:4] == addr[20:8];
	assign fit[1] = cache1[16:4] == addr[20:8];
	assign fit[2] = cache2[16:4] == addr[20:8];
	assign fit[3] = cache3[16:4] == addr[20:8];
	assign fit[4] = cache4[16:4] == addr[20:8];
	assign fit[5] = cache5[16:4] == addr[20:8];
	assign fit[6] = cache6[16:4] == addr[20:8];
	assign fit[7] = cache7[16:4] == addr[20:8];
	
	assign free[0] = cache0[3:1] == 3'b000;
    assign free[1] = cache1[3:1] == 3'b000;
    assign free[2] = cache2[3:1] == 3'b000;
    assign free[3] = cache3[3:1] == 3'b000;
    assign free[4] = cache4[3:1] == 3'b000;
    assign free[5] = cache5[3:1] == 3'b000;
    assign free[6] = cache6[3:1] == 3'b000;
    assign free[7] = cache7[3:1] == 3'b000;

	wire hit = |fit;
	wire st0 = STATE == 0;
	assign ce = st0 && (~mreq || hit);

	wire [2:0]blk =  {fit[4] | fit[5] | fit[6] | fit[7], fit[2] | fit[3] | fit[6] | fit[7], fit[1] | fit[3] | fit[5] | fit[7]};
	wire [2:0]fblk = {free[4] | free[5] | free[6] | free[7], free[2] | free[3] | free[6] | free[7], free[1] | free[3] | free[5] | free[7]};
	wire [2:0]csblk = ({3{fit[0]}} & cache0[3:1]) | ({3{fit[1]}} & cache1[3:1]) |
							({3{fit[2]}} & cache2[3:1]) | ({3{fit[3]}} & cache3[3:1]) |
							({3{fit[4]}} & cache4[3:1]) | ({3{fit[5]}} & cache5[3:1]) |
							({3{fit[6]}} & cache6[3:1]) | ({3{fit[7]}} & cache7[3:1]);
	
	always @(posedge ddr_clk) begin
		if(cache_write_data || cache_read_data) lowaddr <= lowaddr + 1;
		ddr_dout <= lowaddr[0] ? cache_QA[15:0] : cache_QA[31:16];
	end
	
	cache_512KB cache_mem (
	  .clka(ddr_clk), // input clka
	  .ena(cache_write_data | cache_read_data),
	  .wea({4{cache_write_data}} & {lowaddr[0], lowaddr[0], ~lowaddr[0], ~lowaddr[0]}), // input [3 : 0] wea
	  .addra({blk, lowaddr[6:1]}), // input [8 : 0] addra
	  .dina({ddr_din, ddr_din}), // input [31 : 0] dina
	  .douta(cache_QA), // output [31 : 0] douta
	  .clkb(clk), // input clkb
	  .enb(mreq & hit & st0),
	  .web({4{mreq & hit & st0 & wr}} & wmask),
	  .addrb({blk, addr[7:2]}), // input [8 : 0] addrb
	  .dinb(din), // input [31 : 0] dinb
	  .doutb(dout) // output [31 : 0] doutb
	);
	
	
	always @(cache0, cache1, cache2, cache3, cache4, cache5, cache6, cache7) begin
		dirty = 1'bx;
		case(1)
			free[0]: begin dirty = cache0[0]; end		
			free[1]: begin dirty = cache1[0]; end
			free[2]: begin dirty = cache2[0]; end
			free[3]: begin dirty = cache3[0]; end
			free[4]: begin dirty = cache4[0]; end
			free[5]: begin dirty = cache5[0]; end
			free[6]: begin dirty = cache6[0]; end
			free[7]: begin dirty = cache7[0]; end
		endcase
	end
	

	always @(posedge clk) begin
		s_lowaddr5 <= lowaddr[6];
		
		case(STATE)
			3'b000: begin
				if(mreq) begin
					if(hit) begin	// cache hit
						cache0[3:1] <= fit[0] ? 3'b111 : cache0[3:1] - (cache0[3:1] > csblk); 
						cache1[3:1] <= fit[1] ? 3'b111 : cache1[3:1] - (cache1[3:1] > csblk); 
						cache2[3:1] <= fit[2] ? 3'b111 : cache2[3:1] - (cache2[3:1] > csblk); 
						cache3[3:1] <= fit[3] ? 3'b111 : cache3[3:1] - (cache3[3:1] > csblk); 
						cache4[3:1] <= fit[4] ? 3'b111 : cache4[3:1] - (cache4[3:1] > csblk); 
						cache5[3:1] <= fit[5] ? 3'b111 : cache5[3:1] - (cache5[3:1] > csblk); 
						cache6[3:1] <= fit[6] ? 3'b111 : cache6[3:1] - (cache6[3:1] > csblk); 
						cache7[3:1] <= fit[7] ? 3'b111 : cache7[3:1] - (cache7[3:1] > csblk); 
					end else begin	// cache miss
						case(fblk)	// free block
							0:	begin waddr <= cache0[16:4]; cache0[16:4] <= addr[20:8]; end
							1:	begin waddr <= cache1[16:4]; cache1[16:4] <= addr[20:8]; end
							2:	begin waddr <= cache2[16:4]; cache2[16:4] <= addr[20:8]; end
							3:	begin waddr <= cache3[16:4]; cache3[16:4] <= addr[20:8]; end
							4:	begin waddr <= cache4[16:4]; cache4[16:4] <= addr[20:8]; end
							5:	begin waddr <= cache5[16:4]; cache5[16:4] <= addr[20:8]; end
							6:	begin waddr <= cache6[16:4]; cache6[16:4] <= addr[20:8]; end
							7:	begin waddr <= cache7[16:4]; cache7[16:4] <= addr[20:8]; end
						endcase
						ddr_rd <= ~dirty;
						ddr_wr <= dirty;
						STATE <= dirty ? 3'b011 : 3'b100;
					end
					if(hit) case(1) // free or hit block
						fit[0]: cache0[0] <= (cache0[0] | wr);
						fit[1]: cache1[0] <= (cache1[0] | wr);
						fit[2]: cache2[0] <= (cache2[0] | wr);
						fit[3]: cache3[0] <= (cache3[0] | wr);
						fit[4]: cache4[0] <= (cache4[0] | wr);
						fit[5]: cache5[0] <= (cache5[0] | wr);
						fit[6]: cache6[0] <= (cache6[0] | wr);
						fit[7]: cache7[0] <= (cache7[0] | wr);
					endcase else case(1)
						free[0]: cache0[0] <= 0;
						free[1]: cache1[0] <= 0;
						free[2]: cache2[0] <= 0;
						free[3]: cache3[0] <= 0;
						free[4]: cache4[0] <= 0;
						free[5]: cache5[0] <= 0;
						free[6]: cache6[0] <= 0;
						free[7]: cache7[0] <= 0;
					endcase				
				end
			end
			3'b011: begin	// write cache to ddr
				ddr_rd <= 1'b1;
				if(s_lowaddr5) begin
					ddr_wr <= 1'b0;
					STATE <= 3'b111;
				end
			end
			3'b111: begin // read cache from ddr
				if(~s_lowaddr5) STATE <= 3'b100;
			end
			3'b100: begin	
				if(s_lowaddr5) STATE <= 3'b101;
			end
			3'b101: begin
				ddr_rd <= 1'b0;
				if(~s_lowaddr5) STATE <= 3'b000;
			end
		endcase
	end
	
endmodule

module seg_map_512KB(
	 input CLK,
	 input [3:0]cpuaddr,
	 output [3:0]cpurdata,
	 input [3:0]cpuwdata,
	 input [4:0]memaddr,
	 output [3:0]memdata,
	 input WE
    );

	reg [3:0]map[0:31] = {4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9,
								 4'ha, 4'hb,	// VGA seg 1 and 2
								 4'hc, 4'hd, 4'he, 4'hf,
								 4'h0,	// HMA
								 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 
								 4'ha, 4'hb, 4'hc, 4'hd, 4'he, 4'hf}; // VGA seg 1..6								 
	assign memdata = map[memaddr];
	assign cpurdata = map[{1'b0, cpuaddr}];
	
	always @(posedge CLK) 
		if(WE) map[{1'b0, cpuaddr}] <= cpuwdata;

endmodule
