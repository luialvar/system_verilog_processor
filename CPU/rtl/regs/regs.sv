module regs (
    input logic clk,
    input logic reset,

    input logic regwrite,

    input logic [4:0] rs1adr,
    input logic [4:0] rs2adr,
    input logic [4:0] rdadr,

    input  logic [31:0] rd,
    output logic [31:0] rs1,
    output logic [31:0] rs2
);

    reg [31:0] R[31:0];

    always_ff @(posedge clk) begin
        if (reset) begin
            rs1 <= 32'h00000000;
            rs2 <= 32'h00000000;
        end
        else if (regwrite) begin
            R[rdadr] <= rd;
        end
        else begin
            case (rs1adr)
                5'b00000    :   rs1 <= 32'h00000000;
                default     :   rs1 <= R[rs1adr];
            endcase
            case (rs2adr)
                5'b00000    :   rs2 <= 32'h00000000;
                default     :   rs2 <= R[rs2adr];
            endcase
        end
    end

endmodule  // regs
