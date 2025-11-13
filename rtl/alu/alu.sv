module alu (
    input logic [31:0] a,               // rs1/pc
    input logic [31:0] b,               // rs2/imm
    input logic [16:0] instruction,     // [16:10] func7, [9:7] func3, [6:0] opcode

    output logic [31:0] rd,
    output logic illegal_instruction
);


always_comb begin
    illegal_instruction = 0;
    rd = 32'b0;
    case(instruction[6:0])
        7'b0110011: begin // R-type
            case(instruction[9:7]) // func3
                3'b000: begin
                    case(instruction[16:10]) // func7
                        7'b0000000: rd = a + b;
                        7'b0100000: rd = a - b;
                        7'b0000001: rd = a * b;
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b001: rd = a << b[4:0];           // SLL
                3'b010: rd = $signed(a) < $signed(b) ? 32'b1 : 32'b0; // SLT  (signed comparison)
                3'b011: rd = a < b ? 32'b1 : 32'b0; // SLTU (unsigned comparison)
                3'b100: rd = a ^ b; // XOR (a & ~b) | (~a & b) 
                3'b101: begin 
                    case(instruction[16:10]) // func7
                        7'b0100000: rd = $signed(a) >>> $signed(b[4:0]); //SRA
                        7'b0000000: rd = a >> b[4:0]; //SRL
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b110: rd = a | b; // OR
                3'b111: rd = a & b;
            endcase
        end

        7'b0010011: begin // I-type
            case(instruction[9:7]) // func3
                3'b001: rd = a << b[4:0]; // SLLI, [4:0] not included in instructions, but works
                3'b000: rd = a + b; // ADDI
                3'b111: rd = a & b; // ANDI
                3'b110: rd = a | b; // ORI
                3'b100: rd = a ^ b; // XORI
                3'b010: rd = $signed(a) < $signed(b);// ? 32'b1 : 32'b0; // SLTI
                3'b011: rd = a < b;// ? 32'b1 : 32'b0; // SLTIU
                3'b101: begin
                    case(instruction[16:10])
                        7'b0100000: rd = $signed(a) >>> $signed(b[4:0]); //SRAI
                        7'b0000000: rd = a >> b[4:0]; //SRLI
                        default: illegal_instruction = 1;
                    endcase
                end
                default: illegal_instruction = 1;
            endcase
        end
        
        7'b0110111: begin // I-type LUI
            rd = b;       // imm << 12
        end

        7'b0010111, 7'b0000011, 7'b0100011: begin // I-type AUIPC, LW, SW
            rd = a + b;   // PC + (imm << 12)
        end
        
        7'b1100011: begin // S-type
            rd = 32'b0;   //default value
            case(instruction[9:7])
                3'b000: rd[17] = a != b;                    // BEQ branch if a == b;
                3'b001: rd[17] = a == b;                    // BNE branch if a != b;
                3'b100: rd[17] = $signed(a) >= $signed(b);   // BLT branch if a < b
                3'b101: rd[17] = $signed(a) < $signed(b);   // BGE branch if a >= b
                3'b110: rd[17] = a >= b;                    // BLTU branch if a < b unsigned
                3'b111: rd[17] = a < b;                     // BGEU branch if a >= b unsigned
                default: illegal_instruction = 1;
            endcase
        end
        
        7'b1101111: begin // U-type JAL, case necessary to prevent illegal_instruction to be thrown
            rd = 32'b0;
        end
        
        7'b1100111: begin // I-type JALR
            rd = {{15{1'b0}}, 1'b1, a[15:1] + b[15:1], 1'b0}; //rd[17:16] = 01, rd[15:1] = a + b, rd[0] = 0
        end
        
        7'b1110011: begin 
            case(instruction[9:7])
                3'b010, 3'b001, 3'b000: begin //CSRR, CSRW, MRET,  case necessary to prevent illegal_instruction to be thrown
                    rd = 32'b0;
                end
                default: illegal_instruction = 1;
            endcase
        end
        
        default: illegal_instruction = 1;

    endcase
end

endmodule
