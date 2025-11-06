`timescale 1ns / 1ps

module alu_tb;

  logic clk = 0;
  logic reset = 0;
  logic [31:0] a;
  logic [31:0] b;
  logic [16:0] instruction;
  logic [31:0] rd;
  logic [31:0] rd_expected;
  logic illegal_instruction;
  logic illegal_instruction_expected;

  logic finished = 0;
  real half_period = 5;
  real period = 2 * half_period;
  string line;
  int    FILE,code;

  logic [113:0] alu_test_vector;

  logic [113:0] test_vectors [$];

  alu dut (
        .a(a),
        .b(b),
        .instruction(instruction),
        .rd(rd),
        .illegal_instruction(illegal_instruction)
  );

  always #half_period clk = ~clk;

  assign a = alu_test_vector[113:82];
  assign b = alu_test_vector[81:50];
  assign rd_expected = alu_test_vector[49:18];
  assign instruction = alu_test_vector[17:1];
  assign illegal_instruction_expected = alu_test_vector[0];


  initial
    begin
      $dumpfile("alu.vcd");
      $dumpvars(0, dut);
      reset = 1;
      #period;
      reset = 0;

      //TEST
      test_vectors.push_back({32'h00000001, 32'h00000100, 32'h00000101, INST_ADD, 1'b0});  // Test 0: ADD normal
      test_vectors.push_back({32'h0001E692, 32'h00000856, 32'h0001EEE8, INST_ADD, 1'b0});  // Test 1: ADD normal
      test_vectors.push_back({32'h9B342A10, 32'hB12BD999, 32'h4C6003A9, INST_ADD, 1'b0});  // Test 2: ADD normal
      test_vectors.push_back({32'hFFFFFFFF, 32'h00000001, 32'h00000000, INST_ADDI, 1'b0}); // Test 3: ADDI with overflow
      test_vectors.push_back({32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, INST_ADDI, 1'b0}); // Test 4: ADDI with negative numbers
      test_vectors.push_back({32'h0001E692, 32'hFFFFF856, 32'h0001DEE8, INST_ADDI, 1'b0}); // Test 5: ADDI with negative numbers
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'h0FF0FFFF, INST_AND, 1'b0});  // Test 6: AND normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h00000000, INST_AND, 1'b0});  // Test 7: AND normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'h0002B042, INST_AND, 1'b0});  // Test 8: AND normal
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'h0FF0FFFF, INST_ANDI, 1'b0}); // Test 9: ANDI normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h00000000, INST_ANDI, 1'b0}); // Test 10: ANDI normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'h0002B042, INST_ANDI, 1'b0}); // Test 11: ANDI normal
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'hFFFFFFFF, INST_OR, 1'b0});   // Test 12: OR normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h0FCAF92F, INST_OR, 1'b0});   // Test 13: OR normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'hA91ABD4F, INST_OR, 1'b0});   // Test 14: OR normal
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'hFFFFFFFF, INST_ORI, 1'b0});  // Test 15: ORI normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h0FCAF92F, INST_ORI, 1'b0});  // Test 16: ORI normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'hA91ABD4F, INST_ORI, 1'b0});  // Test 17: ORI normal
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'hF00F0000, INST_XOR, 1'b0});  // Test 18: XOR normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h0FCAF92F, INST_XOR, 1'b0});  // Test 19: XOR normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'hA9180D0D, INST_XOR, 1'b0});  // Test 20: XOR normal
      test_vectors.push_back({32'hFFF0FFFF, 32'h0FFFFFFF, 32'hF00F0000, INST_XORI, 1'b0}); // Test 21: XORI normal
      test_vectors.push_back({32'h00000000, 32'h0FCAF92F, 32'h0FCAF92F, INST_XORI, 1'b0}); // Test 22: XORI normal
      test_vectors.push_back({32'hA912BC4F, 32'h000AB142, 32'hA9180D0D, INST_XORI, 1'b0}); // Test 23: XORI normal
      test_vectors.push_back({32'h00000011, 32'h00000003, 32'h00000033, INST_MUL, 1'b0});  // Test 24: MUL normal
      test_vectors.push_back({32'hFFFFFF11, 32'hFFFFFFF3, 32'h00000C23, INST_MUL, 1'b0});  // Test 25: MUL with overflow
      test_vectors.push_back({32'h00A0010D, 32'h00000001, 32'h0140021A, INST_SLL, 1'b0});  // Test 26: SLL by 1
      test_vectors.push_back({32'h00A0010D, 32'hFFFFFF00, 32'h00A0010D, INST_SLL, 1'b0});  // Test 27: SLL by 0
      test_vectors.push_back({32'h00A0010D, 32'hFFFFFF20, 32'h00A0010D, INST_SLL, 1'b0});  // Test 28: SLL by 0
      test_vectors.push_back({32'h00000001, 32'h0000001F, 32'h80000000, INST_SLL, 1'b0});  // Test 29: SLL by 31
      test_vectors.push_back({32'h00A0010D, 32'h00000001, 32'h0140021A, INST_SLLI, 1'b0}); // Test 30: SLLI by 1
      test_vectors.push_back({32'h00A0010D, 32'hFFFFFF00, 32'h00A0010D, INST_SLLI, 1'b0}); // Test 31: SLLI by 0
      test_vectors.push_back({32'h00A0010D, 32'hFFFFFF20, 32'h00A0010D, INST_SLLI, 1'b0}); // Test 32: SLLI by 0
      test_vectors.push_back({32'h00000001, 32'h0000001F, 32'h80000000, INST_SLLI, 1'b0}); // Test 33: SLLI by 31
      test_vectors.push_back({32'h00000ABC, 32'h00000003, 32'h00000157, INST_SRA, 1'b0});  // Test 34: Positive SRA by 3
      test_vectors.push_back({32'h000392F0, 32'h0000000F, 32'h00000007, INST_SRA, 1'b0});  // Test 35: Positive SRA by 15
      test_vectors.push_back({32'h000000F0, 32'h0000001F, 32'h00000000, INST_SRA, 1'b0});  // Test 36: Positive SRA by 31
      test_vectors.push_back({32'h000000F0, 32'h00000000, 32'h000000F0, INST_SRA, 1'b0});  // Test 37: Positive SRA by 0
      test_vectors.push_back({32'hFFFFC80F, 32'h00000005, 32'hFFFFFE40, INST_SRA, 1'b0});  // Test 38: Negative SRA by 5
      test_vectors.push_back({32'h00000ABC, 32'h00000003, 32'h00000157, INST_SRAI, 1'b0}); // Test 39: Positive SRAI by 3
      test_vectors.push_back({32'h000392F0, 32'h0000000F, 32'h00000007, INST_SRAI, 1'b0}); // Test 40: Positive SRAI by 15
      test_vectors.push_back({32'h000000F0, 32'h0000001F, 32'h00000000, INST_SRAI, 1'b0}); // Test 41: Positive SRAI by 31
      test_vectors.push_back({32'h000000F0, 32'h00000000, 32'h000000F0, INST_SRAI, 1'b0}); // Test 42: Positive SRAI by 0
      test_vectors.push_back({32'hFFFFC80F, 32'h00000005, 32'hFFFFFE40, INST_SRAI, 1'b0}); // Test 43: Negative SRAI by 5
      test_vectors.push_back({32'h00000ABC, 32'h00000003, 32'h00000157, INST_SRL, 1'b0});   // Test 44: SRL positive by 3
      test_vectors.push_back({32'h000392F0, 32'h0000000F, 32'h00000007, INST_SRL, 1'b0});   // Test 45: SRL positive by 15
      test_vectors.push_back({32'h000000F0, 32'h0000001F, 32'h00000000, INST_SRL, 1'b0});   // Test 46: SRL positive by 31
      test_vectors.push_back({32'h000000F0, 32'h00000000, 32'h000000F0, INST_SRL, 1'b0});   // Test 47: SRL positive by 0
      test_vectors.push_back({32'hFFFFC80F, 32'h00000005, 32'h07FFFE40, INST_SRL, 1'b0});   // Test 48: SRL negative by 5
      test_vectors.push_back({32'h00000ABC, 32'h00000003, 32'h00000157, INST_SRLI, 1'b0});  // Test 49: SRLI positive by 3
      test_vectors.push_back({32'h000392F0, 32'h0000000F, 32'h00000007, INST_SRLI, 1'b0});  // Test 50: SRLI positive by 15
      test_vectors.push_back({32'h000000F0, 32'h0000001F, 32'h00000000, INST_SRLI, 1'b0});  // Test 51: SRLI positive by 31
      test_vectors.push_back({32'h000000F0, 32'h00000000, 32'h000000F0, INST_SRLI, 1'b0});  // Test 52: SRLI positive by 0
      test_vectors.push_back({32'hFFFFC80F, 32'h00000005, 32'h07FFFE40, INST_SRLI, 1'b0});  // Test 53: SRLI negative by 5
      test_vectors.push_back({32'hFFFFFFFF, 32'h00000001, 32'h00000000, INST_LW, 1'b0});    // Test 54: LW with overflow
      test_vectors.push_back({32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, INST_LW, 1'b0});    // Test 55: LW with negative numbers
      test_vectors.push_back({32'h0001E692, 32'hFFFFF856, 32'h0001DEE8, INST_LW, 1'b0});    // Test 56: LW with negative numbers
      test_vectors.push_back({32'hFFFFFFFF, 32'h00000001, 32'h00000000, INST_SW, 1'b0});    // Test 57: SW with overflow
      test_vectors.push_back({32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFE, INST_SW, 1'b0});    // Test 58: SW with negative numbers
      test_vectors.push_back({32'h0001E692, 32'hFFFFF856, 32'h0001DEE8, INST_SW, 1'b0});    // Test 59: SW with negative numbers
      test_vectors.push_back({32'h00000000, 32'h00000001, 32'h00000001, INST_SLT, 1'b0});    // Test 60: SLT
      test_vectors.push_back({32'h00000001, 32'h00000001, 32'h00000000, INST_SLT, 1'b0});    // Test 61: SLT
      test_vectors.push_back({32'h00000001, 32'h00000000, 32'h00000000, INST_SLT, 1'b0});    // Test 62: SLT
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00000000, INST_SLT, 1'b0});    // Test 63: SLT
      test_vectors.push_back({32'h01000111, 32'h01001010, 32'h00000001, INST_SLT, 1'b0});    // Test 64: SLT
      test_vectors.push_back({32'hF1000111, 32'h00000010, 32'h00000001, INST_SLT, 1'b0});    // Test 65: SLT
      test_vectors.push_back({32'hF0000111, 32'hF1000010, 32'h00000001, INST_SLT, 1'b0});    // Test 66: SLT
      test_vectors.push_back({32'h00000000, 32'h00000001, 32'h00000001, INST_SLTI, 1'b0});   // Test 67: SLTI
      test_vectors.push_back({32'h00000001, 32'h00000001, 32'h00000000, INST_SLTI, 1'b0});   // Test 68: SLTI
      test_vectors.push_back({32'h00000001, 32'h00000000, 32'h00000000, INST_SLTI, 1'b0});   // Test 69: SLTI
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00000000, INST_SLTI, 1'b0});   // Test 70: SLTI
      test_vectors.push_back({32'h01000111, 32'h01001010, 32'h00000001, INST_SLTI, 1'b0});   // Test 71: SLTI
      test_vectors.push_back({32'hF1000111, 32'h00000010, 32'h00000001, INST_SLTI, 1'b0});   // Test 72: SLTI
      test_vectors.push_back({32'hF0000111, 32'hF1000010, 32'h00000001, INST_SLTI, 1'b0});   // Test 73: SLTI
      test_vectors.push_back({32'h00000000, 32'h00000001, 32'h00000001, INST_SLTU, 1'b0});   // Test 74: SLTU
      test_vectors.push_back({32'h00000001, 32'h00000001, 32'h00000000, INST_SLTU, 1'b0});   // Test 75: SLTU
      test_vectors.push_back({32'h00000001, 32'h00000000, 32'h00000000, INST_SLTU, 1'b0});   // Test 76: SLTU
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00000000, INST_SLTU, 1'b0});   // Test 77: SLTU
      test_vectors.push_back({32'h01000111, 32'h01001010, 32'h00000001, INST_SLTU, 1'b0});   // Test 78: SLTU
      test_vectors.push_back({32'hF1000111, 32'h00000010, 32'h00000000, INST_SLTU, 1'b0});   // Test 79: SLTU
      test_vectors.push_back({32'hF0000111, 32'hF1000010, 32'h00000001, INST_SLTU, 1'b0});   // Test 80: SLTU
      test_vectors.push_back({32'h00000000, 32'h00000001, 32'h00000001, INST_SLTIU, 1'b0});   // Test 81: SLTIU
      test_vectors.push_back({32'h00000001, 32'h00000001, 32'h00000000, INST_SLTIU, 1'b0});   // Test 82: SLTIU
      test_vectors.push_back({32'h00000001, 32'h00000000, 32'h00000000, INST_SLTIU, 1'b0});   // Test 83: SLTIU
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00000000, INST_SLTIU, 1'b0});   // Test 84: SLTIU
      test_vectors.push_back({32'h01000111, 32'h01001010, 32'h00000001, INST_SLTIU, 1'b0});   // Test 85: SLTIU
      test_vectors.push_back({32'hF1000111, 32'h00000010, 32'h00000000, INST_SLTIU, 1'b0});   // Test 86: SLTIU
      test_vectors.push_back({32'hF0000111, 32'hF1000010, 32'h00000001, INST_SLTIU, 1'b0});   // Test 87: SLTIU
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00010120, INST_JALR, 1'b0});    // Test 88: JALR
      test_vectors.push_back({32'h00000111, 32'h00000010, 32'h00000010, INST_LUI, 1'b0});     // Test 89: LUI
      test_vectors.push_back({32'h00000111, 32'h000F0010, 32'h000F0010, INST_LUI, 1'b0});     // Test 90: LUI
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00020000, INST_BNE, 1'b0});      // Test 91: BNE (no jump)
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00020000, INST_BNE, 1'b0});      // Test 92: BNE (no jump)
      test_vectors.push_back({32'hABDC29B2, 32'hABDC29B2, 32'h00020000, INST_BNE, 1'b0});      // Test 93: BNE (no jump)
      test_vectors.push_back({32'h0000000A, 32'h0000000A, 32'h00020000, INST_BNE, 1'b0});      // Test 94: BNE (no jump)
      test_vectors.push_back({32'hAB193BD1, 32'h13948201, 32'h00000000, INST_BNE, 1'b0});      // Test 95: BNE (jump)
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00000000, INST_BNE, 1'b0});      // Test 96: BNE (jump)
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_BNE, 1'b0});      // Test 97: BNE (jump)
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00000000, INST_BEQ, 1'b0});      // Test 98: BEQ
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00000000, INST_BEQ, 1'b0});      // Test 99: BEQ
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00020000, INST_BEQ, 1'b0});      // Test 100: BEQ
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00020000, INST_BEQ, 1'b0});      // Test 101: BEQ
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00020000, INST_BLT, 1'b0});      // Test 102: BLT
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00020000, INST_BLT, 1'b0});      // Test 103: BLT
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00020000, INST_BLT, 1'b0});      // Test 104: BLT
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_BLT, 1'b0});      // Test 105: BLT
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00000000, INST_BGE, 1'b0});      // Test 106: BGE
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00000000, INST_BGE, 1'b0});      // Test 107: BGE
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00000000, INST_BGE, 1'b0});      // Test 108: BGE
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00020000, INST_BGE, 1'b0});      // Test 109: BGE
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00020000, INST_BLTU, 1'b0});     // Test 110: BLTU
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00020000, INST_BLTU, 1'b0});     // Test 111: BLTU
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00000000, INST_BLTU, 1'b0});     // Test 112: BLTU
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00020000, INST_BLTU, 1'b0});     // Test 113: BLTU
      test_vectors.push_back({32'h00000000, 32'h00000000, 32'h00000000, INST_BGEU, 1'b0});     // Test 114: BGEU
      test_vectors.push_back({32'h12345678, 32'h12345678, 32'h00000000, INST_BGEU, 1'b0});     // Test 115: BGEU
      test_vectors.push_back({32'h10283010, 32'hAB19DDE9, 32'h00020000, INST_BGEU, 1'b0});     // Test 116: BGEU
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_BGEU, 1'b0});     // Test 117: BGEU
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_MRET, 1'b0});     // Test 118: MRET
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_CSRR, 1'b0});     // Test 119: CSRR
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, INST_CSRW, 1'b0});     // Test 120: CSRW
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, 16'd0, 1'b1});         // Test 121: Unknown
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, 16'd12345, 1'b1});     // Test 122: Unknown
      test_vectors.push_back({32'hFFF19390, 32'h018001BC, 32'h00000000, 16'd9876, 1'b1});      // Test 123: Unknown


      // Testing all cases here
      foreach (test_vectors[i])
        begin
          alu_test_vector = test_vectors[i];
          //$strobe("a = %h b = %h rd_exp = %h INST = %b number= %0d", a, b, rd_expected, instruction, i);

          #period;


          assert (rd == rd_expected)
                 else
                   $error("\033[31mTest %0d failed: a = %h b = %h Expected rd = %h but got %h\033[0m", i, a, b, rd_expected, rd);

          assert (illegal_instruction == illegal_instruction_expected)
                 else
                   $error("\033[31mTest %0d failed: a = %h b = %h Expected illegal_instruction = %h but got %h\033[0m", i, a, b, illegal_instruction_expected, illegal_instruction);
        end

      $display("\033[32mTestbench finished running\033[0m");
      finished = 1;
      #period;
      $finish;
    end

endmodule
