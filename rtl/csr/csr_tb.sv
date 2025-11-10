module csr_tb ();

    logic        clk = 0;
    logic        reset;

    int half_period = 1;
    int period = 2 * half_period;

    logic        mret;
    logic [2:0]  exceptions;
    logic        intr_timer;
    logic        intr_ext;


    logic [31:0] data_in;
    logic [11:0] addr;
    logic        write_en;
    logic [31:0] data_out;

    logic [15:0] pc;
    logic [15:0] isr_return;
    logic [15:0] isr_target;
    logic        trap_occured;
    logic        interrupt_pending;
    logic        enter_isr;

    csr dut (
        .clk(clk),
        .reset(reset),
        .intr_timer(intr_timer),
        .intr_ext(intr_ext),
        .exceptions(exceptions),
        .mret(mret),
        .interrupt_pending(interrupt_pending),
        .enter_isr(enter_isr),
        .data_in(data_in),
        .addr(addr),
        .write_en(write_en),
        .data_out(data_out),
        .pc(pc),
        .isr_return(isr_return),
        .isr_target(isr_target)
    );

    typedef struct packed {
        logic        reset;
        logic [ 2:0] exceptions;
        logic        intr_timer;
        logic        intr_ext;
        logic        mret;
        logic        enter_isr;
        logic [31:0] data_in;
        logic [11:0] addr;
        logic        write_en;
        logic [15:0] pc;
        // To assert:
        logic        interrupt_pending;
        logic [31:0] data_out;
        logic [15:0] isr_return;
        logic [15:0] isr_target;
    } test_case;

    test_case [0:74] test_cases;

    logic [11:0] MSTATUS = 12'h300;
    logic [11:0] MIE = 12'h304;
    logic [11:0] MTVEC = 12'h305;
    logic [11:0] MEPC = 12'h341;
    logic [11:0] MCAUSE = 12'h342;
    logic [11:0] MIP = 12'h344;

    initial test_cases = '{
    //   rst   excep   timer  ext  mret  enter_isr   d_in       addr   write  pc    pend       d_out    return     target
    // Testing reset. mstatus, mie == 0
        {1'b1, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'h00000000, 16'h0000, 16'hXXXX}, // Test  0
        {1'b1, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIE, 1'b0, 16'h0, 1'b0, 32'h00000000, 16'h0000, 16'hXXXX}, // Test  1
    // Testing write and read to CSRs (except MIP since this is written by hardware)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'hABCDEF12, MSTATUS, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h0000, 16'hXXXX}, // Test  2: WR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'hABCDEF12, 16'h0000, 16'hXXXX}, // Test  3: RD
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'hF0F0ABCD,     MIE, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h0000, 16'hXXXX}, // Test  4: WR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIE, 1'b0, 16'h0, 1'b0, 32'hF0F0ABCD, 16'h0000, 16'hXXXX}, // Test  5: RD
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h98712345,   MTVEC, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h0000, 16'hXXXX}, // Test  6: WR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,   MTVEC, 1'b0, 16'h0, 1'b0, 32'h98712345, 16'h0000, 16'hXXXX}, // Test  7: RD
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'hA5A51234,    MEPC, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test  8: WR (return == mepc[15:0]!)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,    MEPC, 1'b0, 16'h0, 1'b0, 32'hA5A51234, 16'h1234, 16'hXXXX}, // Test  9: RD
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'hFFFFFFFF,  MCAUSE, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test 10: WR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'h0, 1'b0, 32'hFFFFFFFF, 16'h1234, 16'hXXXX}, // Test 11: RD

    // Testing deactivated interrupts now
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b1, 16'h0, 1'b0, 32'h00000000, 16'h1234, 16'hXXXX}, // Test 12: Deactivate interrupts
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'h00000000, 16'h1234, 16'hXXXX}, // Test 13: Timer intr. Should do nothing
        {1'b0, 3'b000, 1'b0, 1'b1, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'h00000000, 16'h1234, 16'hXXXX}, // Test 14: Ext intr. Should do nothing
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIE, 1'b1, 16'h0, 1'b0, 32'h00000000, 16'h1234, 16'hXXXX}, // Test 15: Deactivate all individual intrs
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000008, MSTATUS, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test 16: Activate interrupts globally
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'h00000008, 16'h1234, 16'hXXXX}, // Test 17: Timer intr. Still ignored
        {1'b0, 3'b000, 1'b0, 1'b1, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'h0, 1'b0, 32'h00000008, 16'h1234, 16'hXXXX}, // Test 18: Ext intr. Still ignored

    // Testing interrupt handling. First setting up mtvec and mie
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000401,   MTVEC, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test 19: mtvec setup 0x100 + 01
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,   MTVEC, 1'b0, 16'h0, 1'b0, 32'h00000401, 16'h1234, 16'hXXXX}, // Test 20: mtvec verify
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIP, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test 21: clearing all interrupts
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0,    32'(2176),     MIE, 1'b1, 16'h0, 1'b0, 32'hXXXXXXXX, 16'h1234, 16'hXXXX}, // Test 22: mie setup (bit 11, 7 to 1)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIE, 1'b0, 16'h0, 1'b0,    32'(2176), 16'h1234, 16'hXXXX}, // Test 23: mie verify

    // Timer interrupt
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b1, 32'h00000008, 16'h1234, 16'hXXXX}, // Test 24: timer interrupt occured
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b1, 32'h00000008, 16'h1234, 16'h041C}, // Test 25: timer interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'd8, 1'b1, 32'h80000007, 16'h1234, 16'h041C}, // Test 26: timer interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'hD, 1'b1, 32'h80000007, 16'h1234, 16'h041C}, // Test 27: timer interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b1, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000000, 16'h000D, 16'h041C}, // Test 28: interrupt cleared (mstatus should be zero since intr disabled)
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000000, 16'h000D, 16'h041C}, // Test 29: cpu running ISR
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000000, 16'h000D, 16'h041C}, // Test 30:      ="=
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000000, 16'h000D, 16'h041C}, // Test 31:      ="=
        {1'b0, 3'b000, 1'b1, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000D, 16'h041C}, // Test 32:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000008, 16'h000D, 16'h041C}, // Test 33: mret. Returning from ISR (interrupts should be enabled again)

    // External interrupt
        {1'b0, 3'b000, 1'b0, 1'b1, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b1, 32'h00000008, 16'h000D, 16'hXXXX}, // Test 34: ext interrupt occured (latched internally)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b1, 32'h00000008, 16'h000D, 16'h042C}, // Test 35: ext interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'd8, 1'b1, 32'h8000000B, 16'h000D, 16'h042C}, // Test 36: ext interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'hE, 1'b1, 32'h8000000B, 16'h000D, 16'h042C}, // Test 37: ext interrupt handled, waiting for clear
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b1, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 38: interrupt cleared (mstatus should be zero since intr disabled)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,     MIP, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 39: interrupt cleared (external bit in mip should be cleared by the module)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 40: cpu running ISR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 41:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 42:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000000, 16'h000E, 16'h042C}, // Test 43:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000008, 16'h000E, 16'h042C}, // Test 44: mret. Returning from ISR (interrupts should be enabled again)

    // Testing pc_misaligned exception
        {1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd3, 1'b0, 32'h00000008, 16'h000E, 16'hXXXX}, // Test 45: pc_misaligned exception
        {1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd3, 1'b0, 32'h00000008, 16'h000E, 16'hXXXX}, // Test 46: pc_misaligned exception
        {1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd3, 1'b0, 32'h00000008, 16'h000E, 16'hXXXX}, // Test 47: pc_misaligned exception
        {1'b0, 3'b001, 1'b0, 1'b0, 1'b0, 1'b1, 32'h00000000, MSTATUS, 1'b0, 16'd3, 1'b0, 32'h00000000, 16'h0003, 16'hXXXX}, // Test 48: pc_misaligned exception handled (intrs deactivated)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0003, 16'h0400}, // Test 49: checking correct mcause
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0003, 16'h0400}, // Test 50: cpu running ISR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0003, 16'h0400}, // Test 51:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0003, 16'h0400}, // Test 52:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000000, 16'h0003, 16'h0400}, // Test 53:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000008, 16'h0003, 16'h0400}, // Test 54: mret. Returning from ISR (interrupts should be enabled again)

    // Testing illegal_instruction exception
        {1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b0, 32'h00000008, 16'h0003, 16'hXXXX}, // Test 55: illegal_instruction exception
        {1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b0, 32'h00000008, 16'h0003, 16'hXXXX}, // Test 56: illegal_instruction exception
        {1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b0, 32'h00000008, 16'h0003, 16'hXXXX}, // Test 57: illegal_instruction exception
        {1'b0, 3'b010, 1'b0, 1'b0, 1'b0, 1'b1, 32'h00000000, MSTATUS, 1'b0, 16'd4, 1'b0, 32'h00000000, 16'h0004, 16'hXXXX}, // Test 58: illegal_instruction exception handled (intrs deactivated)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'hE, 1'b0, 32'h00000002, 16'h0004, 16'h0400}, // Test 59: checking correct mcause
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0004, 16'h0400}, // Test 60: cpu running ISR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0004, 16'h0400}, // Test 61:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h0004, 16'h0400}, // Test 62:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000000, 16'h0004, 16'h0400}, // Test 63:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000008, 16'h0004, 16'h0400}, // Test 64: mret. Returning from ISR (interrupts should be enabled again)

    // Testing load_access_fault exception
        {1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000008, 16'h0004, 16'hXXXX}, // Test 65: load_access_fault exception
        {1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000008, 16'h0004, 16'hXXXX}, // Test 66: load_access_fault exception
        {1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000008, 16'h0004, 16'hXXXX}, // Test 67: load_access_fault exception
        {1'b0, 3'b100, 1'b0, 1'b0, 1'b0, 1'b1, 32'h00000000, MSTATUS, 1'b0, 16'hD, 1'b0, 32'h00000000, 16'h000D, 16'hXXXX}, // Test 68: load_access_fault exception handled (intrs deactivated)
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000,  MCAUSE, 1'b0, 16'hE, 1'b0, 32'h00000005, 16'h000D, 16'h0400}, // Test 69: checking correct mcause
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000D, 16'h0400}, // Test 70: cpu running ISR
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000D, 16'h0400}, // Test 71:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hE, 1'b0, 32'h00000000, 16'h000D, 16'h0400}, // Test 72:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000000, 16'h000D, 16'h0400}, // Test 73:      ="=
        {1'b0, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 32'h00000000, MSTATUS, 1'b0, 16'hF, 1'b0, 32'h00000008, 16'h000D, 16'h0400} // Test 74: mret. Returning from ISR (interrupts should be enabled again)
    };

    test_case test = test_cases[0];

    always #1 clk = ~clk;

    assign reset = test.reset;
    assign exceptions = test.exceptions;
    assign intr_timer = test.intr_timer;
    assign intr_ext = test.intr_ext;
    assign mret = test.mret;
    assign enter_isr = test.enter_isr;
    assign data_in = test.data_in;
    assign addr = test.addr;
    assign write_en = test.write_en;
    assign pc = test.pc;

    initial begin
        $dumpfile("csr_tb.vcd");
        $dumpvars(0, dut, test);

        // Align to rising edge
        #half_period;

        foreach (test_cases[i]) begin
            test = test_cases[i];
            #period;

            assert (interrupt_pending == test.interrupt_pending)
            else
                $error(
                    "\033[31mTest %0d failed: Wrong interrupt_pending. Expected %b but got %b\033[0m",
                    i,
                    test.interrupt_pending,
                    interrupt_pending
                );

            // This comparison looks weird but it actually only fails
            // on undefined values and is true else. HACK to avoid some assertions
            // if they are fine being undefined by making the test vector undefined
            if (test.data_out == 0 || test.data_out != 0) begin
                assert (data_out == test.data_out)
                else
                    $error(
                        "\033[31mTest %0d failed: Wrong data_out. Expected %h but got %h\033[0m",
                        i,
                        test.data_out,
                        data_out
                    );
            end

            if (test.isr_return == 0 || test.isr_return != 0) begin
                assert (isr_return == test.isr_return)
                else
                    $error(
                        "\033[31mTest %0d failed: Wrong isr_return. Expected %h but got %h\033[0m",
                        i,
                        test.isr_return,
                        isr_return
                    );
            end

            if (test.isr_target == 0 || test.isr_target != 0) begin
                assert (isr_target == test.isr_target)
                else
                    $error(
                        "\033[31mTest %0d failed: Wrong isr_target. Expected %h but got %h\033[0m",
                        i,
                        test.isr_target,
                        isr_target
                    );
            end

        end

        $display("\033[32mTestbench finished running\033[0m");
        $finish;
    end

endmodule
