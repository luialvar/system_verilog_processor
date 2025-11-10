`timescale 1ns/1ns

module ifelse_tb();
    logic a, b, c, d, y;

    ifelse dut(
        .a(a),
        .b(b),
        .c(c),
        .d(d),
        .y(y)
    );

    initial begin
        $dumpfile("ifelse.vcd");
        $dumpvars(0, dut);

        a = 0;
        b = 0;
        c = 0;
        d = 0;
        #10;
        assert(y==a) else $error("y not equal a");

        a = 1;
        b = 0;
        c = 1;
        d = 1;
        #10;
        assert(y==b) else $error("y not equal b");
        $finish;
    end
endmodule
