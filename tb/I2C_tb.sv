`timescale 1ns/10ps



module I2C_tb();
    logic i_rst_n;
    logic i_clk_100k;
    logic i_start;
    logic o_finished;
    logic o_sclk;
    logic o_sdat;
    logic o_oen;
    // Clock Generation (100kHz)
    always #5000 i_clk_100k = ~i_clk_100k;

    I2cInitializer DUT(
        .i_rst_n(i_rst_n),
        .i_clk_100k(i_clk_100k),
        .i_start(i_start),
        .o_finished(o_finished),
        .o_sclk(o_sclk),
        .o_sdat(o_sdat),
        .o_oen(o_oen)
    );


    initial begin

        $fsdbDumpfile("I2C_tb.fsdb");
        $fsdbDumpvars(0, I2C_tb);
        i_rst_n = 0;
        i_clk_100k = 0;
        i_start = 0;
        #10000; // Hold reset for 10us
        i_rst_n = 1; // Release reset
        #10000; // Wait for 10us
        i_start = 1; // Start the I2C initialization
        #10000
        i_start = 0; // Stop the start signal

        fork
            begin
                wait (o_finished == 1);
                $display("I2C Initialization Finished!");
            end
            begin
                #2000000; // Timeout after 2ms (enough for 8 config words at 100kHz)
                $display("I2C Initialization Timeout!");
            end
        join_any
        $finish;
    end
    

endmodule