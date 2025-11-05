module cpu (
    input logic clk,
    input logic reset, // active low due to pico-ice button
    input logic intr_ext,

    input  logic so,
    output logic si,
    output logic sclk,
    output logic sram_ce,

    output logic scl,
    inout  logic sda,

    output logic tx,

    input  logic [7:0] gpio_in,
    output logic [7:0] gpio_out
);

endmodule  // cpu
