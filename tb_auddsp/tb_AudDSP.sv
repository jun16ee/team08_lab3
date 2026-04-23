`timescale 1ns/1ps

module tb_AudDSP_Full();

    // ====================================================
    // 1. 訊號宣告
    // ====================================================
    logic i_rst_n;
    logic i_clk;
    
    // 新增的控制訊號
    logic i_start;
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

    logic [2:0]dsp_state;

    // ====================================================
    // 2. 實例化被測模組 (UUT)
    // ====================================================
    AudDSP uut (
        .i_rst_n(i_rst_n),
        .i_clk(i_clk),
        .i_play(i_start),
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
    // 注意：你的狀態機是跟著 daclrck 的邊緣跑的
    initial begin
        i_daclrck = 0;
        forever #100 i_daclrck = ~i_daclrck;
    end

    // ====================================================
    // 4. 建立 Mock SRAM (假記憶體)
    // ====================================================
    logic [15:0] fake_sram [0:1023];
    initial begin
        for (int i = 0; i < 1024; i++) begin
            fake_sram[i] = i * 16'd1000;
        end
    end

    assign i_sram_data = fake_sram[o_sram_addr[9:0]];

    // ====================================================
    // 5. 測試劇本 (Test Scenarios)
    // ====================================================
    initial begin
        $fsdbDumpfile("wave_AudDSP_Full.fsdb");
        $fsdbDumpvars(0, tb_AudDSP_Full);

        // 初始化所有輸入
        i_rst_n  = 0;
        i_start  = 0;
        i_pause  = 0;
        i_stop   = 0;
        i_speed  = 4'd1;
        i_fast   = 0;
        i_slow_0 = 0;
        i_slow_1 = 0;

        #25; 
        i_rst_n  = 1;
        #100;

        // ----------------------------------------------------
        // [測試 1] 開始播放 (正常速度 1x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 1] Start Playback (Normal 1x) ---", $time);
        i_start = 1;      // 給予 Start Pulse
        #10 i_start = 0;
        
        #2000; // 讓它跑幾個 LRCK 週期，觀察 addr = 0, 1, 2, 3...

        // ----------------------------------------------------
        // [測試 2] 播放中切換：2倍速快轉 (Fast 2x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 2] Change to Fast Forward (2x) ---", $time);
        i_fast  = 1;
        i_speed = 4'd2;
        
        #2000; // 觀察 addr 跳躍 = 4, 6, 8, 10...

        // ----------------------------------------------------
        // [測試 3] 暫停播放 (Pause)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 3] Pause Playback ---", $time);
        i_pause = 1;      // 給予 Pause Pulse
        #10 i_pause = 0;
        
        #1000; // 觀察 addr 是否凍結，且 o_en 是否為 0

        // ----------------------------------------------------
        // [測試 4] 恢復播放：切換到 1/4 慢速常數內插 (Slow_0 4x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 4] Resume Playback -> Slow Motion Constant (1/4x) ---", $time);
        // 設定速度與模式
        i_fast   = 0;
        i_slow_0 = 1;
        i_speed  = 4'd4;
        
        // 依照 RTL，給予 Start 訊號來恢復播放
        i_start = 1;      
        #10 i_start = 0;

        #4000; // 需要長一點的時間觀察同一個 Data 維持 4 個 LRCK 週期

        // ----------------------------------------------------
        // [測試 5] 播放中切換：1/4 慢速線性內插 (Slow_1 4x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 5] Change to Slow Motion Linear (1/4x) ---", $time);
        i_slow_0 = 0;
        i_slow_1 = 1;
        i_speed  = 4'd4;

        #4000; // 觀察 DAC 輸出是否出現平滑的階梯值

        // ----------------------------------------------------
        // [測試 6] 停止播放 (Stop)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 6] Stop Playback ---", $time);
        i_stop = 1;       // 給予 Stop Pulse
        #10 i_stop = 0;

        #1000; // 觀察系統是否回到 S_IDLE，並準備好接受下一次 Start

        $display("\n[%0t] --- Simulation Finished ---", $time);
        $finish;
    end

endmodule