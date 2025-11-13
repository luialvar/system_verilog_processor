module ifelse (
    input logic  a, b, c, d,
    output logic y
);

    // This version is not correct, the testbench
    // will report a problem. y = b should happen
    // if both c and d are 1. Fix this mistake
    // and run the test again
    always_comb begin
        if (c == 1'b0 && d == 1'b1)
            y = b;
        else
            y = a;
    end

endmodule
