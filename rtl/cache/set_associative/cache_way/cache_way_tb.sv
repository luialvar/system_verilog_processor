`timescale 1ps / 1ps

module cache_set_associative_tb();

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
  logic idle = 0;

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

cache_way #(
            .set_bits(set_bits),
            .tag_bits(tag_bits),
            .offset_bits(offset_end - offset_start + 1)
        ) i_way (
            .clk(clk),
            .reset(reset),
            .enable(enable[t]),
            .write(cache_write),
            .tag(addr[23:set_end + 1]),
            .set(addr[set_end:set_start]),
            .offset(offset),
            .data_in(sram_data_out),
            .valid(valid_flag),
            .hit(vec_hit[t]),
            .data_out(vec_data_out[t])
        );

  int k;
  always #half_period clk = ~clk;
  initial
    begin
      $dumpfile("cache_set_associative.vcd");
      $dumpvars(0, dut);

      /*for (int i = 0; i < 128; i++) begin
        $dumpvars(1, i_cache_content[i]);
        $dumpvars(1, d_cache_content[i]);
      end */

      reset = 1;
      #period;
      reset = 0;

      //TEST_CASES            addr        datain        ex_dataout    write busy  valid iread
      test_vectors.push_back({24'h000000, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 0: read from addr 0
      test_vectors.push_back({24'h000004, 32'h00000000, 32'h00000001, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 1: read from addr 4, should be cached
      test_vectors.push_back({24'h000014, 32'h00000000, 32'h00000005, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 2: read from addr 20, should be cached
      test_vectors.push_back({24'h000020, 32'h00000000, 32'h00000008, 1'b0, 1'b0, 1'b1, 1'b0}); //Test 3: read from addr 32
/*
      test_vectors.push_back({24'h000021, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b0, 1'b0}); //Test 4: read from missaligned addr
      test_vectors.push_back({24'h000092, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b0, 1'b0}); //Test 5: read from missaligned addr
      test_vectors.push_back({24'h000663, 32'h00000000, 32'h00000000, 1'b0, 1'b0, 1'b0, 1'b0}); //Test 6: read from missaligned addr

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
*/
      // Testing all cases here
      foreach (test_vectors[i])
        begin
          $display("Running test %0d", i);

          c_test_vector = test_vectors[i];
          reset = 1'b0;

          k = 0;
          while(dut.busy && k <= 2000) begin
            #period;
            if( k++ == 2000) begin
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

          reset = 1'b1;

          #period;
        end

      $display("\033[32mTestbench finished running\033[0m");
      finished = 1;
      #period;
      $finish;
    end


endmodule