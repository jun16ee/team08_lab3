`timescale 1ns/1ps

module tb_AudDSP_Full();

    // ====================================================
    // 1. 訊號宣告
    // ====================================================
    logic i_rst_n;
    logic i_clk;
    
    // 控制訊號 (One-hot 狀態)
    logic i_play;
    logic i_pause;
    logic i_stop;

    logic i_daclrck;
    logic [3:0] i_speed;
    logic i_fast;
    logic i_slow_0;
    logic i_slow_1;
    logic [15:0] i_sram_data;

    logic [15:0] o_dac_data;
    logic o_en;
    logic [19:0] o_sram_addr;

    logic [2:0] dsp_state;

    // ====================================================
    // 2. 實例化被測模組 (UUT)
    // ====================================================
    AudDSP uut (
        .i_rst_n(i_rst_n),
        .i_clk(i_clk),
        .i_play(i_play),
        .i_pause(i_pause),
        .i_stop(i_stop),
        .i_daclrck(i_daclrck),
        .i_speed(i_speed),
        .i_fast(i_fast),
        .i_slow_0(i_slow_0),
        .i_slow_1(i_slow_1),
        .i_sram_data(i_sram_data),
        .o_dac_data(o_dac_data),
        .o_en(o_en),
        .o_sram_addr(o_sram_addr),
        .dsp_state(dsp_state)
    );

    // ====================================================
    // 3. 產生 Clock
    // ====================================================
    // System Clock (100MHz, 週期 10ns)
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    // LRCK (模擬音訊時脈，週期 200ns)
    initial begin
        i_daclrck = 0;
        forever #100 i_daclrck = ~i_daclrck;
    end

    // ====================================================
    // 4. 建立 Mock SRAM (假記憶體)
    // ====================================================
    logic [15:0] fake_sram [0:8191]; // 加大 SRAM 容量以應付長時期快轉
    initial begin
        for (int i = 0; i < 8192; i++) begin
            fake_sram[i] = i * 16'd1000; // 每個 Address 的 Data 增加 1000 方便觀察階梯
        end
    end

    // 保護避免 Address 爆掉導致 Simulation Error
    assign i_sram_data = fake_sram[o_sram_addr[12:0]];

    // ====================================================
    // 5. 測試劇本 (Test Scenarios)
    // ====================================================
    
    // 寫一個簡單的 Task 來切換狀態，確保 One-hot 且乾淨
    task set_control(input p_play, input p_pause, input p_stop);
        begin
            i_play  = p_play;
            i_pause = p_pause;
            i_stop  = p_stop;
        end
    endtask

    task set_mode(input f, input s0, input s1, input [3:0] spd);
        begin
            i_fast   = f;
            i_slow_0 = s0;
            i_slow_1 = s1;
            i_speed  = spd;
        end
    endtask

    initial begin
        $fsdbDumpfile("AudDSP_new.fsdb");
        $fsdbDumpvars(0, tb_AudDSP_Full);

        // 初始化所有輸入
        i_rst_n  = 0;
        set_control(0, 0, 1); // 預設在 Stop 狀態
        set_mode(0, 0, 0, 4'd1);

        #25; 
        i_rst_n  = 1;
        #200;

        // ----------------------------------------------------
        // [測試 1] 開始播放 (正常速度 1x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 1] Start Playback (Normal 1x) ---", $time);
        set_control(1, 0, 0); 
        set_mode(0, 0, 0, 4'd1);
        #10000; // 跑 50 個 LRCK 週期，確認 address 穩定的 +1

        // ----------------------------------------------------
        // [測試 2] 播放中切換：2倍速快轉 (Fast 2x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 2] Change to Fast Forward (2x) ---", $time);
        set_mode(1, 0, 0, 4'd2);
        #10000; // 跑 50 個 LRCK 週期，確認 address 每次 +2

        // ----------------------------------------------------
        // [測試 3] 播放中切換：極限 8倍速快轉 (Fast 8x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 3] Change to Extreme Fast Forward (8x) ---", $time);
        set_mode(1, 0, 0, 4'd8);
        #10000; // 確認 address 每次 +8，且沒有漏 Data

        // ----------------------------------------------------
        // [測試 4] 暫停播放 (Pause)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 4] Pause Playback ---", $time);
        set_control(0, 1, 0); 
        #5000; // 長時間暫停，確認 Address 完全凍結，o_en 為 0

        // ----------------------------------------------------
        // [測試 5] 恢復播放：切換到 1/4 慢速常數內插 (Slow_0 4x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 5] Resume Playback -> Slow Motion Constant (1/4x) ---", $time);
        set_control(1, 0, 0); 
        set_mode(0, 1, 0, 4'd4);
        #20000; // 需要長一點的時間，觀察同一個 Data 維持 4 個 LRCK 週期後才跳下一個

        // ----------------------------------------------------
        // [測試 6] 播放中切換：1/8 慢速常數內插 (極限慢放 Slow_0 8x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 6] Slow Motion Constant (1/8x) ---", $time);
        set_mode(0, 1, 0, 4'd8);
        #40000; // 每個 Data 維持 8 個週期

        // ----------------------------------------------------
        // [測試 7] 播放中切換：1/4 慢速線性內插 (Slow_1 4x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 7] Change to Slow Motion Linear (1/4x) ---", $time);
        set_mode(0, 0, 1, 4'd4);
        #20000; // 觀察 DAC 輸出是否出現平滑的階梯值 (例如: 1000 -> 1250 -> 1500 -> 1750 -> 2000)

        // ----------------------------------------------------
        // [測試 8] 播放中切換：1/8 慢速線性內插 (極限慢放 Slow_1 8x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 8] Slow Motion Linear (1/8x) ---", $time);
        set_mode(0, 0, 1, 4'd8);
        #40000; // 觀察更細緻的階梯

        // ----------------------------------------------------
        // [測試 9] 停止播放 (Stop)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 9] Stop Playback ---", $time);
        set_control(0, 0, 1); 
        #5000; // 觀察系統是否回到 S_RESET，o_en 為 0

        // ----------------------------------------------------
        // [測試 10] 重新開始播放 (確認 Address 有被洗掉歸零)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 10] Restart Playback (Check Address Reset) ---", $time);
        set_control(1, 0, 0); 
        set_mode(0, 0, 0, 4'd1); // 回到正常一倍速
        #10000; // 觀察 SRAM Address 是否確實從 0 開始爬升

        $display("\n[%0t] --- Simulation Finished Successfully ---", $time);
        $finish;
    end

endmodule