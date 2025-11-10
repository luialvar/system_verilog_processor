`timescale 1ns / 1ps

module imm_gen_tb;


logic clk;
logic [31:0] iword;
logic [31:0] immediate;
logic [63:0] test_vector;
logic [63:0] test_vectors [$];
logic [31:0] expected;

logic finished = 0;
real half_period = 5;
real period = 2 * half_period;

imm_gen dut (
    .iword(iword),
    .immediate(immediate)
  );

  assign expected = test_vector[31:0];
  assign iword = test_vector[63:32];




  initial
    begin
      $dumpfile("imm_gen.vcd");
      $dumpvars(0, dut);
      test_vectors.push_back({32'b00000000101001001001011110010011, 32'b00000000000000000000000000001010}); // Test 0: SLLI
      test_vectors.push_back({32'b01011100101110101000011000010011, 32'b00000000000000000000010111001011}); // Test 1: ADDI
      test_vectors.push_back({32'b11110000110110000111111010010011, 32'b11111111111111111111111100001101}); // Test 2: ANDI
      test_vectors.push_back({32'b11011110101010100110100100010011, 32'b11111111111111111111110111101010}); // Test 3: ORI
      test_vectors.push_back({32'b01100001100101000100100100010011, 32'b00000000000000000000011000011001}); // Test 4: XORI
      test_vectors.push_back({32'b01010011010101110010101010010011, 32'b00000000000000000000010100110101}); // Test 5: SLTI
      test_vectors.push_back({32'b01101111111111110011111100010011, 32'b00000000000000000000011011111111}); // Test 6: SLTIU
      test_vectors.push_back({32'b01000000001101101101010010010011, 32'b00000000000000000000010000000011}); // Test 7: SRAI
      test_vectors.push_back({32'b00000000011011100101110010010011, 32'b00000000000000000000000000000110}); // Test 8: SRLI
      test_vectors.push_back({32'b11111101110110001001111100110111, 32'b11111101110110001001000000000000}); // Test 9: LUI
      test_vectors.push_back({32'b10010000110011011111100110010111, 32'b10010000110011011111000000000000}); // Test 10: AUIPC
      test_vectors.push_back({32'b01011011000101111010000000000011, 32'b00000000000000000000010110110001}); // Test 11: LW
      test_vectors.push_back({32'b00001110100111010010101110100011, 32'b00000000000000000000000011110111}); // Test 12: SW
      test_vectors.push_back({32'b00100011010010001000100101100011, 32'b00000000000000000000001000110010}); // Test 13: BEQ
      test_vectors.push_back({32'b11010011001100111001011011100011, 32'b11111111111111111111110100101100}); // Test 14: BNE
      test_vectors.push_back({32'b00100111110111010100111011100011, 32'b00000000000000000000101001111100}); // Test 15: BLT
      test_vectors.push_back({32'b00100011100111010101000111100011, 32'b00000000000000000000101000100010}); // Test 16: BGE
      test_vectors.push_back({32'b10010011110101001110101001100011, 32'b11111111111111111111000100110100}); // Test 17: BLTU
      test_vectors.push_back({32'b10001101101100011111000001100011, 32'b11111111111111111111000011000000}); // Test 18: BGEU
      test_vectors.push_back({32'b11011101110001110011011011101111, 32'b11111111111101110011010111011100}); // Test 19: JAL
      test_vectors.push_back({32'b01111100101111010000010111100111, 32'b00000000000000000000011111001011}); // Test 20: JALR

      foreach (test_vectors[i])
      begin
        test_vector = test_vectors[i];
        #1;
        assert (immediate == expected)
               else
                 $error("\033[31mTest %0d failed: Expected imm = %h but got %h\033[0m", i, expected, immediate);
      end

    $display("\033[32mTestbench finished running\033[0m");
    finished = 1;
    #1;
    $finish;
    end


endmodule
