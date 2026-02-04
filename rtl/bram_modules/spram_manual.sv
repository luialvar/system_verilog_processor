module spram_manual (
    input logic clk,
    input logic reset,
    input logic [9:0] addr,
    input logic write_enable,
    input logic read_enable,
    input logic [31:0] write_data,
    output logic [31:0] read_data
);

logic enable;
assign enable = write_enable || read_enable;


SB_SPRAM256KA ramfn_inst1(
.DATAIN(write_data[15:0]),
.ADDRESS({4'b0, addr}),  //2**14 addresses
.MASKWREN(4'b1111),
.WREN(write_enable),
.CHIPSELECT(enable),
.CLOCK(clk),
.STANDBY(1'b0),
.SLEEP(1'b0),
.POWEROFF(1'b0),
.DATAOUT(read_data[15:0])
);

SB_SPRAM256KA ramfn_inst2(
.DATAIN(write_data[31:16]),
.ADDRESS({4'b0, addr}),
.MASKWREN(4'b1111),
.WREN(write_enable),
.CHIPSELECT(enable),
.CLOCK(clk),
.STANDBY(1'b0),
.SLEEP(1'b0),
.POWEROFF(1'b0),
.DATAOUT(read_data[31:16])
);

endmodule // spram_manual