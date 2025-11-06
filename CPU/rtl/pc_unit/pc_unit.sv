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

    logic [15:0] pc_reg = 0;
    logic [15:0] pc_new_reg = 0;

    always_ff @(posedge clk) begin
        if (pc_reg[1:0] != 2'b00) begin
            pc_misaligned <= 1;
            pc_reg <= pc_new_reg;
        end
        else if (interrupt) begin
            pc_reg <= isr_target;
        end
        else if (interrupt == 0 & pcflag) begin 
            case (jump)
                2'b00   :   pc_reg <= pc_reg + imm;
                2'b01   :   pc_reg <= imm;
                2'b10   :   pc_reg <= pc_reg + 4;
                2'b11   :   pc_reg <= isr_return;
                default :   pc_reg <= pc_reg;
            endcase
        end
        else begin
            pc_reg <= pc_reg;
        end
        if (reset) begin
            pc_reg <= 0;
        end
    end

    assign pc_new = pc_reg;

endmodule  // pc_unit
