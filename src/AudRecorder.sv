module AudRecorder(  // 只讀右聲道
    input        i_rst_n,
    input        i_clk, // BCLK
    input        i_lrc, // DACLRCK / ADCLRCK
    input        i_rec,
    input        i_pause,
    input        i_stop,

    input        i_data,
    output[19:0] o_address,
    output[19:0] o_stop_address,
    output[15:0] o_data
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_PAUSED,
        S_REST, // 等待左聲道結束，同時也是寫入 SRAM 的時間
        S_READ  // 讀取右聲道
    } rec_state_t;

    rec_state_t state_r, state_w;
    logic [3:0] read_counter_r, read_counter_w;
    logic [15:0] read_data_r, read_data_w;
    logic [19:0] write_addr_r, write_addr_w;
    logic read_finish_flag_r, read_finish_flag_w;

    // === 新增：輸出端的 Register ===
    logic [15:0] o_data_w, o_data_r;
    logic [19:0] o_address_w, o_address_r;

    // 直接將輸出綁定在乾淨的 Output Register 上
    assign o_address = o_address_r;
    assign o_data    = o_data_r;
    assign o_stop_address = write_addr_r; // 這個給 Top 看內部進度，用原來的即可

    always_comb begin
        // 預設保持原來的值
        state_w = state_r;
        read_counter_w = read_counter_r;
        read_data_w = read_data_r;
        write_addr_w = write_addr_r;
        read_finish_flag_w = read_finish_flag_r;
        o_data_w = o_data_r;
        o_address_w = o_address_r;

        case(state_r)
            S_IDLE: begin
                if (i_lrc && i_rec) begin
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                    write_addr_w = 20'd0; // 重新開始，位址歸零
                end
            end

            S_PAUSED: begin
                if (i_lrc && i_rec) begin
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                    // PAUSE 恢復，保持原來的 write_addr_r
                end else if (i_stop) begin
                    state_w = S_IDLE;
                end
            end

            S_READ: begin
                // Shift Register 讀取資料
                if (!read_finish_flag_r) begin
                    read_data_w = {read_data_r[14:0], i_data};
                    
                    if (read_counter_r == 4'd0) begin
                        read_finish_flag_w = 1'b1; // 讀滿 16 bits 就不再 shift
                    end else begin
                        read_counter_w = read_counter_r - 1'b1;
                    end
                end

                // 換聲道 (Right -> Left)，準備進入 S_REST
                if (!i_lrc) begin
                    if (i_stop) begin
                        state_w = S_IDLE;
                    end else if (i_pause) begin
                        state_w = S_PAUSED;
                    end else if (i_rec) begin
                        state_w = S_REST;
                        
                        // ✨ 關鍵邏輯：在這裡 Latch 輸出！
                        // 當確認要進入 S_REST 寫入 SRAM，且資料已讀完時，
                        // 把結果推給 Output Register，這樣整個 S_REST 期間輸出都會完美保持
                        if (read_finish_flag_r) begin
                            o_data_w = read_data_r;
                            o_address_w = write_addr_r;
                        end
                        
                    end else begin
                        state_w = S_IDLE;
                    end
                end
            end

            S_REST: begin
                if (i_stop) begin
                    state_w = S_IDLE;
                end else if (i_pause) begin
                    state_w = S_PAUSED;
                end else if (i_lrc) begin
                    // 準備進入下一個週期的錄音
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                    
                    if (read_finish_flag_r) begin 
                        write_addr_w = write_addr_r + 20'd1; // 在這裡更新下一次的內部 Address
                    end
                end
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state_r <= S_IDLE;
            read_counter_r <= 4'd15;
            read_data_r <= 16'd0;
            write_addr_r <= 20'd0;
            read_finish_flag_r <= 1'b0; 
            
            // Output FF Reset
            o_data_r <= 16'd0;
            o_address_r <= 20'd0;
        end
        else begin
            state_r <= state_w;
            read_counter_r <= read_counter_w;
            read_data_r <= read_data_w;
            write_addr_r <= write_addr_w;
            read_finish_flag_r <= read_finish_flag_w; 
            
            // Output FF Update
            o_data_r <= o_data_w;
            o_address_r <= o_address_w;
        end
    end

endmodule