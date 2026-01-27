module cache_way #(
    parameter set_bits = 4,  //4: 668, 4;   5: 1198, 4;   6: 2008, 8
    parameter tag_bits = 15,
    parameter offset_bits = 3  //4 should also be possible without changing the number of SB_RAM40_4K modules
)(
    input logic clk,
    input logic reset,
    input logic [1:0] enable, // bit 1: d-cache, bit 0: i-cache target
    input logic [1:0] mode,   // 00 - read, 01 - write data, 11 - update line (set valid, tag)
    input logic iread,
    input logic [tag_bits - 1:0] tag,
    input logic [set_bits - 1:0] set,
    input logic [offset_bits - 1:0] offset,
    input logic [31:0] data_in,
    input logic valid,
    output logic [1:0] hit,
    output logic [31:0] data_out
);

logic [31:0] i_lines [2**(set_bits + offset_bits)];
logic [(2**set_bits - 1):0] i_valids;

logic [31:0] d_lines [2**(set_bits + offset_bits)];
logic [(2**set_bits - 1):0] d_valids;
//logic [tag_bits - 1:0] i_tags [2**set_bits];
//logic [tag_bits - 1:0] d_tags [2**set_bits];

logic [tag_bits - 1:0] tags [2**(set_bits + 1)];

logic [31:0] i_data;
logic [31:0] d_data;


logic i_hit;
logic d_hit;

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
                //$display("wrote to i_cache at set %d, offset %d: %h", set, offset, data_in);
                i_lines[{set, offset}] <= data_in;
                //i_tags[set] <= tag;
                //i_valids[set] <= valid;
                i_data <= data_in;
            end else begin
                i_data <= i_lines[{set, offset}];
                i_hit <= i_valids[set] && (tags[set] == tag);
            end
            
            if(update_tags) begin
                i_valids[set] <= valid;
                tags[{1'b0, set}] <= tag;
                i_hit <= valid;
            end else begin
                i_hit <= i_valids[set] && (tags[{1'b0, set}] == tag);
            end
        end

        if(enable[1]) begin
            if(write) begin
                //$display("wrote to d_cache at set %d, offset %d: %h, valid %b", set, offset, data_in, valid);
                d_lines[{set, offset}] <= data_in;
                //d_tags[set] <= tag;
                //d_valids[set] <= valid;
                d_data <= data_in;
            end else begin
                //$display("output data %h", d_lines[{set, offset}]);
                d_data <= d_lines[{set, offset}];
            end

            if(update_tags) begin
                d_valids[set] <= valid;
                tags[{1'b1, set}] <= tag;
                d_hit <= valid;
            end else begin
                d_hit <= d_valids[set] && (tags[{1'b1, set}] == tag);
            end
        end

        //if(enable[0])
        //    i_out <= 1'b1;
        //else if(enable[1])
        //    i_out <= 1'b0;


        /*if(update_tags && (enable[0] || enable[1])) begin
            tags[{enable[1], set}] <= tag;

            if(enable[0]) begin
                //tags[set] <= tag;
                i_valids[set] <= valid;
            end else begin //if(enable[1]) begin
                //tags[{1'b1, set}] <= tag;
                d_valids[set] <= valid;
            end
        end*/
    end
end

assign update_tags = mode[1];
assign write = mode[0];
assign hit = {d_hit, i_hit};

always_comb begin
    if(reset)
        data_out = 32'b0;
    else if(iread)
        data_out = i_data;
    else 
        data_out = d_data;
end

endmodule