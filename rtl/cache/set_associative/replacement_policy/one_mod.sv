module one_mod #(
    parameter assoc_bits
)(
    input logic in,
    input logic c_in,
    output logic out,
    output logic c_out
);

assign c_out = in && c_in;
assign out = !in && c_in;

endmodule