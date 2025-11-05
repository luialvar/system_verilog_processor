`include "./div_clock.sv"

module traffic_light (
    input logic clk,
    input logic reset,

    output logic red,
    output logic yellow,
    output logic green//,
    //output logic tone
);

    logic [25:0] max_le_cycles;
    //logic [11:0] max_sp_cycles;
    logic div_clk;
    logic rst;

    div_clock #(.WIDTH(26)) div_clk_m (
        .clk(clk), .reset(reset), .max(max_le_cycles), .div_clk(div_clk)
    );
    
    /*div_clock #(.WIDTH(11)) speaker_clk (
        .clk(clk), .reset(reset), .max(max_sp_cycles), .div_clk(tone)
    );*/

    enum bit[2:0] {state_red=1, state_red_yellow=3, state_green=4, state_yellow=2} state_d, state_q;

    always_ff @( posedge div_clk or negedge reset) begin  
        if(reset == 1'b0) begin
            state_q <= state_red;
            rst <= 1'b1;
        end else begin
            state_q <= state_d;
            rst <= 1'b0;
        end
    end

    always_comb begin 
        case(state_q) 
            state_red: begin
                if(rst) begin
                    state_d = state_red;
                end else begin
                    state_d = state_red_yellow;
                end
                max_le_cycles = 36000000; //append 000000, so 36000000 instead of 36
                //max_sp_cycles = 2; //13636, 440 Hz (12 MHz clock speed)
            end
            state_red_yellow: begin
                state_d = state_green;
                max_le_cycles = 12000000; //12
                //max_sp_cycles = 3; //12170, 493 Hz
            end
            state_green: begin
                state_d = state_yellow;
                max_le_cycles = 36000000;
                //max_sp_cycles = 4; //11472, 523 Hz
            end
            state_yellow: begin
                state_d = state_red;
                max_le_cycles = 18000000;
                //max_sp_cycles = 5; //10221, 587 Hz
            end
            default: begin
                state_d = state_red;
                max_le_cycles = 36000000;
                //max_sp_cycles = 2; //3636, 440 Hz
            end
        endcase
    end

    always_comb begin 
        {green, yellow, red} = state_q;
    end
endmodule
