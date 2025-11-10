module control (
    input logic        clk,
    input logic        reset,
    input logic [31:0] iword,
    input logic        mem_busy,
    input logic        mem_valid,

    output logic [31:0] immediate,
    output logic [ 5:0] control_flags,
    output logic        wbflag,
    output logic        memflag,
    output logic        pcflag,
    output logic        fetchflag,
    output logic        mem_ce,

    input logic interrupt_pending,
    input logic [2:0] exceptions,
    output logic jump_to_isr,
    output logic mret,
    output logic csr_write
);

endmodule
