module cache_way #(
    parameter set_bits = 4,
    parameter tag_bits = 15,
    parameter offset_bits = 3
)(
    input logic clk,
    input logic reset,
    input logic [1:0] enable, // bit 1: d-cache, bit 0: i-cache target
    input logic [1:0] mode,   // 00 - read, 01 - write data, 11 - update line (set valid, tag)
    input logic [tag_bits - 1:0] tag,
    input logic [set_bits - 1:0] set,
    input logic [offset_bits - 1:0] offset,
    input logic [31:0] data_in,
    input logic valid,
    output logic [1:0] hit,
    output logic [31:0] data_out
);

logic [15:0] u_lines [2**(set_bits + offset_bits + 1)];
logic [15:0] l_lines [2**(set_bits + offset_bits + 1)];

logic [(2**set_bits - 1):0] i_valids;
logic [(2**set_bits - 1):0] d_valids;

logic [tag_bits - 1:0] tags [2**(set_bits + 1)];

logic [31:0] i_data;
logic [31:0] d_data;

logic i_hit;
logic d_hit;

logic i_out;

logic write;
logic update_tags;

always_ff @( posedge clk) begin
    if(reset) begin
        i_valids <= 0;
        d_valids <= 0;
        i_hit <= 1'b0;
        d_hit <= 1'b0;

    end else begin
        if(enable[0]) begin
            if(write) begin
                u_lines[{1'b0, set, offset}] <= data_in[31:16];
                l_lines[{1'b0, set, offset}] <= data_in[15:0];
                i_data <= data_in;
            end else begin
                i_data[31:16] <= u_lines[{1'b0, set, offset}];
                i_data[15:0] <= l_lines[{1'b0, set, offset}];
            end
            i_hit <= i_valids[set] && (tags[set] == tag);
            i_out = 1'b1;
        end

        if(enable[1]) begin
            if(write) begin
                u_lines[{1'b1, set, offset}] <= data_in[31:16];
                l_lines[{1'b1, set, offset}] <= data_in[15:0];
                d_data <= data_in;
            end else begin
                d_data[31:16] <= u_lines[{1'b1, set, offset}];
                d_data[15:0] <= l_lines[{1'b1, set, offset}];
            end
            d_hit <= d_valids[set] && (tags[{1'b1, set}] == tag);
            i_out = 1'b0;
        end


        if(update_tags && (enable[0] || enable[1])) begin
            tags[{enable[1], set}] <= tag;

            if(enable[0]) begin
                i_valids[set] <= valid;
            end else begin 
                d_valids[set] <= valid;
            end
        end
    end
end

assign update_tags = mode[1];
assign write = mode[0];
assign hit = {d_hit, i_hit};

always_comb begin
    if(reset)
        data_out = 32'b0;
    else if(i_out)
        data_out = i_data;
    else 
        data_out = d_data;
end

endmodule