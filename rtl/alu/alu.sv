module alu (
    input logic [31:0] a,               // rs1/pc
    input logic [31:0] b,               // rs2/imm
    input logic [16:0] instruction,    

    output logic [31:0] rd,
    output logic illegal_instruction
);


endmodule
