module spram_tb ();

  logic clk;
  logic reset;

  int period;

  logic [31:0] data_out;

  spram #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(14)
  ) dut (
    .clk(clk),
    .reset(reset),
    .addr(0),
    .write_enable(0),
    .read_enable(0),
    .write_data(0),
    .read_data(data_out)
  );

  always begin
    clk = 0;
    forever #1 clk = ~clk;
  end

  initial begin
    $dumpfile("spram_tb.vcd");
    $dumpvars(0, dut);

    reset = 1'b1;
    #period;
    reset = 1'b0;
    #period;

    $display("\033[32mTestbench finished running\033[0m");
    $finish;
  end




endmodule // spram_tb