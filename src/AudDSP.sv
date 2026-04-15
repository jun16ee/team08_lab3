module AudDSP dsp0(
	input i_rst_n,
	input i_clk,
	input i_start,
	input i_pause,
	input i_stop,
	input [3:0] i_speed, //1~7
	input i_fast, 
	input i_slow_0, // constant interpolation
	input i_slow_1, // linear interpolation

	input i_daclrck, //根據這個決定現在要送左或右聲道(1=右)
	input [15:0] i_sram_data, // 讀SRAM存的音檔

	output [15:0] o_dac_data, //給喇叭
	output [19:0] o_sram_addr //要讀sram哪裡的資料 0~2^20-1
);


endmodule