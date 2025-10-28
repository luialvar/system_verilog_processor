module div_clock #(
    parameter WIDTH = 0
)(
    input logic clk, reset,
    input logic [WIDTH-1:0] max,
    output logic div_clk
);

logic [WIDTH - 1:0] counter;

logic rst;

always_ff @( posedge clk or negedge reset ) begin
    if(!reset) begin 
        counter <= 0;
        div_clk <= 0;
        rst <= 1;
    end else begin
        if(counter == (max - 1)) begin
            counter <= 0;
            div_clk <= ~div_clk;

        end else begin
            if(rst) begin
                rst <= 0;
                div_clk <= 1;
                counter <= counter;

            end else begin 
                rst <= rst;
                div_clk <= div_clk;
                counter <= counter + 1;
            end
           
        end
    end
end

endmodule