module fifo #(
    parameter ways = 8,
    parameter way_bits = 3,
    parameter sets = 16,
    parameter set_bits = 4
)(
    input logic clk,
    input logic reset,
    input logic hit,                            // update the way that is hit
    input logic replace,                        // on hit, indicate if a way way was replaced
    input logic [set_bits - 1:0] set,           // the set of which one way is replaced or hit
    input logic [way_bits - 1:0] way_hit,       // "index" of the way that was hit
    output logic [way_bits - 1:0] way_replace,  // the way that should be replaced
    output logic finished
);

logic [way_bits - 1:0] counter [sets];

assign way_replace = counter[set];
assign finished = 1'b1;

always_ff @( posedge clk) begin
    if(reset) begin
        for(int i = 0; i < sets; i++) begin
            counter[i] <= 0;
        end
    end else begin
        if(replace && hit) begin
            counter[set] <= counter[set] + 1;
        end
    end
end

endmodule