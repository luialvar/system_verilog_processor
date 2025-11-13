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

logic [31:0] regs [31:0];
logic [31:0] rout1;
logic [31:0] rout2;

always_ff @( posedge clk ) begin 
    if(reset) begin
        rout2 <= 32'b0;
        rout2 <= 32'b0;
    end else begin
        if(regwrite) begin
            regs[rdadr] <= rd;
        end else begin
            rout1 <= regs[rs1adr];
            rout2 <= regs[rs2adr];      
        end
    end
end

assign rs1 = rs1adr ? rout1 : 32'b0; 
assign rs2 = rs2adr ? rout2 : 32'b0; 


endmodule  // regs
