module csr (
    input logic clk,
    input logic reset,

    // Interrupt signals
    input  logic       intr_timer,
    input  logic       intr_ext,
    input  logic [2:0] exceptions,
    input  logic       mret,
    input  logic       enter_isr,
    output logic       interrupt_pending,

    // Signals for reading/writing CSRs
    input  logic [31:0] data_in,
    input  logic [11:0] addr,
    input  logic        write_en,
    output logic [31:0] data_out,

    input  logic [15:0] pc,
    output logic [15:0] isr_return,
    output logic [15:0] isr_target
);

endmodule
