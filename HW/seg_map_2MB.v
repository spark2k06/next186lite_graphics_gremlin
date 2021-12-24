`timescale 1ns / 1ps
module seg_map_2MB(
	 input CLK,
	 input [3:0]cpuaddr,
	 output [7:0]cpurdata,
	 input [7:0]cpuwdata,
	 input [5:0]memaddr, // A20 disabled (PCXT)
	 output [6:0]memdata,
	 input WE,
	 input WE_EMS,
	 input EMS_OE,
	 output f_map_to_f
    );
	
	reg [4:0]map[0:15] = {5'h00, 5'h01, 5'h02, 5'h03, 5'h04, 5'h05, 5'h06, 5'h07, 5'h08, 5'h09,
								 5'h0a, 5'h0b,
								 5'h0c, 5'h0d, 5'h0e, 5'h0f};	

	reg [5:0]map_ems[0:3] = {6'h00, 6'h00, 6'h00, 6'h00}; // Segment hE000, hE400, hE800, hEC00
	reg ena_ems[0:3] = {1'b0, 1'b0, 1'b0, 1'b0}; // Enable Segment Map hE000, hE400, hE800, hEC00

	reg ems_enable = 1'b0;	
	assign cpurdata = EMS_OE ? ena_ems[cpuaddr[1:0]] ? map_ems[cpuaddr[1:0]] : 8'hFF : {4'b00, map[cpuaddr]};
	assign memdata = (memaddr[5:2] == 4'ha & ena_ems[memaddr[1:0]]) ? {1'b1, map_ems[memaddr[1:0]]} : {map[memaddr[5:2]], memaddr[1:0]}; 
	assign f_map_to_f = (map[15] == 5'h0f);	
	
	always @(posedge CLK)
		if(WE_EMS) begin
			ena_ems[cpuaddr[1:0]] <= (cpuwdata == 8'hFF) ? 1'b0 : (cpuwdata < 8'h40) ? 1'b1 : ena_ems[cpuaddr[1:0]];
			map_ems[cpuaddr[1:0]] <= (cpuwdata == 8'hFF) ? 6'hFF : (cpuwdata < 8'h40) ? cpuwdata[5:0] : map_ems[cpuaddr[1:0]];			
		end else if(WE)		
			map[cpuaddr[3:0]] <= cpuwdata[4:0];

endmodule
