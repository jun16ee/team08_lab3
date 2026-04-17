`timescale 1ns/1ps

module tb_AudDSP_Datapath();

    // ====================================================
    // 1. 訊號宣告
    // ====================================================
    logic i_rst_n;
    logic i_clk;
    logic i_daclrck;
    logic [3:0] i_speed;
    logic i_fast;
    logic i_slow_0;
    logic i_slow_1;
    logic [15:0] i_sram_data;

    logic [15:0] o_dac_data;
    logic [19:0] o_sram_addr;

    // ====================================================
    // 2. 實例化被測模組 (UUT)
    // ====================================================
    AudDSP uut (
        .i_rst_n(i_rst_n),
        .i_clk(i_clk),
        .i_daclrck(i_daclrck),
        .i_speed(i_speed),
        .i_fast(i_fast),
        .i_slow_0(i_slow_0),
        .i_slow_1(i_slow_1),
        .i_sram_data(i_sram_data),
        .o_dac_data(o_dac_data),
        .o_sram_addr(o_sram_addr)
    );

    // ====================================================
    // 3. 產生 Clock (100MHz, 週期 10ns)
    // ====================================================
    initial begin
        i_clk = 0;
        forever #5 i_clk = ~i_clk;
    end

    initial begin
        i_daclrck = 0;
        forever #100 i_daclrck = ~i_daclrck;
    end

    // ====================================================
    // 4. 建立 Mock SRAM (假記憶體)
    // ====================================================
    logic [15:0] fake_sram [0:1023];
    initial begin
        // 為了方便觀察內插法，我們把 SRAM 的資料設定為 1000 的倍數
        // Address: 0, 1, 2, 3, 4 ...
        // Data   : 0, 1000, 2000, 3000, 4000 ...
        for (int i = 0; i < 1024; i++) begin
            fake_sram[i] = i * 16'd1000;
        end
    end

    // 模擬 0-cycle 延遲的 SRAM 讀取 (Combinational Read)
    // 注意：只取低 10 bit 避免存取超出 array 範圍
    assign i_sram_data = fake_sram[o_sram_addr[9:0]];

    // ====================================================
    // 5. 測試劇本 (Test Scenarios)
    // ====================================================
    initial begin
        // 產生波形檔 (VCD) 供 GTKWave 觀看
        $fsdbDumpfile("wave_AudDSP_Datapath.fsdb");
        $fsdbDumpvars(0, tb_AudDSP_Datapath);

        // 啟動 Console 監聽器，每當數值改變就印出來
        // $monitor("Time: %5t | Fast:%b Slow0:%b Slow1:%b Spd:%0d | SRAM_Addr: %4d | DAC_Out: %4d", 
                //   $time/1000, i_fast, i_slow_0, i_slow_1, i_speed, o_sram_addr, o_dac_data);

        // 初始化
        i_rst_n  = 0;
        i_speed  = 4'd1;
        i_fast   = 0;
        i_slow_0 = 0;
        i_slow_1 = 0;

        #25; // 等待 2.5 個 Clock 放開 Reset
        i_rst_n  = 1;

        // ----------------------------------------------------
        // [測資 1] 正常速度 (Normal: 1x)
        // 預期輸出: 0, 1000, 2000, 3000... (注意會有 Pipeline Latency)
        // ----------------------------------------------------
        $display("\n--- [Test 1] Normal Speed (1x) ---");
        #1000; // 跑 10 個 Cycle

        // ----------------------------------------------------
        // [測資 2] 2倍速快轉 (Fast: 2x)
        // 預期 SRAM_Addr 跳躍: +2, +2...
        // 預期輸出: 2000, 4000, 6000...
        // ----------------------------------------------------
        $display("\n--- [Test 2] Fast Forward (2x) ---");
        i_fast   = 1;
        i_slow_0 = 0;
        i_slow_1 = 0;
        i_speed  = 4'd2;
        #1000; // 跑 10 個 Cycle

        // ----------------------------------------------------
        // [測資 3] 1/4 慢速 - 常數內插 (Slow_0: Hold 4x)
        // 預期 SRAM_Addr 跳躍: 每 4 個 cycle 才 +1
        // 預期輸出: 同一個數值連續輸出 4 次
        // ----------------------------------------------------
        $display("\n--- [Test 3] Slow Motion - Constant (1/4x) ---");
        i_fast   = 0;
        i_slow_0 = 1;
        i_slow_1 = 0;
        i_speed  = 4'd7;
        #2000; // 跑 20 個 Cycle，觀察完整週期

        // ----------------------------------------------------
        // [測資 4] 1/4 慢速 - 線性內插 (Slow_1: Linear 4x)
        // 預期 SRAM_Addr 跳躍: 每 4 個 cycle 才 +1
        // 預期輸出 (以 4000 到 5000 為例): 4000, 4250, 4500, 4750...
        // ----------------------------------------------------
        $display("\n--- [Test 4] Slow Motion - Linear (1/4x) ---");
        i_fast   = 0;
        i_slow_0 = 0;
        i_slow_1 = 1;
        i_speed  = 4'd5;
        #2500; // 跑 25 個 Cycle，仔細觀察小數點內插階梯

        $display("\n--- Simulation Finished ---");
        $finish;
    end

endmodule