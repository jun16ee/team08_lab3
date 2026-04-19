module AudRecorder(  //只讀右聲道
    input        i_rst_n,
    input        i_clk,
    input        i_lrc, // high時read，low時放好(也就是每次falling edge時更新addr和data)
    // one-hot (Top那邊維護，至少high其中一個)
    // 一定在i_lrc falling edge 變成stop或pause 
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
        S_REST,
        S_READ
    } rec_state_t;

    rec_state_t state_r, state_w;
    logic [3:0] read_counter_r, read_counter_w;
    logic [15:0] read_data_r, read_data_w;
    logic [19:0] write_addr_r, write_addr_w;
    logic read_finish_flag_r, read_finish_flag_w;

    assign o_address = (state_r==S_REST) ? write_addr_r : 20'd0; //default 位置(不write)
    assign o_data = (state_r==S_REST) ? read_data_r : 16'd0;
    assign o_stop_address = write_addr_r; //給Top看
    // assign wen = (state_r==S_REST);
    //S_READ時read_data_r 會逐bit改變

    always_comb begin
        read_counter_w = read_counter_r;
        read_data_w = read_data_r;
        state_w = state_r;
        write_addr_w = write_addr_r;
        read_finish_flag_w = read_finish_flag_r;
        case(state_r)
            S_IDLE: begin
                if (i_lrc && i_rec) begin
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                    write_addr_w = 20'd0; //重新開始了 要initialize
                end
            end

            S_PAUSED: begin
                if (i_lrc && i_rec) begin
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                    // 不用把addr歸零initialize
                end
            end

            S_REST: begin
                if (i_lrc) begin
                    state_w = S_READ;
                    read_counter_w = 4'd15;
                    read_finish_flag_w = 1'b0;
                end
            end

            S_READ: begin
                if (read_counter_r == 4'd0 && !read_finish_flag_r) begin //read LSB
                    read_data_w[read_counter_r] = i_data;
                    read_counter_w = read_counter_r;
                    read_finish_flag_w = 1'b1;
                end else if (!read_finish_flag_r) begin //read 其他bit
                    read_data_w[read_counter_r] = i_data;
                    read_counter_w = read_counter_r - 1'b1;
                end // read完: 什麼都不做
                // NL
                if (!i_lrc) begin
                    case(1'b1)
                        i_stop:  state_w = S_IDLE;
                        i_pause: state_w = S_PAUSED;
                        i_rec: begin
                            state_w = S_REST;
                            if (read_finish_flag_r) begin
                                write_addr_w = write_addr_r + 20'd1;
                            end
                        end
                        default: state_w = S_IDLE;
                    endcase
                end
            end
        endcase
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin //bclk negedge 放資料 (posedge被取樣)
        if (!i_rst_n) begin
            state_r <= S_IDLE;
            read_counter_r <= 4'd15;
            read_data_r <= 16'd0;
            write_addr_r <= 20'd0;
            read_finish_flag_r <= 1'b0; 
        end
        else begin
            state_r <= state_w;
            read_counter_r <= read_counter_w;
            read_data_r <= read_data_w;
            write_addr_r <= write_addr_w;
            read_finish_flag_r <= read_finish_flag_w; 
        end
    end

endmodule