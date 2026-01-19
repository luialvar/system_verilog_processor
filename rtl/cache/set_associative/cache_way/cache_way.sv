module cache_way #(
    parameter set_bits = 4,
    parameter tag_bits = 15,
    parameter offset_bits = 3
)(
    input logic clk,
    input logic reset,
    input logic [1:0] enable, // bit 1: d-cache, bit 0: i-cache target
    input logic write,
    input logic [tag_bits - 1:0] tag,
    input logic [set_bits - 1:0] set,
    input logic [offset_bits - 1:0] offset,
    input logic [31:0] data_in,
    input logic valid,
    output logic [1:0] hit,
    output logic [31:0] data_out
);

/*logic [31:0] lines [(2**(set_bits + offset_bits))];
logic [tag_bits - 1:0] tags [2**set_bits];
logic [2**set_bits] valids;*/
logic [31:0] i_lines [2**(set_bits + offset_bits)];
logic [tag_bits - 1:0] i_tags [2**set_bits];
logic [(2**set_bits - 1):0] i_valids;

logic [31:0] d_lines [2**(set_bits + offset_bits)];
logic [tag_bits - 1:0] d_tags [2**set_bits];
logic [(2**set_bits - 1):0] d_valids;

logic [31:0] i_data;
logic [31:0] d_data;

logic i_hit;
logic d_hit;

logic i_out;

always_ff @( posedge clk) begin
    if(reset) begin
        i_valids <= 0;
        d_valids <= 0;
        i_hit <= 1'b0;
        d_hit <= 1'b0;

    end else begin
        if(enable[0]) begin
            if(write) begin
                //$display("wrote to i_cache at set %d, offset %d: %h", set, offset, data_in);
                i_lines[{set, offset}] <= data_in;
                i_tags[set] <= tag;
                i_valids[set] <= valid;
                i_data <= data_in;
            end else begin
                i_data <= i_lines[{set, offset}];
            end
            i_hit <= i_valids[set] && (i_tags[set] == tag);
            i_out = 1'b1;
        end

        if(enable[1]) begin
            if(write) begin
                //$display("wrote to d_cache at set %d, offset %d: %h, valid %b", set, offset, data_in, valid);
                d_lines[{set, offset}] <= data_in;
                d_tags[set] <= tag;
                d_valids[set] <= valid;
                d_data <= data_in;
            end else begin
                //$display("output data %h", d_lines[{set, offset}]);
                d_data <= d_lines[{set, offset}];
            end
            d_hit <= d_valids[set] && (d_tags[set] == tag);
            i_out = 1'b0;
        end
    end
end

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