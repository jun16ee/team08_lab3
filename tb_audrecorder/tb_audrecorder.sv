`timescale 1ns/1ps
`timescale 1ns/1ps

module tb_AudRecorder();

    logic        clk;
    logic        rst_n;
    logic        lrc;
    logic        sdata;
    
    // 控制訊號
    logic        cmd_rec;
    logic        cmd_pause;
    logic        cmd_stop;

    logic [19:0] out_addr;
    logic [15:0] out_data;

    AudRecorder dut (
        .i_rst_n   (rst_n),
        .i_clk     (clk),
        .i_lrc     (lrc),
        .i_rec     (cmd_rec),
        .i_pause   (cmd_pause),
        .i_stop    (cmd_stop),
        .i_data    (sdata),
        .o_address (out_addr),
        .o_data    (out_data)
    );

    // Clock Generation (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 傳送音訊的 Task
    task send_audio_word(input [15:0] test_data, input logic is_rec, input logic is_pause, input logic is_stop);
        begin
            // 模擬 Top module 在 LRC falling edge (lrc 還是 0 的時候) 設定控制訊號
            cmd_rec   = is_rec;
            cmd_pause = is_pause;
            cmd_stop  = is_stop;
            
            // 等待一下讓電路反應控制訊號 (進入 S_REST 或是 S_PAUSED)
            repeat(2) @(negedge clk);
            
            // LRC 升起，開始讀取資料
            lrc = 1'b1; 
            sdata = test_data[15]; 
            @(negedge clk);
            
            for (int i = 15; i >= 0; i--) begin
                sdata = test_data[i];
                @(negedge clk);
            end
            
            // 讀取結束，LRC 降下
            lrc = 1'b0;
            sdata = 1'b0;
            
            // 留一段時間觀察寫入的 Address 變化
            repeat(5) @(negedge clk);
        end
    endtask

    initial begin
        rst_n     = 1'b0;
        lrc       = 1'b0;
        sdata     = 1'b0;
        cmd_rec   = 1'b0;
        cmd_pause = 1'b0;
        cmd_stop  = 1'b1; // 預設處於 Stop

        #15 rst_n = 1'b1;
        #10;

        $display("--- Test 1: Idle (Should ignore data) ---");
        // 資料: 16'h1111, 控制訊號: Stop
        send_audio_word(16'h1111, 1'b0, 1'b0, 1'b1);
        
        $display("--- Test 2: Start Recording (Address should be 0) ---");
        // 資料: 16'hA5A5, 控制訊號: Rec
        send_audio_word(16'hA5A5, 1'b1, 1'b0, 1'b0);

        $display("--- Test 3: Continue Recording (Address should be 1) ---");
        // 資料: 16'h2222, 控制訊號: Rec
        send_audio_word(16'h2222, 1'b1, 1'b0, 1'b0);

        $display("--- Test 4: Pause Recording (Should ignore data, keep Address) ---");
        // 資料: 16'hDEAD, 控制訊號: Pause
        send_audio_word(16'hDEAD, 1'b0, 1'b1, 1'b0);

        $display("--- Test 5: Resume Recording (Address should be 2) ---");
        // 資料: 16'h3333, 控制訊號: Rec
        send_audio_word(16'h3333, 1'b1, 1'b0, 1'b0);

        $display("--- Test 6: Stop Recording (Goes back to Idle) ---");
        // 資料: 16'hFFFF, 控制訊號: Stop
        send_audio_word(16'hFFFF, 1'b0, 1'b0, 1'b1);

        #50;
        $display("--- Simulation Finished ---");
        $finish;
    end

    initial begin
        $fsdbDumpfile("audrecorder_wave.fsdb");
        $fsdbDumpvars(0, tb_AudRecorder);
    end

endmodule