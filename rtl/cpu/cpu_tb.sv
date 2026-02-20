module cpu_tb ();

    logic clk, reset, memwrite, valid, busy, ce;
    logic so, si, sclk, sram_ce;
    logic rst_n;
    logic intr_ext;

    int period = 2;

    cpu dut (
        .clk(clk),
        .reset(rst_n),
        .so(so),
        .si(si),
        .sclk(sclk),
        .sram_ce(sram_ce),
        .intr_ext(intr_ext)
    );
    

    sram_sim #(
        //.INIT_FILE("./M_Extension_test.txt")
        //.INIT_FILE("../../asm/exceptions_test/exceptions_test.txt")
        //.INIT_FILE("../../asm/blinky/blinky.txt")
        //.INIT_FILE("../../asm/threed/main.txt")
        .INIT_FILE("../../asm/cache_test/cache_test_1.txt")
    ) sram (
        .sclk(sclk),
        .reset(reset),
        .ce(sram_ce),
        .si(si),
        .so(so)
    );

    always begin
        clk   = 0;
        reset = 1;
        rst_n = 0;

        forever #1 clk = ~clk;
    end

    logic [7:0] memory_content [200];
    generate
        genvar i;
        for(i = 0; i < 200; i = i+1) begin
            assign memory_content[i] = sram.mem[i]; //changed to i + 5000
        end
    endgenerate
    /*
    logic [31:0] d_cache_content [128];
    generate
        for(i = 0; i < 128; i = i+1) begin
            assign d_cache_content[i] = dut.memory.sram_master.d_cache[i];
        end
    endgenerate
    logic [31:0] i_cache_content [128];
    generate
        for(i = 0; i < 128; i = i+1) begin
            assign i_cache_content[i] = dut.memory.sram_master.i_cache[i];
        end
    endgenerate*/

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0, dut, sram);

        // Uncomment and adjust the name to your own instance names for regs
        // and registers
        // for (int i = 0; i < 32; i++) $dumpvars(0, dut.regs.registers[i]);

        for (int i = 0; i < 200; i++) $dumpvars(1, memory_content[i]);
        //for (int i = 0; i < 128; i++) $dumpvars(1, d_cache_content[i]);
        //for (int i = 0; i < 128; i++) $dumpvars(1, i_cache_content[i]);
        //$dumpvars(1, sram.mem[16777212]);  //last usable addresses
        //$dumpvars(1, sram.mem[16777208]);

        #20;
        reset = 0;
        rst_n = 1;
        #20000;
        //#100000;
        #1000000; //looong simulation
        //#500000;
        //rst_n = 1'b0;  // reset during execution
        //#10;
        //rst_n = 1'b1;
       // #500000;
        $display("\033[32mTestbench finished running! Verify with the waveform\033[0m");
        $finish;
    end

    // initial begin : ext_interrupt
    //     intr_ext = 0;
    //     #10000;
    //     intr_ext = 0;
    //     // intr_ext = 1;
    //     #2;
    //     intr_ext = 0;
    // end

endmodule  // cputb
