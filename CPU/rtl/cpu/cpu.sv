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
    logic invreset;
    logic ce;
    logic [31:0] addr;
    logic [31:0] mem_data_in;
    logic memwrite;
    logic [31:0] iword;
    logic fetchflag;
    logic [31:0] mem_data_out;
    logic busy;
    logic valid;
    logic intr_timer;
    logic load_access_fault;
    logic regwrite;
    logic [4:0] rdadr;
    logic [31:0] rd;
    logic [4:0] rs1adr;
    logic [4:0] rs2adr;

    memory memory(  .clk(clk),
                    .reset(invreset),
                    .ce(ce),
                    .addr(addr),
                    .datain(mem_data_in),
                    .memwrite(memwrite),
                    .so(so),
                    .sda(sda),
                    .gpio_in(gpio_in),
                    .data_out(mem_data_out),
                    .busy(busy),
                    .valid(valid),
                    .si(si),
                    .sclk(sclk),
                    .sram_ce(sram_ce),
                    .scl(scl),
                    .sda(sda),
                    .tx(tx),
                    .gpio_out(gpio_out)
                    .intr_timer(intr_timer),
                    .load_access_fault(load_access_fault))

    always_ff @(posedge clk) begin
        if(invreset) begin
            iword <= 32'b0;
        end
        if (fetchflag)  :   iword <= mem_data_out;

    end

    assign invreset = ~reset;

endmodule  // cpu
