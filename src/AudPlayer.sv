module AudPlayer(
	input i_rst_n,
	input i_bclk,
	input i_daclrck,
	input i_en, // enable AudPlayer only when playing audio
	input i_dac_data, //dac_data passed by audDSP
	output o_aud_dacdat // pass to wm8731
);

endmodule