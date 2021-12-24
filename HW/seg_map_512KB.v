`timescale 1ns / 1ps
module seg_map_512KB(
	 input CLK,
	 input [3:0]cpuaddr,
	 output [3:0]cpurdata,
	 input [3:0]cpuwdata,
	 input [4:0]memaddr,
	 output [3:0]memdata,
	 input WE,
	 output f_map_to_f
    );

	reg [3:0]map[0:15] = {4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9,
								 4'ha, 4'hb,
								 4'hc, 4'hd, 4'he, 4'hf};
	assign memdata = map[memaddr[3:0]];
	assign cpurdata = map[cpuaddr];
	assign f_map_to_f = (map[15] == 4'hf);
	
	always @(posedge CLK) 
		if(WE) map[cpuaddr] <= cpuwdata;

endmodule
