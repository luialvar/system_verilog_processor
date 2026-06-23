module imm_gen (
    input  logic [31:0] iword,
    output logic [31:0] immediate
);
//ask the professor the utility of this, en cuanto a la logica de por que
//ver bien por que se necesitan los flancos de reloj a veces y a veces no
//ask also about the importance of the clock and wy we can do this part without
//sigue teniendo diferentes formatos para el immediato

//if it does not uses immedaite, we will output 0
//maybe so unoptimal the use of for, ask why
//ask if my output is alright

  always @* begin
    if (iword[6:0] == 7'b0110011 || (iword[6:0] == 7'b1110011 && iword[14:12] == 3'b000)) begin
        immediate = 0;
    end
    else if (iword[6:0] == 7'b0010011 || iword[6:0] == 7'b0000011 || iword[6:0] == 7'b1100111 || iword[6:0] == 7'b1110011) begin
        immediate = {{21{iword[31]}}, iword[30:20]};
    end
    else if (iword[6:0] == 7'b0110111 || iword[6:0] == 7'b0010111) begin
        immediate = {iword[31:12], 12'b0};
    end
    else if(iword[6:0] == 7'b0100011) begin
        immediate = {{21{iword[31]}}, iword[30:25], iword[11:7]};
    end
    else if(iword[6:0] == 7'b1100011) begin
        immediate = {{21{iword[31]}}, iword[7], iword[30:25], iword[11:8], 1'b0};
    end
    else if (iword[6:0] == 7'b1101111) begin
        immediate = {{12{iword[31]}}, iword[19:12], iword[20], iword[30:21], 1'b0};
    end
    else
        immediate = 0;
    end
endmodule
