`timescale 1ns/1ps
module tb_AudPlayer();

    // ==========================================
    // 1. 宣告連接 DUT (Device Under Test) 的訊號
    // ==========================================
    logic i_rst_n;
    logic i_bclk;
    logic i_daclrck;
    logic i_en;
    logic [15:0] i_dac_data;
    logic o_aud_dacdat;

    // ==========================================
    // 2. 實體化 (Instantiate) 你的 AudPlayer 模組
    // ==========================================
    AudPlayer dut (
        .i_rst_n(i_rst_n),
        .i_bclk(i_bclk),
        .i_daclrck(i_daclrck),
        .i_en(i_en),
        .i_dac_data(i_dac_data),
        .o_aud_dacdat(o_aud_dacdat)
    );

    // ==========================================
    // 3. 產生時鐘訊號 (Clock Generation)
    // ==========================================
    // 產生 BCLK (Bit Clock)：假設週期為 10ns (100MHz)
    initial begin
        i_bclk = 1'b0;
        forever #5 i_bclk = ~i_bclk; 
    end

    // 產生 LRCK (Left/Right Clock)
    // I2S 規定 LRCK 的切換必須發生在 BCLK 的「下降沿 (negedge)」
    // 假設一個聲道傳送 16 個 BCLK 週期
    initial begin
        i_daclrck = 1'b0; // 一開始先給左聲道 (0)
        
        // 先等一下，讓 LRCK 的變化對齊 BCLK 的下降沿
        repeat(20) @(negedge i_bclk); 
        
        forever begin
            repeat(20) @(negedge i_bclk); // 數 16 個 BCLK 下降沿
            i_daclrck <= ~i_daclrck;       // 翻轉聲道 (0變1, 1變0)
        end
    end

    // ==========================================
    // 4. 產生測試情境 (Stimulus)
    // ==========================================
    initial begin
        // --- 初始狀態 ---
        i_rst_n = 1'b0;
        i_en = 1'b0;
        i_dac_data = 16'h0000;

        // --- 解除 Reset ---
        #22; 
        i_rst_n = 1'b1;

        // --- 啟動模組 ---
        @(negedge i_bclk);
        i_en = 1'b1;

        // 【測試情境 1】準備送給右聲道 (LRCK=1) 的資料
        // 我們給 16'hA5A5 (二進位: 1010_0101_1010_0101)
        // 這種 1010 交錯的資料最容易在波形圖上看出有沒有掉 bit
        @(negedge i_daclrck); // 等待變成左聲道 (這時先把下一筆右聲道的資料準備好)
        i_dac_data = 16'hA5A5; 

        // 【測試情境 2】準備下一筆給右聲道的資料
        // 我們給 16'h3C3C (二進位: 0011_1100_0011_1100)
        @(negedge i_daclrck);
        i_dac_data = 16'h3C3C;

        // 【結束模擬】
        @(negedge i_daclrck);
        repeat(30) @(negedge i_bclk);
        $finish; // 停止模擬
    end

    // ==========================================
    // 5. 輸出波形檔 (Optional: 給 EDA 工具看波形用)
    // ==========================================
    initial begin
        $fsdbDumpfile("audplayer_wave.fsdb");
        $fsdbDumpvars(0, tb_AudPlayer);
    end

endmodule