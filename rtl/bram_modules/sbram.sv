/*
* from https://yosyshq.readthedocs.io/projects/yosys/en/latest/using_yosys/synthesis/memory.html
*/

module sbram #(
        parameter DATA_WIDTH = 32,
        parameter ADDR_WIDTH = 14
)(
    input logic clk,
    input logic reset,
    input logic [ADDR_WIDTH - 1:0] addr,
    input logic write_enable,
    input logic read_enable,
    input logic [DATA_WIDTH - 1:0] write_data,
    output logic [DATA_WIDTH - 1:0] read_data
);


// Manual selection of ram_style attribute. I don't think that is valid sv code, if other synthesis tools are used?
(* ram_style = "block" *) reg [DATA_WIDTH - 1 : 0] mem [2**ADDR_WIDTH - 1 : 0];

always @(posedge clk) begin
    if (write_enable)
        mem[addr] <= write_data;
    else if (read_enable)
        read_data <= mem[addr];
end

endmodule // spram