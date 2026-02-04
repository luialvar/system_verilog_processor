module cache_module #(
    parameter tag_bits = 12,
    parameter index_bits = 7,
    parameter offset_bits = 3,
    parameter cell_select = 1  //1 - spram, 0 - sbram
)(
    input logic clk,
    input logic reset,

    input logic [tag_bits - 1:0] tag,
    input logic [index_bits - 1:0] index,
    input logic [offset_bits - 1:0] offset,
    input logic valid,
    
    input logic read_enable,
    input logic write_enable,

    input  logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic hit
);

// tags and valid bits
logic [tag_bits - 1:0]      tags[2**(index_bits)];
logic [2**index_bits - 1:0] valids;

//current tag and valid
logic [tag_bits - 1:0] current_tag;
logic current_valid;

assign hit = current_valid && (current_tag == tag);

always_ff @( posedge clk ) begin
    if(reset) begin
        valids <= 0;
        current_valid <= 0;
    end else begin
        if(read_enable) begin
            current_valid <= valids[index];
            current_tag <= tags[index];

        end else if(write_enable) begin
            valids[index] <= valid;
            tags[index] <= tag;

        end
    end
end

// actual cached data
generate
    if(cell_select) begin
        spram #(
            .DATA_WIDTH(32),
            .ADDR_WIDTH(index_bits + offset_bits)
        ) ram (
            .clk(clk),
            .reset(reset),
            .addr({index, offset}),
            .write_enable(write_enable),
            .read_enable(read_enable),
            .write_data(data_in),
            .read_data(data_out)
        );
    end else begin
        sbram #(
            .DATA_WIDTH(32),
            .ADDR_WIDTH(index_bits + offset_bits)
        ) ram (
            .clk(clk),
            .reset(reset),
            .addr({index, offset}),
            .write_enable(write_enable),
            .read_enable(read_enable),
            .write_data(data_in),
            .read_data(data_out)
        );
    end
endgenerate

endmodule // cache_module
