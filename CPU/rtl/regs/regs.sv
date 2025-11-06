module regs (
    input logic clk,
    input logic reset,

    input logic regwrite,

    input logic [4:0] rs1adr,
    input logic [4:0] rs2adr,
    input logic [4:0] rdadr,

    input  logic [31:0] rd,
    output logic [31:0] rs1,
    output logic [31:0] rs2
);

    logic [31:0] R[31:0];
    logic [31:0] rs1a;
    logic [31:0] rs2a;

    always_ff @(posedge clk) begin
        if (reset) begin
            rs1a <= 32'h00000000;
            rs2a <= 32'h00000000;
        end
        else if (regwrite) begin
            R[rdadr] <= rd;
        end
        else begin
            rs1a <= R[rs1adr];
            rs2a <= R[rs2adr];
        end
    end

    assign rs1 = rs1adr ? rs1a : 32'h00000000;
    assign rs2 = rs2adr ? rs2a : 32'h00000000;

endmodule  // regs
