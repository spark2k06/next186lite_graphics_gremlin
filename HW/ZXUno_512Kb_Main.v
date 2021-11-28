`timescale 1ns / 1ps

module ZXUno_Next186lite_512KB
	(
		input  CLK_50MHZ,
		output [2:0]VGA_R,
		output [2:0]VGA_G,
		output [2:0]VGA_B,
		output VGA_HSYNC,
		output VGA_VSYNC,
		output SRAM_WE_n,
		output [19:0]SRAM_A,
		inout [7:0]SRAM_D,
		output LED,
		output AUDIO_L,
		output AUDIO_R,
		inout PS2CLKA,
		inout PS2CLKB,
		inout PS2DATA,
		inout PS2DATB,
		output SD_nCS,
		output SD_DI,
		output SD_CK,
		input SD_DO,
		input P_A,
		input P_U,
		input P_D,
		input P_L,
		input P_R,
		input P_tr		

	);

	wire [5:0] r, g, b;	
	wire VGA_HSYNC, VGA_VSYNC;
	reg [5:0] raux, gaux, baux;
	wire [1:0] monochrome_switcher;
		
	
	reg [5:0]red_weight[0:63] = { // 0.2126*R
	6'h00, 6'h01, 6'h01, 6'h01, 6'h01, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h04,
	6'h04, 6'h04, 6'h04, 6'h05, 6'h05, 6'h05, 6'h05, 6'h05, 6'h06, 6'h06, 6'h06, 6'h06, 6'h06, 6'h07, 6'h07, 6'h07,
	6'h07, 6'h08, 6'h08, 6'h08, 6'h08, 6'h08, 6'h09, 6'h09, 6'h09, 6'h09, 6'h09, 6'h0a, 6'h0a, 6'h0a, 6'h0a, 6'h0a,
	6'h0b, 6'h0b, 6'h0b, 6'h0b, 6'h0c, 6'h0c, 6'h0c, 6'h0c, 6'h0c, 6'h0d, 6'h0d, 6'h0d, 6'h0d, 6'h0d, 6'h0e, 6'h0e
	};
	
	reg [5:0]green_weight[0:63] = { // 0.7152*G
	6'h00, 6'h01, 6'h02, 6'h03, 6'h03, 6'h04, 6'h05, 6'h06, 6'h06, 6'h07, 6'h08, 6'h08, 6'h09, 6'h0a, 6'h0b, 6'h0b,
	6'h0c, 6'h0d, 6'h0d, 6'h0e, 6'h0f, 6'h10, 6'h10, 6'h11, 6'h12, 6'h12, 6'h13, 6'h14, 6'h15, 6'h15, 6'h16, 6'h17,
	6'h17, 6'h18, 6'h19, 6'h1a, 6'h1a, 6'h1b, 6'h1c, 6'h1c, 6'h1d, 6'h1e, 6'h1f, 6'h1f, 6'h20, 6'h21, 6'h21, 6'h22,
	6'h23, 6'h24, 6'h24, 6'h25, 6'h26, 6'h26, 6'h27, 6'h28, 6'h29, 6'h29, 6'h2a, 6'h2a, 6'h2a, 6'h2b, 6'h2b, 6'h2b
	};
	
	reg [5:0]blue_weight[0:63] = { // 0.0722*B
	6'h00, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h01, 6'h02, 6'h02,
	6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h02, 6'h03, 6'h03, 6'h03, 6'h03,
	6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h03, 6'h04, 6'h04, 6'h04, 6'h04, 6'h04, 6'h04,
	6'h04, 6'h04, 6'h04, 6'h04, 6'h04, 6'h04, 6'h04, 6'h04, 6'h05, 6'h05, 6'h05, 6'h05, 6'h05, 6'h05, 6'h05, 6'h05
	};
	
   
	system_512KB sys_inst
	(
		.CLK_50MHZ(CLK_50MHZ),
		.VGA_R(r),
		.VGA_G(g),
		.VGA_B(b),
		.VGA_HSYNC(VGA_HSYNC),
		.VGA_VSYNC(VGA_VSYNC),
		.SRAM_ADDR(SRAM_A),
		.SRAM_DATA(SRAM_D),
		.SRAM_WE_n(SRAM_WE_n),
		.LED(LED),
		.SD_n_CS(SD_nCS),
		.SD_DI(SD_DI),
		.SD_CK(SD_CK),
		.SD_DO(SD_DO),
		.AUD_L(AUDIO_L),
		.AUD_R(AUDIO_R),
	 	.PS2_CLK1(PS2CLKA),
		.PS2_CLK2(PS2CLKB),
		.PS2_DATA1(PS2DATA),
		.PS2_DATA2(PS2DATB),
		.monochrome_switcher(monochrome_switcher)
	);
	
	
	
	always @ (monochrome_switcher, r, g, b) begin
		case(monochrome_switcher)
			// Verde
			2'b01	: begin
				raux = 6'b0;
				gaux = red_weight[r] + green_weight[g] + blue_weight[b];				
				baux = 6'b0;
			end
			// Ambar
			2'b10	: begin
				raux = red_weight[r] + green_weight[g] + blue_weight[b];
				gaux = (red_weight[r] + green_weight[g] + blue_weight[b]) >> 1;
				baux = 6'b0;
			end
			// Blanco y negro
			2'b11	: begin
				raux = red_weight[r] + green_weight[g] + blue_weight[b];
				gaux = red_weight[r] + green_weight[g] + blue_weight[b];
				baux = red_weight[r] + green_weight[g] + blue_weight[b];
			end
			// Color
			default: begin
				raux = r;
				gaux = g;
				baux = b;
			end
		endcase
	end
	
	assign VGA_R = raux[5:3];
	assign VGA_G = gaux[5:3];
	assign VGA_B = baux[5:3];

endmodule
