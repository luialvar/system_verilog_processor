`timescale 1ps / 1ps

module id_c_large_misaligned_tb();

  logic clk = 0;
  logic reset = 0;
  logic si;
  logic so;
  logic sclk;
  logic sram_ce;
  logic[23:0] addr;
  logic[31:0] datain, dataout, expected_dataout, be_expected_dataout;
  logic write;
  logic busy;
  logic valid;
  logic iread;
  logic idle;

  logic finished = 0;
  real half_period = 5;
  real period = 2 * half_period;
  string line;
  int    FILE,code;

  logic [91:0] c_test_vector;

  logic [91:0] test_vectors [$];

  logic expected_busy;
  logic expected_valid;

  assign addr = c_test_vector[91:68];
  assign datain = c_test_vector[67:36];
  assign expected_dataout = c_test_vector[35:4];
  assign write = c_test_vector[3];
  assign expected_busy = c_test_vector[2];
  assign expected_valid = c_test_vector[1];
  assign iread = c_test_vector[0];

  //reordering because little endian
  //assign expected_dataout = {be_expected_dataout[7:0], be_expected_dataout[15:8], be_expected_dataout[23:16], be_expected_dataout[31:24]};

  id_c_large_misaligned dut (
      .clk(clk),            //i
      .reset(reset),        //i
      .so(so),              //i
      .si(si),              //o
      .sclk(sclk),          //o
      .ce(sram_ce),         //o
      .addr(addr),          //i <- [23:0]
      .data_in(datain),     //i <- [31:0]
      .data_out(dataout),   //o <- [31:0]
      .write(write),        //i <- 1
      .busy(busy),          //o <- 1
      .valid(valid),        //o <- 1
      .iread(iread),        //i
      .idle(idle)
  );

  sram_sim #(
      .INIT_FILE("./../../tb_words.txt")
  ) sram (
      .sclk(sclk),
      .reset(reset),
      .ce(sram_ce),
      .si(si),            //i
      .so(so)             //o
  );

  localparam int cache_size = 1024;
  localparam int iterations = 150; //should be 128 to write value to each 8-word block
  /*logic [31:0] i_cache_content [cache_size];
  logic [31:0] d_cache_content [cache_size];
  //logic [7:0] mem_content [cache_size];
    generate
        genvar i;
        for(i = 0; i < cache_size; i = i+1) begin
              assign i_cache_content[i] = dut.i_cache[i];
              assign d_cache_content[i] = dut.d_cache[i];
              //assign mem_content[i] = sram.mem[i];
        end
    endgenerate*/

  int j, time_limit, iter_addr;


  assign time_limit = 4000;

  always #half_period clk = ~clk;
  initial
    begin
      $dumpfile("id_c_large_misaligned.vcd");
      $dumpvars(0, dut);

      //for (int i = 0; i < cache_size; i++) begin
      //  $dumpvars(1, i_cache_content[i]);
      //  $dumpvars(1, d_cache_content[i]);
      //end
      //#half_period;
      reset = 1;
      idle = 1'b1;
      #period;
      reset = 0;
      idle = 1'b0;

      //TEST_CASES            addr        datain        ex_dataout    write busy  valid iread
      test_vectors.push_back({24'h000000, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 0: read from addr 0
      test_vectors.push_back({24'h000004, 32'h00000000, 32'h00000001, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 1: read from addr 4, should be cached
      test_vectors.push_back({24'h000014, 32'h00000000, 32'h00000005, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 2: read from addr 20, should be cached
      test_vectors.push_back({24'h000020, 32'h00000000, 32'h00000008, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 3: read from addr 32

      test_vectors.push_back({24'h000021, 32'h00000000, 32'h09000000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 4: read from missaligned addr
      test_vectors.push_back({24'h000192, 32'h00000000, 32'h00650000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 5: read from missaligned addr, spanning
      test_vectors.push_back({24'h000663, 32'h00000000, 32'h00019900, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 6: read from missaligned addr

      test_vectors.push_back({24'h000030, 32'haabbccdd, 32'h00000000, 1'b1, 1'b0, 1'b1, 1'b0}); //Test 7: write to not cached addr
      test_vectors.push_back({24'h000030, 32'h00000000, 32'haabbccdd, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 8: read newly written value
      test_vectors.push_back({24'h000034, 32'h11223344, 32'h00000000, 1'b1, 1'b0, 1'b1, 1'b0}); //Test 9: write to cached addr
      test_vectors.push_back({24'h000034, 32'h00000000, 32'h11223344, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 10: write to cached addr

      test_vectors.push_back({24'h000004, 32'h00000000, 32'h00000001, 1'b0, 1'b0, 1'b1, 1'b1}); //Test 11: load i-word
      test_vectors.push_back({24'h000008, 32'h00000000, 32'h00000002, 1'b0, 1'b0, 1'b1, 1'b1}); //Test 12: load cached i-word

      test_vectors.push_back({24'h000004, 32'hfffffff1, 32'h00000000, 1'b1, 1'b0, 1'b1, 1'b0}); //Test 13: write cached values in both i- and d-cache
      test_vectors.push_back({24'h000008, 32'hffffff11, 32'h00000000, 1'b1, 1'b0, 1'b1, 1'b1}); //Test 14: write cached values in both i- and d-cache
      test_vectors.push_back({24'h000004, 32'h00000000, 32'hfffffff1, 1'b0, 1'b0, 1'b1, 1'b1}); //Test 15: read from i-cache
      test_vectors.push_back({24'h000004, 32'h00000000, 32'hfffffff1, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 16: read from d-cache
      test_vectors.push_back({24'h000008, 32'h00000000, 32'hffffff11, 1'b0, 1'b0, 1'b1, 1'b1}); //Test 17: read from i-cache
      test_vectors.push_back({24'h000008, 32'h00000000, 32'hffffff11, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 18: read from d-cache

      test_vectors.push_back({24'h100008, 32'heeeeeeee, 32'h00000000, 1'b1, 1'b0, 1'b1, 1'b0}); //Test 19: write to same index, other tag
      test_vectors.push_back({24'h100008, 32'h00000000, 32'heeeeeeee, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 20: read from same index, other tag

      test_vectors.push_back({24'h0007f, 32'h00002000, 32'h00002000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 21: misaligned addresss 127(10) read spanning over two cache-lines, uncached
      test_vectors.push_back({24'h0009e, 32'h00000000, 32'h00280000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 22: misaligned addresss 158(10) read spanning over two cache-lines, lower cached
      test_vectors.push_back({24'h0005d, 32'h00000000, 32'h18000000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 23: misaligned addresss 93(10) read spanning over two cache-lines, upper cached
      test_vectors.push_back({24'h0007e, 32'h00000000, 32'h00200000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 24: misaligned addresss 126(10) read spanning over two cache-lines, both cached
      test_vectors.push_back({24'h00023, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b0, 1'b1}); //Test 25: misaligned address for i-word fetch

      // address is i * 32
      for(int i = 0; i < iterations; i++) begin
        iter_addr = i * 32;
        test_vectors.push_back({iter_addr[23:0], i,            32'h00000000, 1'b1, 1'b0, 1'b1, 1'b0});
        test_vectors.push_back({iter_addr[23:0], 32'h00000000, i,            1'b0, 1'b0, 1'b1, 1'b0});
      end

      // Testing all cases here
      foreach (test_vectors[i])
        begin
          $display("Running test %0d", i);

          c_test_vector = test_vectors[i];
          idle = 1'b0;

          j = 0;
          while(dut.busy && j <= time_limit) begin
            #period;
            if( j++ == time_limit) begin
              $error("\033[31mTest %0d failed: Cache-operation exceeded timeout!\033[0m", i);
            end
          end

          assert (expected_valid == valid)
                            else
                              $error("\033[31mTest %0d failed: Expected valid = %b but got %b\033[0m", i, expected_valid, valid);

          if(!write && expected_valid) begin
            assert (expected_dataout == dataout)
                  else
                    $error("\033[31mTest %0d failed: Expected data_out = %h but got %h\033[0m", i, expected_dataout, dataout);
          end


          idle = 1'b1;

          #period;
          //#period;
        end

      $display("\033[32mTestbench finished running\033[0m");
      finished = 1;
      #period;
      $finish;
    end


endmodule