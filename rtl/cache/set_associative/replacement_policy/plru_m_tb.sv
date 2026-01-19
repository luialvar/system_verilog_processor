`timescale 1ps / 1ps

module plru_m_tb(); 
localparam ways = 8;
localparam way_bits = 3;
localparam sets = 16;
localparam set_bits = 4;

  logic clk;
  logic reset;
  logic enable;
  logic hit;
  logic [3:0] set;
  logic [2:0] way_hit;
  logic [2:0] way_replace; // the set that should be replaced
  logic rep_finished;
  logic finished;

  real half_period = 5;
  real period = 2 * half_period;

  logic [13:0] s_test_vector;
  logic [13:0] test_vectors[$];

  logic [2:0] expected_way_replace;

  assign enable = s_test_vector[11];
  assign hit = s_test_vector[10];
  assign expected_way_replace = s_test_vector[9:7];
  assign way_hit = s_test_vector[6:4];
  assign set = s_test_vector[3:0];

plru_m #(.ways(ways), .way_bits(way_bits), .sets(sets), .set_bits(set_bits)) dut (
    .clk(clk),
    .reset(reset),
    .hit(hit),
    .set(set),
    .way_hit(way_hit),
    .way_replace(way_replace), //output
    .finished(rep_finished)    //output
);



  always #half_period clk = ~clk;
  initial
    begin
      $dumpfile("plru_m");
      $dumpvars(0, dut);

      clk = 0;
      reset = 1;
      #period;
      reset = 0;      

      //TEST_CASES            expected_finish, hit,  expected_way_replace, way_hit, set
      test_vectors.push_back({1'b1,            1'b1, 3'b001,               3'b000,   4'b0000}); //Test  0: hit on set 0, way 0
      test_vectors.push_back({1'b1,            1'b1, 3'b001,               3'b010,   4'b0000}); //Test  1: hit on set 0, way 2
      test_vectors.push_back({1'b1,            1'b1, 3'b001,               3'b000,   4'b0011}); //Test  2: hit on set 3, way 0

      test_vectors.push_back({1'b1,            1'b1, 3'b011,               3'b001,   4'b0000}); //Test  3: hit on set 0, way 1
      test_vectors.push_back({1'b1,            1'b1, 3'b011,               3'b111,   4'b0000}); //Test  4: hit on set 0, way 7
      test_vectors.push_back({1'b1,            1'b1, 3'b010,               3'b001,   4'b0011}); //Test  5: hit on set 3, way 1

      test_vectors.push_back({1'b1,            1'b1, 3'b011,               3'b110,   4'b0000}); //Test  6: hit on set 0, way 6
      test_vectors.push_back({1'b1,            1'b1, 3'b011,               3'b100,   4'b0000}); //Test  7: hit on set 0, way 4
      test_vectors.push_back({1'b1,            1'b1, 3'b011,               3'b010,   4'b0011}); //Test  8: hit on set 3, way 2

      test_vectors.push_back({1'b1,            1'b1, 3'b101,               3'b011,   4'b0000}); //Test  9: hit on set 0, way 3
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b101,   4'b0000}); //Test 10: hit on set 0, way 5
      test_vectors.push_back({1'b1,            1'b1, 3'b100,               3'b011,   4'b0011}); //Test 11: hit on set 3, way 3

      test_vectors.push_back({1'b1,            1'b1, 3'b101,               3'b100,   4'b0011}); //Test 12: hit on set 3, way 4
      test_vectors.push_back({1'b1,            1'b1, 3'b110,               3'b101,   4'b0011}); //Test 13: hit on set 3, way 5
      test_vectors.push_back({1'b1,            1'b1, 3'b111,               3'b110,   4'b0011}); //Test 14: hit on set 3, way 6
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b111,   4'b0011}); //Test 15: hit on set 3, way 7
      
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b001,   4'b1111}); //Test 16: hit on set 15, way 1
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b010,   4'b1111}); //Test 17: hit on set 15, way 2
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b011,   4'b1111}); //Test 18: hit on set 15, way 3
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b100,   4'b1111}); //Test 19: hit on set 15, way 4
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b101,   4'b1111}); //Test 20: hit on set 15, way 5
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b110,   4'b1111}); //Test 21: hit on set 15, way 6
      test_vectors.push_back({1'b1,            1'b1, 3'b000,               3'b111,   4'b1111}); //Test 22: hit on set 15, way 7
      test_vectors.push_back({1'b1,            1'b1, 3'b001,               3'b000,   4'b1111}); //Test 23: hit on set 15, way 0

      // Testing all cases here
      foreach (test_vectors[i])
        begin
          $display("Running test %0d", i);

          s_test_vector = test_vectors[i];
          #period;

          assert (expected_way_replace == way_replace)
          else
            $error("\033[31mTest %0d failed: Wrong way_replace! Expected %d but got %d\033[0m", i, expected_way_replace, way_replace);

          assert (rep_finished)
          else
            $error("\033[31mTest %0d failed: Expected to finish in 1 cycle\033[0m", i);

        end

      $display("\033[32mTestbench finished running\033[0m");
      finished = 1;
      #period;
      $finish;
    end
endmodule