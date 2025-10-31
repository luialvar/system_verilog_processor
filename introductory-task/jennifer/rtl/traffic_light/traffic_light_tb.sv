module traffic_light_tb();
    logic clk, reset;
    logic r, y, g;
    logic tone_out;
    localparam integer cycles = 24;

    traffic_light dut (
        .clk(clk),
        .reset(reset),
        .red(r),
        .yellow(y),
        .green(g),
        .tone(tone_out)
    );

    always begin
        clk = 1;
        reset = 0;
        forever #1 clk = ~clk;
    end

    initial begin
        $dumpfile("traffic_light.vcd");
        $dumpvars(0, dut);

        #6;
        reset = 1;
        #(6*cycles);
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(2*cycles);
        assert({r, y, g} == 3'b001) else
          $error("Wrong output. Expected r = 0, y = 0, g = 1 but got r = %b, y = %b, g = %b", r, y, g);
        #(6*cycles);
        assert({r, y, g} == 3'b010) else
          $error("Wrong output. Expected r = 0, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(3*cycles);
        assert({r, y, g} == 3'b100) else
          $error("Wrong output. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(6*cycles);
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);

        reset = 0;
        #(12*cycles);
        assert({r, y, g} == 3'b100) else
          $error("Wrong output after reset. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);

        reset = 1;
        #(6*cycles);
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(2*cycles);
        assert({r, y, g} == 3'b001) else
          $error("Wrong output. Expected r = 0, y = 0, g = 1 but got r = %b, y = %b, g = %b", r, y, g);
        #(6*cycles);
        assert({r, y, g} == 3'b010) else
          $error("Wrong output. Expected r = 0, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(3*cycles);
        assert({r, y, g} == 3'b100) else
          $error("Wrong output. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #(6*cycles);
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);

        #(12*cycles);

        $finish;
    end

endmodule
