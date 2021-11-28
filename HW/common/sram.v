//////////////////////////////////////////////////////////////////////////////////
//
// Filename: sram.v
// Description: SRAM 8-bit controller for the Next186 SoC PC project, 
// Version 1.0
// Creation date: Dec2016
//
// Author: DistWave
// 
// Based on SDRAM 16-bit controller from the Next186 SoC PC project by Nicolae Dumitrache
/////////////////////////////////////////////////////////////////////////////////

module SRAM_8bit(
		input sys_CLK,								// clock
		input [1:0]sys_CMD,						// 00=nop, 01=write 256 bytes, 11=read 256 bytes
		input [18:0]sys_ADDR,					// word address, multiple of 2 words (4 bytes)
		input [15:0]sys_DIN,						// data input
		output reg [15:0]sys_DOUT,
		output reg sys_rd_data_valid = 0,	// data valid out
		output reg sys_wr_data_valid = 0,	// data valid in
		
		input sram_clk,
		output sram_n_WE,							// SRAM #WE
		output reg [20:0]sram_ADDR,			// SRAM address
		inout [7:0]sram_DATA						// SRAM data
	);
	
	reg [2:0]STATE = 0;
	reg [2:0]RET;									// return state
	reg [6:0]DLY;									// delay
	reg [1:0]sys_cmd_ack = 0;					// command acknowledged 
	reg [15:0]reg_din;
	reg [5:0]out_data_valid = 0;

	assign sram_DATA = out_data_valid[2] ? sram_ADDR[0] ? reg_din[15:8] : reg_din[7:0] : 8'hzz;
	assign sram_n_WE = out_data_valid[2] ? 0 : 1;

	reg [7:0]sram_data2;

	always @(posedge sram_clk) begin
		sram_data2 <= sram_DATA;
		case(STATE)
			0: begin
				if(|sys_CMD) begin
					sram_ADDR <= {sys_ADDR[18:0], 2'b00};
					end 
				end
			1: begin
					if ((sys_rd_data_valid == 1'b1) || (out_data_valid[2] == 1'b1)) begin
						sram_ADDR <= sram_ADDR + 1'b1;
					end
				end
			7: begin
					if(sys_cmd_ack[1]) begin
						sram_ADDR <= sram_ADDR + 1;
					end
				end
		endcase
	end
	
	
	always @(posedge sys_CLK) begin
			STATE <= 1;
			reg_din <= sys_DIN;
			out_data_valid <= {out_data_valid[1:0], sys_wr_data_valid};
			DLY <= DLY - 1;
			sys_DOUT <= {sram_DATA, sram_data2};
			
			case(STATE)
				0: begin
						sys_rd_data_valid <= 1'b0;
						if(|sys_CMD) begin
							sys_cmd_ack <= sys_CMD;
							STATE <= 5;
						end 
						else begin
							sys_cmd_ack <= 2'b00;
							STATE <= 0;
						end
					end
				1: begin
						if(DLY == 3) sys_wr_data_valid <= 1'b0;
						if(DLY == 0) STATE <= RET;	// NOP for DLY clocks, return to RET state
					end 
				5: begin	// read/write
					RET <= 7;
						if(sys_cmd_ack[1]) begin	// read
							STATE <= 7;
						end else begin	// write
							DLY <= 1;
							sys_wr_data_valid <= 1'b1;
						end
					end 
				7: begin	// init read/write phase
						if(sys_cmd_ack[1]) begin
							sys_rd_data_valid <= 1'b1;
						end
						RET <= 0;
						DLY <= sys_cmd_ack[1] ? 128 - 2 : 128 - 1;
					end
			endcase
	end
endmodule