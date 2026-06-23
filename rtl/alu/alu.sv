module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [16:0] instruction,
    output logic [31:0] rd,
    output logic        illegal_instruction
);

logic [6:0]  opcode;
logic [2:0]  funct3;
logic [6:0]  funct7;

always @* begin //same as comb
    // Valores por defecto (salidas definidas siempre):
    rd                 = 32'd0;
    illegal_instruction = 1'b0;

    opcode  = instruction[6:0];
    funct3  = instruction[9:7];
    funct7  = instruction[16:10];

    case (opcode)
        7'b0110011: begin  // R-Type arithmetic/logical
            case (funct3)
                3'b000: begin  // ADD, SUB, or MUL (distinguish by funct7)
                    case (funct7)
                        7'b0000000: rd = a + b;              // ADD
                        7'b0100000: rd = a - b;              // SUB
                        7'b0000001: rd = a * b;              // MUL (low 32 bits)
                        default:    illegal_instruction = 1; // not supported
                    endcase
                end
                3'b001: begin  // SLL (shift left logical)  // CHANGED: also supports MULH (funct7=0000001)
                    if (funct7 == 7'b0000000) rd = a << (b[4:0]); //a to the left b[4:0] in decimal, rest with 0s
                    else if (funct7 == 7'b0000001) begin
                        // BONUS: MULH (signed x signed) -> upper 32 bits of full 64-bit product
                        logic signed [63:0] prod_ss;
                        prod_ss = $signed(a) * $signed(b);
                        rd      = prod_ss[63:32];
                    end
                    else illegal_instruction = 1;
                end
                3'b010: begin  // SLT (set less than, signed) --> because default unsigned  // CHANGED: also supports MULHSU (funct7=0000001)
                    if (funct7 == 7'b0000000)
                        rd = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                    else if (funct7 == 7'b0000001) begin
                        // BONUS: MULHSU (signed rs1 x unsigned rs2) -> upper 32 bits of full 64-bit product
                        logic signed [64:0] prod_su;
                        prod_su = $signed(a) * $signed({1'b0, b});
                        rd      = prod_su[63:32];
                    end
                    else illegal_instruction = 1;
                end
                3'b011: begin  // SLTU (set less than, unsigned)  // CHANGED: also supports MULHU (funct7=0000001)
                    if (funct7 == 7'b0000000)
                        rd = (a < b) ? 32'd1 : 32'd0;
                    else if (funct7 == 7'b0000001) begin
                        // BONUS: MULHU (unsigned x unsigned) -> upper 32 bits of full 64-bit product
                        logic [63:0] prod_uu;
                        prod_uu = a * b;
                        rd      = prod_uu[63:32];
                    end
                    else illegal_instruction = 1;
                end
                3'b100: begin  // XOR
                    if (funct7 == 7'b0000000) rd = a ^ b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be DIV in M extension, not supported)
                end
                3'b101: begin  // SRL or SRA
                    case (funct7)
                        7'b0000000: rd = a >> (b[4:0]);                   // SRL, move a b[4:0] bits to the right
                        7'b0100000: rd = $signed(a) >>> (b[4:0]);         // SRA, this mantains the sign
                        7'b0000001: illegal_instruction = 1; // DIVU (M extension) not supported
                        default:    illegal_instruction = 1;
                    endcase
                end
                3'b110: begin  // OR
                    if (funct7 == 7'b0000000) rd = a | b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be REM in M extension)
                end
                3'b111: begin  // AND
                    if (funct7 == 7'b0000000) rd = a & b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be REMU in M extension)
                end
                default: illegal_instruction = 1;
            endcase
        end

        7'b0010011: begin  // I-Type arithmetic/logical (immediate)
            case (funct3)
                3'b000: rd = a + b;  // ADDI
                3'b010: rd = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLTI
                3'b011: rd = (a < b) ? 32'd1 : 32'd0;                  // SLTIU
                3'b100: rd = a ^ b;   // XORI
                3'b110: rd = a | b;   // ORI
                3'b111: rd = a & b;   // ANDI
                3'b001: begin         // SLLI (shift left logical immediate)
                    // Check upper immediate bits for validity (must be 0000000)
                    if (funct7 == 7'b0000000) rd = a << b[4:0];
                    else illegal_instruction = 1;
                end
                3'b101: begin         // SRLI or SRAI (shift right immediate)
                    case (funct7)
                        7'b0000000: rd = a >> b[4:0];           // SRLI
                        7'b0100000: rd = $signed(a) >>> b[4:0]; // SRAI
                        default: illegal_instruction = 1;
                    endcase
                end
                default: illegal_instruction = 1;
            endcase
        end

        7'b0000011: begin  // Load (e.g., LW)
            // We assume funct3=010 (LW) as valid. Still perform address calc for any load:
            rd = a + b;
            // Optionally, flag illegal if funct3 not supported (e.g., no LB/LH):
            if (funct3 != 3'b010) illegal_instruction = 1;
        end

        7'b0100011: begin  // Store (e.g., SW)
            // Calculate address (a = base, b = offset immediate)
            rd = a + b;
            // If funct3 not 010 (SW) and others not supported, mark illegal:
            if (funct3 != 3'b010) illegal_instruction = 1;
        end

        7'b1101111: begin  // JAL (unconditional jump)
            // Indicate an indirect jump (PC = PC + imm). PC unit will add immediate.
            rd[17:16] = 2'b00;
            rd[15:0]  = b[15:0];  // immediate offset (assuming b carries the offset)
            // (No direct arithmetic result; link address handled outside ALU)
        end

        7'b1100111: begin  // JALR (jump and link register)
            if (funct3 == 3'b000) begin
                // Calculate target address = a + b, then align LSB to 0
                logic [31:0] target;
                target      = a + b;
                target[0]   = 1'b0;
                rd[15:0]    = target[15:0];
                rd[17:16]   = 2'b01;   // direct jump code
            end
            else begin
                illegal_instruction = 1;
            end
        end

        7'b1100011: begin  // Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
    // rd ya vale 0 por defecto al principio del always, no tocamos los bits bajos
            logic take;
            take = 1'b0;

            case (funct3)
                3'b000: take = (a == b);                    // BEQ
                3'b001: take = (a != b);                    // BNE
                3'b100: take = ($signed(a) <  $signed(b));  // BLT
                3'b101: take = ($signed(a) >= $signed(b));  // BGE
                3'b110: take = (a <  b);                    // BLTU (unsigned)
                3'b111: take = (a >= b);                    // BGEU (unsigned)
                default: begin
                    take = 1'b0;
                    illegal_instruction = 1'b1;
                end
            endcase

            if (!illegal_instruction) begin
                // Sólo tocamos los bits 17:16, el resto se queda a 0
                rd[17:16] = (take) ? 2'b00 : 2'b10;
            end
        end

        7'b0110111: begin  // LUI (Load Upper Immediate)
            // rd = immediate (upper 20 bits already shifted into place by Imm Gen)
            rd = b;
        end

        7'b0010111: begin  // AUIPC (Add Upper Imm to PC)
            // rd = PC (in a) + immediate (in b)
            rd = a + b;
        end

        7'b1110011: begin  // SYSTEM: MRET, CSRR, CSRW
            case (funct3)
                3'b010: begin
                    // CSRR
                    // Instrucción válida, pero la ALU NO devuelve un valor.
                    // rd ya es 0 por defecto, no lo tocamos.
                end

                3'b001: begin
                    // CSRW
                    // Igual: instrucción válida, rd = 0.
                end

                3'b000: begin
                    // Puede ser MRET u otras cosas (ECALL/EBREAK, etc.)
                    if (funct7 == 7'b0011000) begin
                        // MRET: instrucción válida, rd = 0.
                        // NO pongas rd[17:16] a 2'b11 ni nada.
                    end
                    else begin
                        // Otras system no soportadas -> ilegal
                        illegal_instruction = 1'b1;
                    end
                end

                default: begin
                    // Cualquier otro funct3 -> ilegal
                    illegal_instruction = 1'b1;
                end
            endcase
        end
        default: begin
            // Opcode not recognized: illegal instruction
            illegal_instruction = 1;
        end
    endcase
end

endmodule

/* module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [16:0] instruction,
    output logic [31:0] rd,
    output logic        illegal_instruction
);

logic [6:0]  opcode;
logic [2:0]  funct3;
logic [6:0]  funct7;

always @* begin //same as comb
    // Valores por defecto (salidas definidas siempre):
    rd                 = 32'd0;
    illegal_instruction = 1'b0;

    opcode  = instruction[6:0];
    funct3  = instruction[9:7];
    funct7  = instruction[16:10];

    case (opcode)
        7'b0110011: begin  // R-Type arithmetic/logical
            case (funct3)
                3'b000: begin  // ADD, SUB, or MUL (distinguish by funct7)
                    case (funct7)
                        7'b0000000: rd = a + b;              // ADD
                        7'b0100000: rd = a - b;              // SUB
                        7'b0000001: rd = a * b;              // MUL (low 32 bits)
                        default:    illegal_instruction = 1; // not supported
                    endcase
                end
                3'b001: begin  // SLL (shift left logical)
                    if (funct7 == 7'b0000000) rd = a << (b[4:0]); //a to the left b[4:0] in decimal, rest with 0s
                    else illegal_instruction = 1;
                end
                3'b010: begin  // SLT (set less than, signed) --> because default unsigned
                    if (funct7 == 7'b0000000)
                        rd = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                    else illegal_instruction = 1;
                end
                3'b011: begin  // SLTU (set less than, unsigned)
                    if (funct7 == 7'b0000000)
                        rd = (a < b) ? 32'd1 : 32'd0;
                    else illegal_instruction = 1;
                end
                3'b100: begin  // XOR
                    if (funct7 == 7'b0000000) rd = a ^ b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be DIV in M extension, not supported)
                end
                3'b101: begin  // SRL or SRA
                    case (funct7)
                        7'b0000000: rd = a >> (b[4:0]);                   // SRL, move a b[4:0] bits to the right
                        7'b0100000: rd = $signed(a) >>> (b[4:0]);         // SRA, this mantains the sign
                        7'b0000001: illegal_instruction = 1; // DIVU (M extension) not supported
                        default:    illegal_instruction = 1;
                    endcase
                end
                3'b110: begin  // OR
                    if (funct7 == 7'b0000000) rd = a | b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be REM in M extension)
                end
                3'b111: begin  // AND
                    if (funct7 == 7'b0000000) rd = a & b;
                    else if (funct7 == 7'b0000001) illegal_instruction = 1;
                    else illegal_instruction = 1;
                    // (funct7 == 0000001 would be REMU in M extension)
                end
                default: illegal_instruction = 1;
            endcase
        end

        7'b0010011: begin  // I-Type arithmetic/logical (immediate)
            case (funct3)
                3'b000: rd = a + b;  // ADDI
                3'b010: rd = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLTI
                3'b011: rd = (a < b) ? 32'd1 : 32'd0;                  // SLTIU
                3'b100: rd = a ^ b;   // XORI
                3'b110: rd = a | b;   // ORI
                3'b111: rd = a & b;   // ANDI
                3'b001: begin         // SLLI (shift left logical immediate)
                    // Check upper immediate bits for validity (must be 0000000)
                    if (funct7 == 7'b0000000) rd = a << b[4:0];
                    else illegal_instruction = 1;
                end
                3'b101: begin         // SRLI or SRAI (shift right immediate)
                    case (funct7)
                        7'b0000000: rd = a >> b[4:0];           // SRLI
                        7'b0100000: rd = $signed(a) >>> b[4:0]; // SRAI
                        default: illegal_instruction = 1;
                    endcase
                end
                default: illegal_instruction = 1;
            endcase
        end

        7'b0000011: begin  // Load (e.g., LW)
            // We assume funct3=010 (LW) as valid. Still perform address calc for any load:
            rd = a + b;
            // Optionally, flag illegal if funct3 not supported (e.g., no LB/LH):
            if (funct3 != 3'b010) illegal_instruction = 1;
        end

        7'b0100011: begin  // Store (e.g., SW)
            // Calculate address (a = base, b = offset immediate)
            rd = a + b;
            // If funct3 not 010 (SW) and others not supported, mark illegal:
            if (funct3 != 3'b010) illegal_instruction = 1;
        end

        7'b1101111: begin  // JAL (unconditional jump)
            // Indicate an indirect jump (PC = PC + imm). PC unit will add immediate.
            rd[17:16] = 2'b00;
            rd[15:0]  = b[15:0];  // immediate offset (assuming b carries the offset)
            // (No direct arithmetic result; link address handled outside ALU)
        end

        7'b1100111: begin  // JALR (jump and link register)
            if (funct3 == 3'b000) begin
                // Calculate target address = a + b, then align LSB to 0
                logic [31:0] target;
                target      = a + b;
                target[0]   = 1'b0;
                rd[15:0]    = target[15:0];
                rd[17:16]   = 2'b01;   // direct jump code
            end
            else begin
                illegal_instruction = 1;
            end
        end

        7'b1100011: begin  // Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
    // rd ya vale 0 por defecto al principio del always, no tocamos los bits bajos
            logic take;
            take = 1'b0;

            case (funct3)
                3'b000: take = (a == b);                    // BEQ
                3'b001: take = (a != b);                    // BNE
                3'b100: take = ($signed(a) <  $signed(b));  // BLT
                3'b101: take = ($signed(a) >= $signed(b));  // BGE
                3'b110: take = (a <  b);                    // BLTU (unsigned)
                3'b111: take = (a >= b);                    // BGEU (unsigned)
                default: begin
                    take = 1'b0;
                    illegal_instruction = 1'b1;
                end
            endcase

            if (!illegal_instruction) begin
                // Sólo tocamos los bits 17:16, el resto se queda a 0
                rd[17:16] = (take) ? 2'b00 : 2'b10;
            end
        end

        7'b0110111: begin  // LUI (Load Upper Immediate)
            // rd = immediate (upper 20 bits already shifted into place by Imm Gen)
            rd = b;
        end

        7'b0010111: begin  // AUIPC (Add Upper Imm to PC)
            // rd = PC (in a) + immediate (in b)
            rd = a + b;
        end

        7'b1110011: begin  // SYSTEM: MRET, CSRR, CSRW
            case (funct3)
                3'b010: begin
                    // CSRR
                    // Instrucción válida, pero la ALU NO devuelve un valor.
                    // rd ya es 0 por defecto, no lo tocamos.
                end

                3'b001: begin
                    // CSRW
                    // Igual: instrucción válida, rd = 0.
                end

                3'b000: begin
                    // Puede ser MRET u otras cosas (ECALL/EBREAK, etc.)
                    if (funct7 == 7'b0011000) begin
                        // MRET: instrucción válida, rd = 0.
                        // NO pongas rd[17:16] a 2'b11 ni nada.
                    end
                    else begin
                        // Otras system no soportadas -> ilegal
                        illegal_instruction = 1'b1;
                    end
                end

                default: begin
                    // Cualquier otro funct3 -> ilegal
                    illegal_instruction = 1'b1;
                end
            endcase
        end
        default: begin
            // Opcode not recognized: illegal instruction
            illegal_instruction = 1;
        end
    endcase
end

endmodule

*/
