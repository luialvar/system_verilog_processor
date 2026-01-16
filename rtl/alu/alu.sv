module alu (
    input logic [31:0] a,               // rs1/pc
    input logic [31:0] b,               // rs2/imm
    input logic [16:0] instruction,     // [16:10] func7, [9:7] func3, [6:0] opcode
    input logic clk,
    input logic reset,

    output logic [31:0] rd,
    output logic illegal_instruction,
    output logic alu_busy
);

logic start_div;
logic is_signed;
logic is_rem;
logic div_busy;
logic [31:0] rd_alu;
logic [31:0] rd_div;
logic [31:0] dividend_q, dividend_d;
logic [31:0] divisor_q, divisor_d;
logic [31:0] quotient_q, quotient_d;
logic [31:0] remainder_q, remainder_d;
logic [31:0] rd_div_q, rd_div_d;
logic [5:0] counter_q, counter_d;
logic signed_q, signed_d;
logic isrem_q, isrem_d;

enum {NO_DIV, START, FIN} state_q, state_d;

always_ff @(posedge clk) begin
    if (reset) begin
        state_q <= NO_DIV;
        dividend_q <= 0;
        divisor_q <= 0;
        quotient_q <= 0;
        remainder_q <= 0;
        counter_q <= 0;
        signed_q <= 0;
        isrem_q <= 0;
        rd_div_q <= 0;
    end
    else begin
        state_q <= state_d;
        dividend_q <= dividend_d;
        divisor_q <= divisor_d;
        quotient_q <= quotient_d;
        remainder_q <= remainder_d;
        counter_q <= counter_d;
        signed_q <= signed_d;
        isrem_q <= isrem_d;
        rd_div_q <= rd_div_d;
    end
end

