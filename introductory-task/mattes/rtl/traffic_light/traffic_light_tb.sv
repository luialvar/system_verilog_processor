module traffic_light_tb();
    logic clk, reset;
    logic r, y, g;

    traffic_light dut (
        .clk(clk),
        .reset(reset),
        .red(r),
        .yellow(y),
        .green(g)
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
        $display("y: %b", y);
        $strobe("y: %b", y);
        #2;
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b001) else
          $error("Wrong output. Expected r = 0, y = 0, g = 1 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b010) else
          $error("Wrong output. Expected r = 0, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b100) else
          $error("Wrong output. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        reset = 0;
        #2;
        assert({r, y, g} == 3'b100) else
          $error("Wrong output after reset. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);

        reset = 1;
        #2;
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b001) else
          $error("Wrong output. Expected r = 0, y = 0, g = 1 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b010) else
          $error("Wrong output. Expected r = 0, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b100) else
          $error("Wrong output. Expected r = 1, y = 0, g = 0 but got r = %b, y = %b, g = %b", r, y, g);
        #2;
        assert({r, y, g} == 3'b110) else
          $error("Wrong output. Expected r = 1, y = 1, g = 0 but got r = %b, y = %b, g = %b", r, y, g);

        #12;

        $finish;
    end

endmodule
