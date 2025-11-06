module imm_gen (
    input  logic [31:0] iword,
    output logic [31:0] immediate
);

    always_comb begin
        case (iword[6:2])
            // I-Type
            5'b00100, 5'b00000, 5'b11001, 5'b11100   :
                begin
                    immediate[10:0] = iword[30:20]; 
                    immediate[31:11] = {21{iword[31]}};
                end
            // S-Type
            5'b01000   :
                begin
                    immediate[4:0] = iword[11:7];
                    immediate[10:5] = iword[30:25];
                    immediate[31:11] = {21{iword[31]}};
                end
            // B-Type
            5'b11000   :
                begin
                    immediate[0] = 1'b0;
                    immediate[4:1] = iword[11:8];
                    immediate[10:5] = iword[30:25];
                    immediate[11] = iword[7];
                    immediate[31:12] = {20{iword[31]}};
                end
            // U-Type
            5'b01101, 5'b00101  :
                begin
                    immediate[11:0] = 1'b0;
                    immediate[31:12] = iword[31:12];
                end
            // J-Type
            5'b11011   :
                begin
                    immediate[0] = 1'b0;
                    immediate[10:1] = iword[30:21];
                    immediate[11] = iword[20];
                    immediate[19:12] = iword[19:12];
                    immediate[31:20] = {12{iword[31]}};
                end
            default : immediate[31:0] = iword[31:0];
        endcase
    end

endmodule
