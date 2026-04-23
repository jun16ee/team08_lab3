// 十進位顯示
module SevenHexDecoder (
	input        [3:0] i_hex,
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
always_comb begin
	case(i_hex)
		4'h0: begin o_seven_ten = D0; o_seven_one = D0; end
		4'h1: begin o_seven_ten = D0; o_seven_one = D1; end
		4'h2: begin o_seven_ten = D0; o_seven_one = D2; end
		4'h3: begin o_seven_ten = D0; o_seven_one = D3; end
		4'h4: begin o_seven_ten = D0; o_seven_one = D4; end
		4'h5: begin o_seven_ten = D0; o_seven_one = D5; end
		4'h6: begin o_seven_ten = D0; o_seven_one = D6; end
		4'h7: begin o_seven_ten = D0; o_seven_one = D7; end
		4'h8: begin o_seven_ten = D0; o_seven_one = D8; end
		4'h9: begin o_seven_ten = D0; o_seven_one = D9; end
		4'ha: begin o_seven_ten = D1; o_seven_one = D0; end
		4'hb: begin o_seven_ten = D1; o_seven_one = D1; end
		4'hc: begin o_seven_ten = D1; o_seven_one = D2; end
		4'hd: begin o_seven_ten = D1; o_seven_one = D3; end
		4'he: begin o_seven_ten = D1; o_seven_one = D4; end
		4'hf: begin o_seven_ten = D1; o_seven_one = D5; end
	endcase
end

endmodule



// ============================================================================
// 16進位顯示
// ============================================================================
module Display16Bit (
    input  logic [15:0] i_data,
    output logic [6:0]  o_hex3, // 顯示 bits [15:12]
    output logic [6:0]  o_hex2, // 顯示 bits [11:8]
    output logic [6:0]  o_hex1, // 顯示 bits [7:4]
    output logic [6:0]  o_hex0  // 顯示 bits [3:0]
);

    // 實例化 4 個解碼器，分別負責 4 個位數 (nibbles)
    HexTo7Seg dec3 (.i_hex(i_data[15:12]), .o_seg(o_hex3));
    HexTo7Seg dec2 (.i_hex(i_data[11:8]),  .o_seg(o_hex2));
    HexTo7Seg dec1 (.i_hex(i_data[7:4]),   .o_seg(o_hex1));
    HexTo7Seg dec0 (.i_hex(i_data[3:0]),   .o_seg(o_hex0));

endmodule

// ============================================================================
// 單一 4-bit (0~F) 轉七段顯示器解碼器 (Active Low / 共陽極)
// ============================================================================
module HexTo7Seg (
    input  logic [3:0] i_hex,
    output logic [6:0] o_seg
);

    always_comb begin
        case (i_hex)
            // 對應 DE2-115 的共陽極七段顯示器 (0為亮，1為暗)
            // 段位順序通常為 {g, f, e, d, c, b, a}
            4'h0: o_seg = 7'b1000000;
            4'h1: o_seg = 7'b1111001;
            4'h2: o_seg = 7'b0100100;
            4'h3: o_seg = 7'b0110000;
            4'h4: o_seg = 7'b0011001;
            4'h5: o_seg = 7'b0010010;
            4'h6: o_seg = 7'b0000010;
            4'h7: o_seg = 7'b1111000; // 或 7'b1011000，視你要不要亮上面那一橫
            4'h8: o_seg = 7'b0000000;
            4'h9: o_seg = 7'b0010000;
            4'hA: o_seg = 7'b0001000;
            4'hB: o_seg = 7'b0000011;
            4'hC: o_seg = 7'b1000110;
            4'hD: o_seg = 7'b0100001;
            4'hE: o_seg = 7'b0000110;
            4'hF: o_seg = 7'b0001110;
            default: o_seg = 7'b1111111; // 預設全暗
        endcase
    end

endmodule