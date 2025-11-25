module pc_unit (
    input logic clk,
    input logic reset,

    input logic        pcflag,
    input logic        interrupt,
    input logic [ 1:0] jump,
    input logic [15:0] imm,
    input logic [15:0] isr_target,
    input logic [15:0] isr_return,

    output logic [15:0] pc_new,
    output logic pc_misaligned
);

logic [15:0] pc = 16'b0;

always_ff @( posedge clk ) begin
    if(reset) begin
        pc <= 16'b0;
    end else begin
        if(interrupt) begin
            pc <= isr_target;        
        end else if(pcflag) begin
                case(jump)
                    2'b00: begin 
                        pc <= pc + imm;
                    end
                    2'b01: begin 
                        pc <= imm;
                    end
                    2'b10: begin 
                        pc <= pc + 16'b100;
                    end
                    2'b11: begin 
                        pc <= isr_return;
                    end
                endcase
        end else begin 
            pc <= pc;
        end
    end
end

assign pc_new = pc;

always_comb begin //pc_misaligned
    pc_misaligned = pc_new[0] | pc_new[1];
end

endmodule  // pc_unit

