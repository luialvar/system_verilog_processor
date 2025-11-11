module alu (
    input logic [31:0] a,               // rs1/pc
    input logic [31:0] b,               // rs2/imm
    input logic [16:0] instruction,

    output logic [31:0] rd,
    output logic illegal_instruction
);
    always_comb begin
        illegal_instruction = 0;
        rd = 0;
        case (instruction[6:0])
            7'b0110011 :
                begin
                    case (instruction[9:7])
                        //add, sub, mul
                        3'b000 :
                            begin
                                if(instruction[16:10] == 7'b0100000) begin
                                    rd = a - b;
                                end
                                else if(instruction[16:10] == 7'b0000001) begin
                                    rd = a * b;
                                end
                                else begin
                                    rd = a + b;
                                end
                            end
                        //and
                        3'b111 :   rd = a & b;
                        //or
                        3'b110 :   rd = a | b;
                        //xor
                        3'b100 :   rd = a ^ b;
                        //slt
                        3'b010 :   rd = (signed'(a) < signed'(b));
                        //sltu
                        3'b011 :   rd = (a < b);
                        //sra, srl
                        3'b101 :
                            begin
                                if(instruction[16:10] == 7'b0100000) begin
                                    rd = signed'(a) >>> b;
                                end
                                else begin
                                    rd = a >> b;
                                end
                            end
                        //sll
                        3'b001 :   rd = a << b[4:0];
                    endcase
                end
            7'b0010011 :
                begin
                    case (instruction[9:7])
                        //slli
                        3'b001 :   rd = a << b[4:0];
                        //addi
                        3'b000 :   rd = a + b;
                        //andi
                        3'b111 :   rd = a & b;
                        //ori
                        3'b110 :   rd = a | b;
                        //xori
                        3'b100 :   rd = a ^ b;
                        //slti
                        3'b010 :   rd = (signed'(a) < signed'(b));
                        //sltiu
                        3'b011 :   rd = (a < b);
                        //srai, srli
                        3'b101 :
                            begin
                                if(instruction[16:10] == 7'b0100000) begin
                                    rd = signed'(a) >>> b;
                                end
                                else begin
                                    rd = a >> b;
                                end
                            end
                    endcase
                end
            //lui
            7'b0110111 :   rd = b;
            //auipc
            7'b0010111 :   rd = a + b;
            //jal
            7'b1101111 :   rd[17:16] = 2'b00;
            //jalr
            7'b1100111 :
                begin
                    rd[17:16] = 2'b01;
                    rd[15:0] = a + b;
                    rd[0] = 1'b0;
                end
            //lw, sw
            7'b0000011, 7'b0100011  :   rd = a + b;
            7'b1100011 :
                begin
                    case (instruction[9:7])
                        //beq
                        3'b000  :   
                            begin
                                if (a == b) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end
                        //bne
                        3'b001  :
                            begin
                                if (a != b) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end
                        //blt
                        3'b100  :
                            begin
                                if (signed'(a) < signed'(b)) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end
                        //bge
                        3'b101  :
                            begin
                                if (signed'(a) >= signed'(b)) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end  
                        //bltu
                        3'b110  :
                            begin
                                if (a < b) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end
                        //bgeu
                        3'b111  :
                            begin
                                if (a >= b) begin
                                    rd[17:16] = 2'b00;
                                end
                                else begin
                                    rd[17:16] = 2'b10;
                                end
                            end  
                    endcase
                end
            7'b1110011  :   rd = 0;
            default :
                begin
                    illegal_instruction = 1;
                    rd = 0;
                end
        endcase
    end

endmodule
