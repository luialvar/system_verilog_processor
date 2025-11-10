module traffic_light (
    input logic clk,
    input logic reset,

    output logic red,
    output logic yellow,
    output logic green
);

    enum {R,RY,G,Y} state_d, state_q;

    logic [31:0] clk_count = 0;
    
    always_ff @(posedge clk) begin
        clk_count <= clk_count + 1;
        if ((state_q == R | state_q == G) & clk_count == 72000000 | state_q == Y & clk_count == 36000000 | state_q == RY & clk_count == 24000000) begin 
            clk_count <= 0;
            state_q <= state_d;
        end
        else if (reset == 0)
            state_q <= R;
        else
            state_q <= state_q;
    end

    always_comb begin
        if (state_q == R) begin
            red = 1;
            yellow = 0;
            green = 0;
        end
        else if (state_q == RY) begin
            red = 1;
            yellow = 1;
            green = 0;
        end
        else if (state_q == Y) begin
            red = 0;
            yellow = 1;
            green = 0;
        end
        else begin
            red = 0;
            yellow = 0;
            green = 1;
        end
    end

    always_comb begin
        case (state_q)
            R   :   state_d = RY;
            RY  :   state_d = G;
            G   :   state_d = Y;
            Y   :   state_d = R;
        default:
            state_d = R;
        endcase
    end

endmodule
