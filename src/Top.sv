module Top (
	input i_rst_n, // key3
	input i_clk,
	input i_key_0, // Record/Pause
	input i_key_1, // Play/Pause
	input i_key_2, // Stop
	// design how user can decide mode on your own
	// one-hot priority(8>7>..>2)
	input i_speed2,
	input i_speed3,
	input i_speed4,
	input i_speed5,
	input i_speed6,
	input i_speed7,
	input i_speed8,

	input interpolation_method,
	input fast_slow, // f1/s0，speed==1的話哪個都沒差
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	output [6:0] o_seven_ten,
	output [6:0] o_seven_one,
	// output [5:0] o_record_time,
	// output [5:0] o_play_time,
	

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	output  [8:0] o_ledg,
	output [17:0] o_ledr
);
	
	// debug LED
	assign o_ledg[0] = opr_state_r == S_IDLE;
	assign o_ledg[1] = opr_state_r == S_I2C;
	assign o_ledg[2] = opr_state_r == S_RECD;
	assign o_ledg[3] = opr_state_r == S_RECD_PAUSE;
	assign o_ledg[4] = opr_state_r == S_PLAY;
	assign o_ledg[5] = opr_state_r == S_PLAY_PAUSE;
	// logic [2:0] dsp_state;
	// assign o_ledr[0] = dsp_state == 3'b000;
	// assign o_ledr[1] = dsp_state == 3'b001;
	// assign o_ledr[2] = dsp_state == 3'b010;
	// assign o_ledr[3] = dsp_state == 3'b011;
	// assign o_ledr[4] = dsp_state == 3'b100;
	// assign o_ledr[5] = dsp_state == 3'b101;

	// design the FSM and states as you like
	typedef enum logic [2:0] {
		S_IDLE       ,
		S_I2C        ,
		S_RECD       ,
		S_RECD_PAUSE ,
		S_PLAY       ,
		S_PLAY_PAUSE
	} opr_state_t;

	opr_state_t opr_state_r, opr_state_w;

	logic i2c_oen, i2c_sdat;
	logic [19:0] addr_record, addr_play, addr_rec_end;
	logic [15:0] data_record, data_play, dac_data;

	assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

	assign o_SRAM_ADDR = (opr_state_r == S_RECD) ? addr_record : addr_play[19:0];
	assign io_SRAM_DQ  = (opr_state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
	assign data_play   = (opr_state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

	// in S_RECD: dataplay = 0; io_SRAM_DQ = data_record (存東西進SRAM)
	// not in S_RECD: dataplay = z; io_SRAM_DQ = z 


	assign o_SRAM_WE_N = (opr_state_r == S_RECD) ? 1'b0 : 1'b1;
	assign o_SRAM_CE_N = 1'b0;
	assign o_SRAM_OE_N = 1'b0;
	assign o_SRAM_LB_N = 1'b0;
	assign o_SRAM_UB_N = 1'b0;

	// below is a simple example for module division
	// you can design these as you like
	logic play_en;
	logic I2C_finished;
	logic dsp_play, dsp_pause, dsp_stop; //給DSP的control signal
	logic dsp_fast, dsp_slow0, dsp_slow1, normal;  //給DSP的control signal
	logic rec_recd, rec_pause, rec_stop; //給recorder的control signal
	
	// speed computation
	logic [3:0] speedx;
	always_comb begin
		normal = 1'b0;
		case (1'b1)
			i_speed8: speedx = 4'd8;
			i_speed7: speedx = 4'd7;
			i_speed6: speedx = 4'd6;
			i_speed5: speedx = 4'd5;
			i_speed4: speedx = 4'd4;
			i_speed3: speedx = 4'd3;
			i_speed2: speedx = 4'd2;
			default: begin // 原速
				speedx = 4'd1;
				normal = 1'b1;
			end
		endcase
	end
	// control signal computation
	assign dsp_fast  = !normal && fast_slow;
	assign dsp_slow0 = !normal && !fast_slow && !interpolation_method;
	assign dsp_slow1 = !normal && !fast_slow && interpolation_method;

	// === I2cInitializer ===
	// sequentially sent out settings to initialize WM8731 with I2C protocal
	logic start_initI2C;
	assign start_initI2C = opr_state_r == S_I2C;
	I2cInitializer init0(
		.i_rst_n(i_rst_n),
		.i_clk(i_clk_100k),
		.i_start(start_initI2C),
		.o_finished(I2C_finished),
		.o_sclk(o_I2C_SCLK),
		.o_sdat(i2c_sdat),
		.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
	);

	// === AudDSP ===
	// responsible for DSP operations including fast play and slow play at different speed
	// in other words, determine which data addr to be fetch for player 
	AudDSP dsp0(
		.i_rst_n(i_rst_n),
		.i_clk(i_AUD_BCLK),
		.i_play(dsp_play),
		.i_pause(dsp_pause),
		.i_stop(dsp_stop),
		.i_speed(speedx),
		.i_fast(dsp_fast),
		.i_slow_0(dsp_slow0), // constant interpolation
		.i_slow_1(dsp_slow1), // linear interpolation
		.i_daclrck(i_AUD_DACLRCK),
		.i_sram_data(data_play),
		.o_dac_data(dac_data),
		.o_en(play_en),
		.o_sram_addr(addr_play)
	);

	// === AudPlayer ===
	// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
	AudPlayer player0(
		.i_rst_n(i_rst_n),
		.i_bclk(i_AUD_BCLK),
		.i_daclrck(i_AUD_DACLRCK),
		.i_en(play_en), // enable AudPlayer only when playing audio, work with AudDSP
		.i_dac_data(dac_data), //dac_data
		.o_aud_dacdat(o_AUD_DACDAT)
	);

	// === AudRecorder ===
	// receive data from WM8731 with I2S protocal and save to SRAM
	AudRecorder recorder0(
		.i_rst_n(i_rst_n), 
		.i_clk(i_AUD_BCLK),
		.i_lrc(i_AUD_ADCLRCK),
		.i_rec(rec_recd),
		.i_pause(rec_pause),
		.i_stop(rec_stop),
		.i_data(i_AUD_ADCDAT),
		.o_address(addr_record),
		.o_data(data_record),
		.o_stop_address(addr_rec_end)
	);

	// === Timer ===
	// display o_SRAM_ADDR except IDLE and I2C with SevenHexDecoder
	// o_SRAM_ADDR has 20 bits, WM8731 is 32k/s * 2 bytes/s = 64kB/s
	// [0000 0]000 000_0 0000 0000
	// o_SRAM_ADD[20:16] is 0 -> 31 second
	SevenHexDecoder timer0 (
		.i_en(!(opr_state_r == S_IDLE || opr_state_r == S_I2C)),
		.i_hex(o_SRAM_ADD[20:16]),
		.o_seven_ten(o_seven_ten),
		.o_seven_one(o_seven_one)
	);


	// NL
	always_comb begin
		opr_state_w = opr_state_r;
		case (opr_state_r)
			S_IDLE: begin
				case(1'b1)
					i_key_1: begin
						opr_state_w = S_PLAY;
						// DSP 會從 S_RESET變PLAY addr_play會歸零 
					end
					i_key_0: begin
						opr_state_w = S_RECD;
						// Recorder 會從 S_IDLE變READ addr_record會歸零 
					end
					default: opr_state_w = opr_state_r;
				endcase
			end

			S_I2C: begin
				if (I2C_finished) opr_state_w = S_IDLE;
			end

			S_RECD: begin
				case(1'b1)
					i_key_2: opr_state_w = S_IDLE;
					i_key_1: begin
						opr_state_w = S_PLAY;
					end
					i_key_0: opr_state_w = S_RECD_PAUSE;
					default: opr_state_w = opr_state_r;
				endcase
			end

			S_RECD_PAUSE: begin
				case(1'b1)
					i_key_2: opr_state_w = S_IDLE;
					i_key_1: begin
						opr_state_w = S_PLAY;
					end
					i_key_0: opr_state_w = S_RECD;
					default: opr_state_w = opr_state_r;
				endcase
			end

			S_PLAY: begin
				if (addr_play >= addr_rec_end) opr_state_w = S_IDLE; //播完
				else begin
					case(1'b1)
						i_key_2: opr_state_w = S_IDLE;
						i_key_1: opr_state_w = S_PLAY_PAUSE;
						i_key_0: opr_state_w = S_RECD;
						default: opr_state_w = opr_state_r;
					endcase
				end
			end

			S_PLAY_PAUSE: begin
				case(1'b1)
					i_key_2: opr_state_w = S_IDLE;
					i_key_1: opr_state_w = S_PLAY;
					i_key_0: opr_state_w = S_RECD;
					default: opr_state_w = opr_state_r;
				endcase
			end

			default: begin
				opr_state_w = S_IDLE;
			end
		endcase
	end

	// state control
	assign rec_pause = (opr_state_r==S_RECD_PAUSE);
	assign rec_recd  = (opr_state_r==S_RECD);
	assign rec_stop  = !(rec_pause || rec_recd);
	assign dsp_pause = (opr_state_r==S_PLAY_PAUSE);
	assign dsp_play  = (opr_state_r==S_PLAY);
	assign dsp_stop  = !(dsp_pause || dsp_play);

	always_ff @(posedge i_AUD_BCLK or negedge i_rst_n) begin
		if (!i_rst_n) begin
			opr_state_r <= S_I2C;
		end
		else begin
			opr_state_r <= opr_state_w;
		end
	end

endmodule

// OS:其實昨天就完成了