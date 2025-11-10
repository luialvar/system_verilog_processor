module alu (
    input logic [31:0] a,               // rs1/pc
    input logic [31:0] b,               // rs2/imm
    input logic [16:0] instruction,     // [16:10] func7, [9:7] func3, [6:0] opcode

    output logic [31:0] rd,
    output logic illegal_instruction
);


always_comb begin
    illegal_instruction = 0;
    case(instruction[6:0])
        7'b0110011: begin // R-type
            case(instruction[9:7]) // func3
                3'b000: begin
                    case(instruction[16:10]) // func7
                        7'b0000000: rd = a + b;
                        7'b0100000: rd = a - b;
                        7'b0000001: rd = a * b;
                        default: begin
                            rd = 32'b0;
                            illegal_instruction = 1;
                        end
                    endcase
                end
                3'b001: rd = a << b[4:0];           // SLL
                3'b010: rd = $signed(a) < $signed(b) ? 32'b1 : 32'b0; // SLT  (signed comparison)
                3'b011: rd = a < b ? 32'b1 : 32'b0; // SLTU (unsigned comparison)
                3'b100: rd = a ^ b; // XOR (a & ~b) | (~a & b) 
                3'b101: begin 
                    case(instruction[16:10]) // func7
                        7'b0100000: rd = a >>> b[4:0]; //SRA
                        7'b0000000: rd = a >> b[4:0]; //SRL
                        default: begin
                            rd = 32'b0;
                            illegal_instruction = 1;
                        end
                    endcase
                end
                3'b110: rd = a | b; // OR
                3'b111: rd = a & b;
            endcase
        end

        7'b0010011: begin // I-type
            case(instruction[9:7]) // func3
                3'b000: rd = a + b; // ADDI
                3'b111: rd = a & b; // ANDI
                3'b110: rd = a | b; // ORI
                3'b100: rd = a ^ b; // XORI
                3'b010: rd = $signed(a) < $signed(b) ? 32'b1 : 32'b0; // SLTI
                3'b011: rd = a < b ? 32'b1 : 32'b0; // SLTIU
                3'b101: begin
                    case(instruction[16:10])
                        7'b0100000: rd = a >>> b[4:0]; //SRAI
                        7'b0000000: rd = a >> b[4:0]; //SRLI
                        default: begin
                            rd = 32'b0;
                            illegal_instruction = 1;
                        end
                    endcase
                end
                default: begin
                            rd = 32'b0;
                            illegal_instruction = 1;
                end
            endcase
        end
        
        7'b0110111: begin // I-type LUI
            rd = b;       // imm << 12
        end

        7'b0010111: begin // I-type AUIPC
            rd = a + b;   // PC + (imm << 12)
        end
        
        7'b0000011: begin //I-type, LW
            rd = a + b;   //calculate address
        end
        
        7'b0000000: begin
        end
        
        7'b0000000: begin
        end
        
        default: begin
            rd = 32'b0;
            illegal_instruction = 1;
        end
    endcase
end

endmodule
