module SevenHexDecoderTimer (
	input              i_en,  
	input        [4:0] i_hex,
	output logic [6:0] o_seven_ten,
	output logic [6:0] o_seven_one
);

/* The layout of seven segment display, 1: dark
 *    00
 *   5  1
 *    66
 *   4  2
 *    33
 */

parameter DX = 7'b1111111;
parameter D0 = 7'b1000000;
parameter D1 = 7'b1111001;
parameter D2 = 7'b0100100;
parameter D3 = 7'b0110000;
parameter D4 = 7'b0011001;
parameter D5 = 7'b0010010;
parameter D6 = 7'b0000010;
parameter D7 = 7'b1011000;
parameter D8 = 7'b0000000;
parameter D9 = 7'b0010000;
parameter DERROR = 7'b0000110; // Error
always_comb begin
	case(i_hex)
		5'h0:  begin o_seven_ten = D0; o_seven_one = D0; end
		5'h1:  begin o_seven_ten = D0; o_seven_one = D1; end
		5'h2:  begin o_seven_ten = D0; o_seven_one = D2; end
		5'h3:  begin o_seven_ten = D0; o_seven_one = D3; end
		5'h4:  begin o_seven_ten = D0; o_seven_one = D4; end
		5'h5:  begin o_seven_ten = D0; o_seven_one = D5; end
		5'h6:  begin o_seven_ten = D0; o_seven_one = D6; end
		5'h7:  begin o_seven_ten = D0; o_seven_one = D7; end
		5'h8:  begin o_seven_ten = D0; o_seven_one = D8; end
		5'h9:  begin o_seven_ten = D0; o_seven_one = D9; end
		5'ha:  begin o_seven_ten = D1; o_seven_one = D0; end
		5'hb:  begin o_seven_ten = D1; o_seven_one = D1; end
		5'hc:  begin o_seven_ten = D1; o_seven_one = D2; end
		5'hd:  begin o_seven_ten = D1; o_seven_one = D3; end
		5'he:  begin o_seven_ten = D1; o_seven_one = D4; end
		5'hf:  begin o_seven_ten = D1; o_seven_one = D5; end
		5'h10: begin o_seven_ten = D1; o_seven_one = D6; end
		5'h11: begin o_seven_ten = D1; o_seven_one = D7; end
		5'h12: begin o_seven_ten = D1; o_seven_one = D8; end
		5'h13: begin o_seven_ten = D1; o_seven_one = D9; end
		5'h14: begin o_seven_ten = D2; o_seven_one = D0; end
		5'h15: begin o_seven_ten = D2; o_seven_one = D1; end
		5'h16: begin o_seven_ten = D2; o_seven_one = D2; end
		5'h17: begin o_seven_ten = D2; o_seven_one = D3; end
		5'h18: begin o_seven_ten = D2; o_seven_one = D4; end
		5'h19: begin o_seven_ten = D2; o_seven_one = D5; end
		5'h1a: begin o_seven_ten = D2; o_seven_one = D6; end
		5'h1b: begin o_seven_ten = D2; o_seven_one = D7; end
		5'h1c: begin o_seven_ten = D2; o_seven_one = D8; end
		5'h1d: begin o_seven_ten = D2; o_seven_one = D9; end
		5'h1e: begin o_seven_ten = D3; o_seven_one = D0; end
		5'h1f: begin o_seven_ten = D3; o_seven_one = D1; end
		default: begin o_seven_ten = DERROR; o_seven_one = DERROR; end
	endcase

	if (!i_en) begin
		o_seven_ten = DX;
		o_seven_one = DX;
	end
end

endmodule


module SevenHexDecoderSpeed (
	input              i_en,  
	input              i_sign, // f1/s0
	input        [3:0] i_speed,
	output logic [6:0] o_seven_sign,
	output logic [6:0] o_seven_num
);
/* The layout of seven segment display, 1: dark
 *    00
 *   5  1
 *    66
 *   4  2
 *    33
 */
//                6543210
parameter DX = 7'b1111111;
parameter D0 = 7'b1000000;
parameter D1 = 7'b1111001;
parameter D2 = 7'b0100100;
parameter D3 = 7'b0110000;
parameter D4 = 7'b0011001;
parameter D5 = 7'b0010010;
parameter D6 = 7'b0000010;
parameter D7 = 7'b1011000;
parameter D8 = 7'b0000000;
parameter D9 = 7'b0010000;
parameter DNEG = 7'b0111111; // -
always_comb begin
	case(i_speed)
		4'h0:  o_seven_num = D0;
		4'h1:  o_seven_num = D1;
		4'h2:  o_seven_num = D2;
		4'h3:  o_seven_num = D3;		
		4'h4:  o_seven_num = D4;
		4'h5:  o_seven_num = D5;
		4'h6:  o_seven_num = D6;
		4'h7:  o_seven_num = D7;
		4'h8:  o_seven_num = D8;
		4'h9:  o_seven_num = D9;
		default: o_seven_num = DX;
	endcase	

	o_seven_sign = (i_sign || i_speed == 4'h1 ? DX : DNEG);
	if (!i_en) begin
		o_seven_sign = DX;
		o_seven_num = DX;
	end	
end
endmodule


module SevenHexDecoderState (
	input        [2:0] i_state,
	output logic [6:0] o_seven_state_1,
	output logic [6:0] o_seven_state_2,
	output logic [6:0] o_seven_state_3,
	output logic [6:0] o_seven_state_4
);
// state: 00-idle, 01-play, 10-record, 11-pause
/* The layout of seven segment display, 1: dark
 *    00
 *   5  1
 *    66
 *   4  2
 *    33
 */
	parameter P = 7'b0001100; // P for play
	parameter A = 7'b0001000; // A for pause
	parameter U = 7'b1000001; // U for record

	parameter L = 7'b1000111; // L for idle
	parameter Y = 7'b0010001; // Y for play

	parameter R = 7'b0001000; // R for record
	parameter E = 7'b0000110; // E for error
	parameter C = 7'b1000110; // C for record pause

	parameter DX = 7'b1111111; // blank
	parameter DNEG = 7'b0111111; // -
	parameter DBOTTOM = 7'b1110111; // -

	always_comb begin
		case(i_state)
			3'b000: begin o_seven_state_1 = DNEG; o_seven_state_2 = DNEG; o_seven_state_3 = DNEG; o_seven_state_4 = DNEG; end
			3'b001: begin o_seven_state_1 = DBOTTOM; o_seven_state_2 = DBOTTOM; o_seven_state_3 = DBOTTOM; o_seven_state_4 = DBOTTOM; end

			3'b010: begin o_seven_state_1 = DX; o_seven_state_2 = R; o_seven_state_3 = E; o_seven_state_4 = C; end
			3'b100: begin o_seven_state_1 = P;  o_seven_state_2 = L; o_seven_state_3 = A; o_seven_state_4 = Y; end
			3'b011: begin o_seven_state_1 = DX; o_seven_state_2 = P; o_seven_state_3 = A; o_seven_state_4 = U; end
			3'b101: begin o_seven_state_1 = DX; o_seven_state_2 = P; o_seven_state_3 = A; o_seven_state_4 = U; end
			default: begin o_seven_state_1 = E; o_seven_state_2 = E; o_seven_state_3 = E; o_seven_state_4 = E; end
		endcase
	end

 endmodule