//things to learn, you cannot asign smth to the same variable in two different places,
//what you can do is access to it to read it, also the importance of
//the clocks and all that in updating the counter when you are suppose to do it
//and do the check also after updating


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

always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_new        <= 16'h0000;
            pc_misaligned <= 1'b0;
        end else begin
            logic [15:0] pc_next;
            pc_next = pc_new;
            if (interrupt) begin
                pc_next = isr_target;
            end else if (pcflag) begin
                case (jump)
                    2'b00: pc_next = pc_new + imm;       // salto relativo
                    2'b01: pc_next = imm;               // salto absoluto
                    2'b10: pc_next = pc_new + 16'd4;    // PC + 4
                    2'b11: pc_next = isr_return;        // retorno ISR
                endcase
            end
            pc_new <= pc_next;
            if (pc_next % 4 == 0)
                pc_misaligned <= 1'b0;
            else
                pc_misaligned <= 1'b1;
        end
    end

endmodule

/*
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        pc_new        <= 16'h0000;
        pc_misaligned <= 1'b0;
    end
    else if (pc_new % 4 != 0) begin
        pc_misaligned <= 1'b1;
    end
    else if (interrupt) begin
    pc_new <= isr_target;
    end
    else if(!interrupt && pcflag) begin
        if (jump == 2'b00) begin
        pc_new <= pc_new + imm;
        end
    else if (jump == 2'b01) begin
        pc_new <= imm;
        end
    else if (jump == 2'b10) begin
        pc_new <= pc_new + 4;
        end
    else if (jump == 2'b11) begin
        pc_new <= isr_return;
        end
    end
end

endmodule
*/