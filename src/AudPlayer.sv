module AudPlayer(
	input i_rst_n,
	input i_bclk,
	input i_daclrck,
	input i_en, // enable AudPlayer only when playing audio
	input [15:0] i_dac_data, //dac_data passed by audDSP
	output o_aud_dacdat // pass to wm8731
);
    logic op_r, op_w;
    assign o_aud_dacdat = op_r;

    typedef enum logic [1:0] {
        S_IDLE,
        S_PASS,
        S_FINISH
    } state_t;

    state_t state_r, state_w;

    logic [3:0] counter_r, counter_w;

    // 只傳right channel
    always_comb begin 
        state_w = state_r;
        counter_w = counter_r;
        op_w = 0; // 沒事的時候讓訊號線保持 0
        case(state_r)
            S_IDLE: begin
                if (i_en && i_daclrck == 1'b1) begin //first cycle
                    state_w = S_PASS;
                    op_w = i_dac_data[15];
                    counter_w = 4'd14;
                    // 1-Bit Delay：
                    // counter_w = 4'd15;
                    // op_w = 1'b0;
                end else begin
                    op_w = 1'b0; // 沒事的時候讓訊號線保持 0
                end
            end

            S_PASS: begin 
                op_w = i_dac_data[counter_r];
                counter_w = counter_r - 1'b1;
                if (counter_r==4'd0) begin
                    state_w = S_FINISH;
                end
            end

            S_FINISH: begin
                op_w = 1'b0; // 沒事的時候讓訊號線保持 0
                if (!i_daclrck) begin//right channel 時間結束
                    state_w = S_IDLE;
                end
            end
        endcase
    end

    always_ff @(negedge i_bclk or negedge i_rst_n) begin //bclk negedge 放資料 (posedge被取樣)
        if (!i_rst_n) begin
            op_r <= 1'b0;
            counter_r <= 4'd15;
            state_r <= S_IDLE;
        end
        else begin
            if (i_en) begin
                state_r <= state_w;
                op_r <= op_w;
                counter_r <= counter_w;
            end
        end
    end
endmodule