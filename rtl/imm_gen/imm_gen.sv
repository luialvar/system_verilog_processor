module imm_gen (
    input  logic [31:0] iword,
    output logic [31:0] immediate
);

logic [4:0] comp;
assign comp = iword[6:2];

always_comb begin 
    case (comp)
        5'b01000: begin //s
            immediate = {iword[31]? {21{1'b1}} : 21'b0, iword[30:25], iword[11:7]}; //or use 21'b111111111111111111111
        end 
        5'b01101, 5'b00101: begin //u
            immediate = {iword[31:12], 12'b0};
        end 
        5'b11000: begin //B
            immediate = {iword[31]? {20{1'b1}}  : 20'b0, iword[7], iword[30:25], iword[11:8], 1'b0};
        end 
        5'b11011: begin //J
            immediate = {iword[31]? {12{1'b1}} : 12'b0, iword[19:12], iword[20], iword[30:21], 1'b0};
        end 
        default: begin//I + remaining
            immediate = {iword[31]? {21{1'b1}}  : 21'b0, iword[30:20]};
        end
    endcase
end

endmodule
