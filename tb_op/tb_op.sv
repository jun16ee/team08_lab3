`timescale 1ns/1ps
module tb_AudSystem_Integration();

    // ====================================================
    // 1. 系統與控制訊號宣告
    // ====================================================
    logic i_rst_n;
    logic i_AUD_BCLK;
    logic i_AUD_DACLRCK;
    
    // DSP 控制訊號 (One-hot)
    logic dsp_play;
    logic dsp_pause;
    logic dsp_stop;

    // DSP 速度與模式訊號
    logic [3:0] speedx;
    logic dsp_fast;
    logic dsp_slow0;
    logic dsp_slow1;
    
    // SRAM 資料
    logic [15:0] data_play;

    // 模組間互連訊號 (Interconnects)
    logic [15:0] dac_data;
    logic play_en;
    logic [19:0] addr_play;
    logic [2:0]  dsp_state;

    // 最終輸出至 DAC 的序列資料
    logic o_AUD_DACDAT;

    // ====================================================
    // 2. 實例化被測模組 (UUT)
    // ====================================================
    
    // --- 實例化 AudDSP ---
    AudDSP dsp0(
        .i_rst_n(i_rst_n),
        .i_clk(i_AUD_BCLK), // DSP 的 i_clk 接到 BCLK
        .i_play(dsp_play),
        .i_pause(dsp_pause),
        .i_stop(dsp_stop),
        .i_speed(speedx),
        .i_fast(dsp_fast),
        .i_slow_0(dsp_slow0),
        .i_slow_1(dsp_slow1),
        .i_daclrck(i_AUD_DACLRCK),
        .i_sram_data(data_play),
        .o_dac_data(dac_data),
        .o_en(play_en),
        .o_sram_addr(addr_play),
        .dsp_state(dsp_state)
    );

    // --- 實例化 AudPlayer ---
    AudPlayer player0(
        .i_rst_n(i_rst_n),
        .i_bclk(i_AUD_BCLK),
        .i_daclrck(i_AUD_DACLRCK),
        .i_en(play_en),
        .i_dac_data(dac_data),
        .o_aud_dacdat(o_AUD_DACDAT)
    );

    // ====================================================
    // 3. 產生 Clocks (BCLK 與 DACLRCK 同步)
    // ====================================================
    
    // 產生 BCLK (Bit Clock): 假設頻率為 100MHz (週期 10ns)
    initial begin
        i_AUD_BCLK = 0;
        forever #5 i_AUD_BCLK = ~i_AUD_BCLK;
    end

    // 產生 DACLRCK: 由 BCLK 除頻產生，確保時序邊緣穩定
    // I2S 16-bit 標準：半個 LRCK 週期包含至少 16~32 個 BCLK
    // 這裡我們設定 1 個 LRCK 週期 = 64 個 BCLK 週期 (左32, 右32)
    logic [5:0] bclk_div; 
    always_ff @(negedge i_AUD_BCLK or negedge i_rst_n) begin
        if (!i_rst_n) begin
            bclk_div <= 6'd0;
        end else begin
            bclk_div <= bclk_div + 1'b1;
        end
    end
    // 最高位元作為 LRCK，這樣會在 BCLK negedge 翻轉，確保 BCLK posedge 取樣穩定
    assign i_AUD_DACLRCK = bclk_div[5]; 

    // ====================================================
    // 4. 建立 Mock SRAM (假記憶體)
    // ====================================================
    logic [15:0] fake_sram [0:8191]; 
    initial begin
        for (int i = 0; i < 8192; i++) begin
            // 給予 16'hA___ 開頭的資料 (1010_xxxx)，這樣序列化輸出時很好辨認
            // 例如: Addr 0 -> 16'hA000, Addr 1 -> 16'hA001
            fake_sram[i] = 16'hA000 + i; 
        end
    end

    assign data_play = fake_sram[addr_play[12:0]];

    // ====================================================
    // 5. 測試控制 Tasks
    // ====================================================
    task set_control(input logic p_play, input logic p_pause, input logic p_stop);
        begin
            dsp_play  = p_play;
            dsp_pause = p_pause;
            dsp_stop  = p_stop;
        end
    endtask

    task set_mode(input logic f, input logic s0, input logic s1, input logic [3:0] spd);
        begin
            dsp_fast  = f;
            dsp_slow0 = s0;
            dsp_slow1 = s1;
            speedx    = spd;
        end
    endtask

    // ====================================================
    // 6. 測試劇本 (Test Scenarios)
    // ====================================================
    initial begin
        $fsdbDumpfile("wave_AudSystem_Integration.fsdb");
        $fsdbDumpvars(0, tb_AudSystem_Integration);

        // 初始化
        i_rst_n = 0;
        set_control(0, 0, 1); // 預設 Stop
        set_mode(0, 0, 0, 4'd1);

        #45; 
        i_rst_n = 1;
        #200;

        // ----------------------------------------------------
        // [測試 1] 開始播放 (正常 1倍速)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 1] Playback Started (1x Normal) ---", $time);
        set_control(1, 0, 0); 
        
        // 觀察重點：
        // 1. dsp_state 是否進入 READY/OUTPUT
        // 2. 當 i_AUD_DACLRCK == 1 時，Player 是否開始把 16'hA000 轉成 Serial
        // 3. o_AUD_DACDAT 是否能在 BCLK 週期正確出現 1, 0, 1, 0...
        #15000; 

        // ----------------------------------------------------
        // [測試 2] 暫停播放 (Pause)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 2] Playback Paused ---", $time);
        set_control(0, 1, 0); 
        
        // 觀察重點：play_en 應變為 0，o_AUD_DACDAT 應保持 0，序列推移停止
        #10000;

        // ----------------------------------------------------
        // [測試 3] 恢復播放 + 2倍速快轉 (Fast 2x)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 3] Resume & Fast Forward (2x) ---", $time);
        set_control(1, 0, 0); 
        set_mode(1, 0, 0, 4'd2);
        
        // 觀察重點：addr_play 是否一次跳 +2，Player 吐出的序列資料是否對應更新的位址
        #15000;

        // ----------------------------------------------------
        // [測試 4] 切換為 4倍慢放 (Slow 0, Constant)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 4] Slow Motion Constant (4x) ---", $time);
        set_mode(0, 1, 0, 4'd4);
        
        // 觀察重點：Player 連續 4 個 DACLRCK 週期吐出完全相同的 Serial Data
        #30000;

        // ----------------------------------------------------
        // [測試 5] 停止播放 (Stop)
        // ----------------------------------------------------
        $display("\n[%0t] --- [Test 5] Playback Stopped ---", $time);
        set_control(0, 0, 1); 
        
        // 觀察系統是否安靜，所有內部狀態歸零
        #5000;

        $display("\n[%0t] --- Simulation Finished Successfully ---", $time);
        $finish;
    end

endmodule