always_comb begin
    state_d = state_q;
    dividend_d = dividend_q;
    divisor_d = divisor_q;
    quotient_d = quotient_q;
    remainder_d = remainder_q;
    counter_d = counter_q;
    signed_d = signed_q;
    isrem_d = isrem_q;
    rd_div_d = rd_div_q;
    rd_div = 32'b0;
    
    case(state_q)
        NO_DIV: begin
            if (start_div) begin
                isrem_d = is_rem;
                signed_d = is_signed;
                dividend_d = is_signed ? $signed(a) : $unsigned(a);
                divisor_d = is_signed ? $signed(b) : $unsigned(b);
                quotient_d = 0;
                remainder_d = 0;
                counter_d = 32;
                state_d = START;
            end
        end
        START: begin
            remainder_d = {remainder_q[30:0], dividend_q[31]};
            dividend_d = {dividend_q[30:0], 1'b0};
            if (remainder_d >= divisor_q) begin
                remainder_d = remainder_d - divisor_q;
                quotient_d = {quotient_q[30:0], 1'b1};
            end
            else begin
                quotient_d = {quotient_q[30:0], 1'b0};
            end
            if (counter_q == 1) begin
                state_d   = FIN;
                counter_d = 0;
            end else begin
                counter_d = counter_q - 1;
            end

        end
        FIN: begin
            rd_div_d = isrem_q ? remainder_q : quotient_q;
            state_d = NO_DIV;
        end
    endcase
end

always_comb begin
    illegal_instruction = 0;
    rd_alu = 32'b0;
    start_div = 0;
    is_signed = 0;
    is_rem = 0;
    case(instruction[6:0])
        7'b0110011: begin // R-type
            case(instruction[9:7]) // func3
                3'b000: begin
                    case(instruction[16:10]) // func7
                        7'b0000000: rd_alu = a + b;
                        7'b0100000: rd_alu = a - b;
                        7'b0000001: rd_alu = a * b;
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b001: begin
                    case(instruction[16:10])
                        7'b0000000: rd_alu = a << b[4:0];                       // SLL
                        7'b0000001: rd_alu = ($signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b})) >>> 32;   // MULH
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b010: begin
                    case(instruction[16:10])
                        7'b0000000: rd_alu = $signed(a) < $signed(b) ? 32'b1 : 32'b0; // SLT  (signed comparison)
                        7'b0000001: rd_alu = ($signed({{32{a[31]}}, a}) * $signed({32'b0, b})) >> 32;      // MULHSU
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b011: begin
                    case(instruction[16:10])
                        7'b0000000: rd_alu = a < b ? 32'b1 : 32'b0; // SLTU (unsigned comparison)
                        7'b0000001: rd_alu = ($signed({32'b0, a}) * $signed({32'b0, b})) >> 32;                     // MULHU
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b100: begin
                    case(instruction[16:10])
                        7'b0000000: rd_alu = a ^ b; // XOR (a & ~b) | (~a & b) 
                        7'b0000001: begin       // DIV
                            start_div = 1;
                            is_signed = 1;
                            is_rem = 0;
                        end
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b101: begin 
                    case(instruction[16:10]) // func7
                        7'b0100000: rd_alu = $signed(a) >>> $signed(b[4:0]); //SRA
                        7'b0000000: rd_alu = a >> b[4:0]; //SRL
                        7'b0000001: begin   // DIVU
                            start_div = 1;
                            is_signed = 0;
                            is_rem = 0;
                        end
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b110: begin
                    case(instruction[16:10])
                        7'b0100000: rd_alu = a | b; // OR
                        7'b0000001: begin       // REM
                            start_div = 1;
                            is_signed = 1;
                            is_rem = 1;
                        end
                        default: illegal_instruction = 1;
                    endcase
                end
                3'b111: begin
                    case(instruction[16:10])
                        7'b0100000: rd_alu = a & b; // AND
                        7'b0000001: begin       // REMU
                            start_div = 1;
                            is_signed = 0;
                            is_rem = 1;
                        end
                        default: illegal_instruction = 1;
                    endcase
                end
            endcase
        end

        7'b0010011: begin // I-type
            case(instruction[9:7]) // func3
                3'b001: rd_alu = a << b[4:0]; // SLLI, [4:0] not included in instructions, but works
                3'b000: rd_alu = a + b; // ADDI
                3'b111: rd_alu = a & b; // ANDI
                3'b110: rd_alu = a | b; // ORI
                3'b100: rd_alu = a ^ b; // XORI
                3'b010: rd_alu = $signed(a) < $signed(b);// ? 32'b1 : 32'b0; // SLTI
                3'b011: rd_alu = a < b;// ? 32'b1 : 32'b0; // SLTIU
                3'b101: begin
                    case(instruction[16:10])
                        7'b0100000: rd_alu = $signed(a) >>> $signed(b[4:0]); //SRAI
                        7'b0000000: rd_alu = a >> b[4:0]; //SRLI
                        default: illegal_instruction = 1;
                    endcase
                end
                default: illegal_instruction = 1;
            endcase
        end
        
        7'b0110111: begin // I-type LUI
            rd_alu = b;       // imm << 12
        end

        7'b0010111, 7'b0000011, 7'b0100011: begin // I-type AUIPC, LW, SW
            rd_alu = a + b;   // PC + (imm << 12)
        end
        
        7'b1100011: begin // S-type
            rd_alu = 32'b0;   //default value
            case(instruction[9:7])
                3'b000: rd_alu[17] = a != b;                    // BEQ branch if a == b;
                3'b001: rd_alu[17] = a == b;                    // BNE branch if a != b;
                3'b100: rd_alu[17] = $signed(a) >= $signed(b);   // BLT branch if a < b
                3'b101: rd_alu[17] = $signed(a) < $signed(b);   // BGE branch if a >= b
                3'b110: rd_alu[17] = a >= b;                    // BLTU branch if a < b unsigned
                3'b111: rd_alu[17] = a < b;                     // BGEU branch if a >= b unsigned
                default: illegal_instruction = 1;
            endcase
        end
        
        7'b1101111: begin // U-type JAL, case necessary to prevent illegal_instruction to be thrown
            rd_alu = 32'b0;
        end
        
        7'b1100111: begin // I-type JALR
            rd_alu = {{15{1'b0}}, 1'b1, a[15:1] + b[15:1], 1'b0}; //rd[17:16] = 01, rd[15:1] = a + b, rd[0] = 0
        end
        
        7'b1110011: begin 
            case(instruction[9:7])
                3'b010, 3'b001, 3'b000: begin //CSRR, CSRW, MRET,  case necessary to prevent illegal_instruction to be thrown
                    rd_alu = 32'b0;
                end
                default: illegal_instruction = 1;
            endcase
        end
        
        default: illegal_instruction = 1;

    endcase
end

assign alu_busy = (state_q != NO_DIV);

always_comb begin
    if (start_div) rd = rd_div_q;
    else rd = rd_alu;
end

endmodule
