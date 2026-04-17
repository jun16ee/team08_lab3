module AudDSP(
	input i_rst_n,
	input i_clk, //每cylce傳一次data
    input i_start,
	input i_pause,
	input i_stop,

    input [3:0] i_speed, //1~8
	input i_fast, 
	input i_slow_0, // constant interpolation
	input i_slow_1, // linear interpolation

	input i_daclrck, //根據這個決定現在要送左或右聲道(1=右)，每個週期傳一次data
	input [15:0] i_sram_data, // 讀SRAM存的音檔
	output [15:0] o_dac_data, //給喇叭 1 daclrck cycle傳一次
    output o_en,
	output [19:0] o_sram_addr //要讀sram哪裡的資料 0~2^20-1
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_PLAY,
        S_PAUSE
    } play_state_t;

    typedef enum logic [2:0] {
        S_RESET,
        S_PAUSED,
        S_PROCESS,
        S_READY,
        S_OUTPUT
    } dsp_state_t;

    play_state_t play_state_r, play_state_w;
    dsp_state_t dsp_state_r, dsp_state_w;
    logic [19:0] read_addr_r, read_addr_w;
    logic [15:0] op_r, op_w;
    logic [3:0] slow_counter_w, slow_counter_r;
    logic [15:0] rdata_nxt_r, rdata_now_r, rdata_now_w;
    
    assign o_sram_addr = read_addr_r;
    assign o_dac_data = (dsp_state_r==S_READY || dsp_state_r==S_OUTPUT) ? op_r : 16'd0;
    assign o_en = (dsp_state_r!=S_RESET) && i_daclrck;
   
    logic [15:0] interpolation_value;
    interpolation_calculator u_interpolation_calculator( // out = D0 + (D1 - D0) * C/S
        .d0(rdata_now_r),     // Current data
        .d1(rdata_nxt_r),     // Next data
        .s(i_speed),      // Slow speed: 2~8
        .c(slow_counter_r),      // Slow counter: 0~s-1
        .o_data(interpolation_value)  
    );


    always_comb begin
        dsp_state_w = dsp_state_r;
        read_addr_w = read_addr_r;
        rdata_now_w = rdata_now_r;
        slow_counter_w = slow_counter_r;
        op_w = op_r;
        // if (play_state_r==S_PLAY) begin
            case(dsp_state_r)
                S_RESET: begin
                    if (!i_daclrck && play_state_r==S_PLAY) begin
                        dsp_state_w = S_PROCESS;
                        read_addr_w = 20'd0; //重新開始了 要initialize
                    end
                end
                S_PAUSED: begin
                    if (!i_daclrck && play_state_r==S_PLAY) begin
                        dsp_state_w = S_PROCESS;
                        // 不用把addr歸零 initialize
                    end
                end
                S_PROCESS: begin
                    dsp_state_w = S_READY;
                    if(i_slow_1) begin
                        op_w = interpolation_value;
                    end else begin
                        op_w = rdata_now_r;
                    end
                end
                S_READY: begin
                    if (i_daclrck) dsp_state_w = S_OUTPUT;
                end
                S_OUTPUT: begin
                    if (!i_daclrck) begin 
                        if (play_state_r==S_IDLE) begin
                            dsp_state_w = S_RESET;
                        end else if (play_state_r==S_PAUSE) begin
                            dsp_state_w = S_PAUSED;
                        end else begin
                            dsp_state_w = S_PROCESS;
                            case(1'b1)
                                i_fast: begin
                                    read_addr_w = read_addr_r + i_speed;
                                    rdata_now_w = rdata_nxt_r;
                                end
                                i_slow_0, i_slow_1: begin // 這兩個模式計數邏輯一樣，可以合併
                                    if (slow_counter_r == i_speed - 1'b1) begin
                                        read_addr_w = read_addr_r + 1'b1;
                                        rdata_now_w = rdata_nxt_r;
                                        slow_counter_w = 4'd0;
                                    end else begin
                                        slow_counter_w = slow_counter_r + 1'b1;
                                    end
                                end
                                // 正常 1 倍速 (Normal Speed) 的預設行為
                                default: begin
                                    read_addr_w = read_addr_r + 1'b1;
                                    rdata_now_w = rdata_nxt_r;
                                    slow_counter_w = 4'd0;
                                end
                            endcase
                        end
                    end
                end
            endcase
        // end else begin
        //     dsp_state_w = S_RESET;
        // end

    end


    // play state NL
    always_comb begin
        play_state_w = play_state_r;
        case(play_state_r)
            S_IDLE: begin
                if (i_start) begin
                    play_state_w = S_PLAY;
                end
            end

            S_PLAY: begin
                if (i_stop) begin
                    play_state_w = S_IDLE;
                end else if (i_pause) begin
                    play_state_w = S_PAUSE;
                end
            end

            S_PAUSE: begin
                if (i_stop) begin
                    play_state_w = S_IDLE;
                end else if (i_start) begin
                    play_state_w = S_PLAY;
                end
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            play_state_r <= S_IDLE;
            dsp_state_r <= S_RESET;
            rdata_now_r <= 16'd0;
            rdata_nxt_r <= 16'd0;
            read_addr_r <= 20'd0;
            op_r <= 16'd0;
            slow_counter_r <= 4'd0;
        end
        else begin
            play_state_r <= play_state_w;
            dsp_state_r <= dsp_state_w;
            rdata_now_r <= rdata_now_w;
            rdata_nxt_r <= i_sram_data;
            read_addr_r <= read_addr_w;
            op_r <= op_w;
            slow_counter_r <= slow_counter_w;
        end
    end

endmodule


module interpolation_calculator( // out = D0 + (D1 - D0) * C/S
    input  [15:0] d0,     // Current data
    input  [15:0] d1,     // Next data
    input  [3:0]  s,      // Slow speed: 2~8
    input  [3:0]  c,      // Slow counter: 0~s-1
    output [15:0] o_data  
);
    /* use LUT save W = (C/S) << 16
    out = D0 + ( (D1 - D0) * W >> 16 )
    */
    
    // d1-d0 17-bit
    logic signed [16:0] diff;
    assign diff = $signed(d1) - $signed(d0);        
    
    // 權重為無號數，最大值對應於 1 (65536，但我們用 16-bit 存小數部位)
    logic        [15:0] weight;      
    
    // 乘法結果: 17-bit(diff) * 17-bit(weight補0) = 34-bit
    logic signed [33:0] mult;

    // ===LUT=== //
    always_comb begin
        // 預設權重為 0 (當 c == 0 時，直接輸出 d0)
        weight = 16'd0; 
        
        case (s)
            4'd2: begin
                if (c == 4'd1) weight = 16'd32768; // 1/2
            end
            4'd3: begin
                if (c == 4'd1) weight = 16'd21845; // 1/3
                if (c == 4'd2) weight = 16'd43690; // 2/3
            end
            4'd4: begin
                if (c == 4'd1) weight = 16'd16384; // 1/4
                if (c == 4'd2) weight = 16'd32768; // 2/4 (1/2)
                if (c == 4'd3) weight = 16'd49152; // 3/4
            end
            4'd5: begin
                if (c == 4'd1) weight = 16'd13107; // 1/5
                if (c == 4'd2) weight = 16'd26214; // 2/5
                if (c == 4'd3) weight = 16'd39321; // 3/5
                if (c == 4'd4) weight = 16'd52428; // 4/5
            end
            4'd6: begin
                if (c == 4'd1) weight = 16'd10922; // 1/6
                if (c == 4'd2) weight = 16'd21845; // 2/6 (1/3)
                if (c == 4'd3) weight = 16'd32768; // 3/6 (1/2)
                if (c == 4'd4) weight = 16'd43690; // 4/6 (2/3)
                if (c == 4'd5) weight = 16'd54613; // 5/6
            end
            4'd7: begin
                if (c == 4'd1) weight = 16'd9362;  // 1/7
                if (c == 4'd2) weight = 16'd18724; // 2/7
                if (c == 4'd3) weight = 16'd28086; // 3/7
                if (c == 4'd4) weight = 16'd37449; // 4/7
                if (c == 4'd5) weight = 16'd46811; // 5/7
                if (c == 4'd6) weight = 16'd56173; // 6/7
            end
            4'd8: begin
                if (c == 4'd1) weight = 16'd8192;  // 1/8
                if (c == 4'd2) weight = 16'd16384; // 2/8 (1/4)
                if (c == 4'd3) weight = 16'd24576; // 3/8
                if (c == 4'd4) weight = 16'd32768; // 4/8 (1/2)
                if (c == 4'd5) weight = 16'd40960; // 5/8
                if (c == 4'd6) weight = 16'd49152; // 6/8 (3/4)
                if (c == 4'd7) weight = 16'd57344; // 7/8
            end
            default: weight = 16'd0;
        endcase
    end

    // 將 weight 前面補一個 0，強迫系統把它當成「正數」的有號數來乘
    // 這樣 diff(有號) * weight(正數) 才能算出正確的正負號結果
    assign mult = diff * $signed({1'b0, weight});

    // 步驟 4：加回基準點，輸出結果
    // mult[31:16] 等同於 (mult >> 16)，也就是除以 65536 還原真實比例
    assign o_data = $signed(d0) + 16'($signed(mult) >>> 16);

endmodule