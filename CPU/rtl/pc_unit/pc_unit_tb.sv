module pc_unit_tb ();

    logic clk, reset;
    logic [15:0] imm, pc_new, isr_target, isr_return, pc_assert;
    logic [1:0] jump;
    logic       pcflag;
    logic       interrupt;
    logic       pc_misaligned;

    pc_unit dut (
        .clk(clk),
        .reset(reset),
        .pcflag(pcflag),
        .jump(jump),
        .imm(imm),
        .pc_new(pc_new),
        .interrupt(interrupt),
        .isr_target(isr_target),
        .isr_return(isr_return),
        .pc_misaligned(pc_misaligned)
    );

    logic [68:0] tests[$];
    logic [68:0] test;

    assign reset = test[68];
    assign interrupt = test[67];
    assign pcflag = test[66];
    assign jump = test[65:64];
    assign imm = test[63:48];
    assign isr_target = test[47:32];
    assign isr_return = test[31:16];
    assign pc_assert = test[15:0];

    always begin
        clk = 1;
        forever #1 clk = ~clk;
    end

    initial begin
        $dumpfile("pc_unit_tb.vcd");
        $dumpvars(0, dut, test, pc_assert);

        // Add test cases
        //               res   intr pcflag jump    imm      target  ret    assert
        tests.push_back({1'b1, 1'b0, 1'b0, 2'b10, 16'(0), 16'd0, 16'd0, 16'(0)});
        tests.push_back({1'b0, 1'b0, 1'b0, 2'b00, 16'hABCD, 16'd0, 16'd0, 16'(0)});  // no pcflag
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd0, 16'd0, 16'(4)});  // +4
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd0, 16'd0, 16'(8)});
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd0, 16'd0, 16'(12)});
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b01, 16'(1234), 16'd0, 16'd0, 16'(1234)});  // direct jump
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b00, 16'(10), 16'd0, 16'd0, 16'(1244)});  // indirect jump forward
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b00, 16'(-10), 16'd0, 16'd0, 16'(1234)});  // indirect jump backward
        tests.push_back({1'b0, 1'b0, 1'b0, 2'b01, 16'h1000, 16'd0, 16'd0, 16'(1234)});  // no pcflag
        tests.push_back({1'b1, 1'b0, 1'b1, 2'b00, 16'h1000, 16'd0, 16'd0, 16'h0000});  // reset
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd0, 16'd0, 16'(4)});  // +4
        tests.push_back({1'b0, 1'b1, 1'b0, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(200)});  // interrupt
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(204)});  // +4
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(208)});  // +4
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b11, 16'hABCD, 16'd200, 16'd8, 16'(8)});  // return from intr
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(12)});  // +4 normal
        tests.push_back({1'b0, 1'b0, 1'b1, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(16)});  // +4 normal
        tests.push_back({1'b0, 1'b1, 1'b1, 2'b10, 16'hABCD, 16'd200, 16'd8, 16'(200)});  // interrupt + pcflag
        tests.push_back({1'b1, 1'b0, 1'b1, 2'b00, 16'h1000, 16'd0, 16'd0, 16'h0000});  // reset

        // Test all cases and report errors
        while (tests.size > 0) begin
            test = tests.pop_front();
            #2;
            assert (pc_assert == pc_new)
            else
                $error(
                    "\033[31mWrong result for reset = %b, interrupt = %b, pcflag = %b, jump = %b, imm = %h, isr_target = %h, isr_return = %h. Expected pc = %h but was %h\033[0m",
                    reset,
                    interrupt,
                    pcflag,
                    jump,
                    imm,
                    isr_target,
                    isr_return,
                    pc_assert,
                    pc_new
                );

           assert (pc_misaligned == (pc_assert[1:0] != 2'b00))
           else
                $error(
                    "\033[31mExpected pc_misaligned = %b for pc = %h\033[0m",
                    pc_assert[1:0] != 2'b00,
                    pc_assert
                );
        end

        $display("\033[32mTestbench finished running\033[0m");
        $finish;
    end

endmodule  // instructioncounter_tb
