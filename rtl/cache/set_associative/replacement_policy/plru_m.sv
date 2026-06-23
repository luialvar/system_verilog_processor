/*
* Implementation of a pseudo least-recently-used cache-replacement policy PLRUm
*
* MRU based replacement, each time, a cache-hit occurs, the corresponding MRU bit is set to 1.
* Reset all other bits to 0, if all bits would have turned to 1.
*
* set hit to true, if a cache hit occurred and the MRU bits of that set have to be updated
* output way_replace holds the index of the way that should be replaced next on a cache miss
*/
module plru_m #(
    parameter ways = 8,
    parameter way_bits = 3,
    parameter sets = 16,
    parameter set_bits = 4
)(
    input logic clk,
    input logic reset,
    input logic hit,                       // indicate that a way was hit
    input logic replace,                   // on hit, indicate if a way way was replaced
    input logic [set_bits - 1:0] set,      // the set of which one way is replaced or hit
    input logic [way_bits - 1:0] way_hit,  // "index" of the way that was hit
    output logic [way_bits - 1:0] way_replace, // the way that should be replaced
    output logic finished
);

assign finished = 1;

logic [ways:0] array [sets]; //holds MRU bits for each set. The bit at position "way" marks this entry as valid.
logic [ways - 1:0] current;
logic [ways - 1:0] carry;

always_ff @( posedge clk) begin
    if(reset) begin
        current <= 0;
        //invalidate all entries on reset
        for(int i = 0; i < ways; i++) begin
            array[ways] <= 1'b0;
        end
    end else begin

        //deliberately using blocking assignments
        if(array[set][ways]) begin  //if entry is valid
            current = array[set][ways - 1:0];   //assign MRU bits of set "set" to current
        end else begin              //else reset MRU bits of sest "set" to 0, set entry valid;
            array[set][ways] = 1'b1;
            array[set[ways - 1:0]] = 0;
            current = 0;
        end

        if(hit) begin               //update MRU bits if hit occured
            //$display("--------------------");
            //$display("we hit set %d, way %d, current before: %b", set, way_hit, current);
            current[way_hit] = 1'b1;
            if(current == {(ways){1'b1}}) begin  //set all bits except the one that was hit to 0, if all bits would have turned to 1
                current = 0;
                current[way_hit] = 1'b1;
            end
            //$display("current after: %b, next way to replace: %d", current, way_replace);
            //$display("--------------------");
            array[set] = {1'b1, current};    //update in array
        end
    end
end

//priority encoder?
//determine index of the first 0-bit in current MRU bits. This index is the next way that should be replaced
always_comb begin
    way_replace = 0;
    carry = 1;
    if(current[0]) begin
        for(int j = 1; j < ways; j++) begin
            carry[j] = current[j] && carry[j-1];

            if(carry[j - 1] && !current[j])
                way_replace = j;
        end
    end
end


endmodule

//assign carry[0] = 1'b1; //set first bit to 1, as first carry-in must always be true
/*genvar i;
generate
    for(i = 1; i < way; i++) begin
        one_mod #(.way_bits(way_bits)) om (
            .in(current[i]),
            .c_in(carry[i-1]),
            .out(one[i]),
            .c_out(carry[i])
        );
    end
endgenerate*/