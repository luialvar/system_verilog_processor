module cpu (
    input  logic clk,
    input  logic reset, // active low due to pico-ice button
    input  logic intr_ext,

    input  logic so,
    output logic si,
    output logic sclk,
    output logic sram_ce,

    output logic scl,
    inout  logic sda,

    output logic tx,

    input  logic [7:0] gpio_in,
    output logic [7:0] gpio_out
);

    // ------------------------------------------------------------
    // [REQ1] Invertir reset (botón activo-bajo -> reset interno activo-alto)
    // ------------------------------------------------------------
    logic rst;
    assign rst = ~reset;

    // ------------------------------------------------------------
    // Señales internas
    // ------------------------------------------------------------
    logic [31:0] iword;

    // Control Unit
    logic        csr_write, mret, jump_to_isr;
    logic [31:0] immediate;
    logic [5:0]  control_flags; // [0]=mem_phase,[1]=memwrite,[2]=regwrite,[3]=auipc,[4]=imm_flag,[5]=jump_flag
    logic        wbflag, memflag, pcflag, fetchflag;
    logic        mem_ce;

    // Regs
    logic [31:0] rs1, rs2;
    logic [31:0] regs_rd_data;
    logic        regs_regwrite;

    // PC unit
    logic [15:0] pc_new;
    logic        pc_misaligned;
    logic [1:0]  jump;
    logic [15:0] pc_imm;

    // ALU
    logic [31:0] alu_a, alu_b;
    logic [16:0] alu_instruction;
    logic [31:0] alu_rd;
    logic        illegal_instruction;

    // Registro para guardar salida ALU (rd_alu) como en el esquema
    logic [31:0] rd_alu;

    // Memory
    logic [31:0] mem_addr;
    logic [31:0] mem_dataout;
    logic        mem_busy, mem_valid;
    logic        intr_timer;
    logic        load_access_fault;
    logic        memwrite_cpu;

    // CSR
    logic [2:0]  exceptions;
    logic        interrupt_pending;
    logic [31:0] csr_data_out;
    logic [15:0] isr_target, isr_return;

    // ------------------------------------------------------------
    // (Extra del top) Exceptions vector
    // ------------------------------------------------------------
    assign exceptions = {load_access_fault, illegal_instruction, pc_misaligned};

    // ------------------------------------------------------------
    // [REQ2] iword register: cargar mem_dataout en flanco + cuando fetchflag=1; reset => 0
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            iword <= 32'd0;
        else if (fetchflag)
            iword <= mem_dataout;
    end

    // ------------------------------------------------------------
    // (Extra del top) Capturar salida ALU (multi-cycle EX -> MEM/WB)
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            rd_alu <= 32'd0;
        else
            rd_alu <= alu_rd;
    end

    // ------------------------------------------------------------
    // [REQ7] instruction para ALU = {funct7, funct3, opcode} (17 bits)
    // ------------------------------------------------------------
    assign alu_instruction = { iword[31:25], iword[14:12], iword[6:0] };

    // ------------------------------------------------------------
    // [REQ8] ALU input a: rs1 o pc_new según auipc
    // ------------------------------------------------------------
    assign alu_a = (control_flags[3]) ? {16'd0, pc_new} : rs1;

    // ------------------------------------------------------------
    // [REQ9] ALU input b: imm o rs2 según imm_flag
    // ------------------------------------------------------------
    assign alu_b = (control_flags[4]) ? immediate : rs2;

    // ------------------------------------------------------------
    // [REQ3] memwrite gating: sólo en fase MEM (memflag=1), si no => 0  (mux f)
    // ------------------------------------------------------------
    assign memwrite_cpu = (memflag) ? control_flags[1] : 1'b0;

    // ------------------------------------------------------------
    // [REQ4] mem_addr mux (c): memflag ? rd_alu : pc_new (zero-extend)
    // ------------------------------------------------------------
    assign mem_addr = (memflag) ? rd_alu : {16'd0, pc_new};

    // ------------------------------------------------------------
    // [REQ5] jalr immediate mux (e): si JALR, imm hacia PC = rd_alu[15:0]; si no, immediate[15:0]
    // ------------------------------------------------------------
    logic is_jal, is_jalr, is_csrr;
    assign is_jal  = (iword[6:0] == 7'b1101111);
    assign is_jalr = (iword[6:0] == 7'b1100111);
    assign is_csrr = (iword[6:0] == 7'b1110011) && (iword[14:12] == 3'b010);

    assign pc_imm = (is_jalr) ? rd_alu[15:0] : immediate[15:0];

    // ------------------------------------------------------------
    // [REQ6] jump mux (d):
    //   - si mret => jump=11
    //   - si jump_flag => jump = rd_alu[17:16] (bits puestos por la ALU para tipo de salto)
    //   - si no => jump=10 (PC+4)
    // ------------------------------------------------------------
    always @* begin
        if (mret)
            jump = 2'b11;
        else if (control_flags[5])
            jump = rd_alu[17:16];
        else
            jump = 2'b10;
    end

    // ------------------------------------------------------------
    // [REQ10] rd mux hacia regs (rd multiplexer):
    //   - jal/jalr => pc_new + 4
    //   - mem_phase => mem_dataout
    //   - csrr => csr_data_out
    //   - else => rd_alu
    // ------------------------------------------------------------
    always @* begin
        if (is_jal || is_jalr)
            regs_rd_data = {16'd0, pc_new} + 32'd4;
        else if (control_flags[0]) // mem_phase (lw/sw)
            regs_rd_data = mem_dataout;
        else if (is_csrr)
            regs_rd_data = csr_data_out;
        else
            regs_rd_data = rd_alu;
    end

    // (Extra del top) regwrite sólo en WB
    assign regs_regwrite = control_flags[2] & wbflag;

    // ------------------------------------------------------------
    // Instanciaciones (conexión de componentes)
    // ------------------------------------------------------------
    control u_control (
        .clk              (clk),
        .reset            (rst),
        .iword            (iword),
        .interrupt_pending(interrupt_pending),
        .exceptions       (exceptions),
        .mem_busy         (mem_busy),
        .mem_valid        (mem_valid),

        .csr_write        (csr_write),
        .mret             (mret),
        .jump_to_isr      (jump_to_isr),

        .immediate        (immediate),
        .control_flags    (control_flags),

        .wbflag           (wbflag),
        .memflag          (memflag),
        .pcflag           (pcflag),
        .fetchflag        (fetchflag),
        .mem_ce           (mem_ce)
    );

    regs u_regs (
        .clk      (clk),
        .reset    (rst),
        .rs1adr   (iword[19:15]),
        .rs2adr   (iword[24:20]),
        .rdadr    (iword[11:7]),
        .rd       (regs_rd_data),
        .regwrite (regs_regwrite),
        .rs1      (rs1),
        .rs2      (rs2)
    );

    alu u_alu (
        .a                 (alu_a),
        .b                 (alu_b),
        .instruction       (alu_instruction),
        .rd                (alu_rd),
        .illegal_instruction(illegal_instruction)
    );

    pc_unit u_pc (
        .clk         (clk),
        .reset       (rst),
        .pcflag      (pcflag),
        .jump        (jump),
        .imm         (pc_imm),
        .isr_target  (isr_target),
        .isr_return  (isr_return),
        .interrupt   (jump_to_isr),
        .pc_new      (pc_new),
        .pc_misaligned(pc_misaligned)
    );

    csr u_csr (
        .clk              (clk),
        .reset            (rst),
        .exceptions       (exceptions),
        .intr_timer       (intr_timer),
        .intr_ext         (intr_ext),
        .mret             (mret),
        .enter_isr        (jump_to_isr),

        .data_in          (rs1),
        .addr             (iword[31:20]),
        .write_en         (csr_write),
        .pc               (pc_new),

        .interrupt_pending(interrupt_pending),
        .data_out         (csr_data_out),
        .isr_return       (isr_return),
        .isr_target       (isr_target)
    );

    memory u_mem (
        .clk              (clk),
        .reset            (rst),
        .ce               (mem_ce),
        .addr             (mem_addr),
        .datain           (rs2),
        .memwrite         (memwrite_cpu),

        .so               (so),mem_flag
        .sda              (sda),
        .gpio_in          (gpio_in),

        .dataout          (mem_dataout),
        .busy             (mem_busy),
        .valid            (mem_valid),mem_flag

        .si               (si),
        .sclk             (sclk),
        .sram_ce          (sram_ce),

        .scl              (scl),
        .tx               (tx),
        .gpio_out         (gpio_out),

        .intr_timer       (intr_timer),
        .load_access_fault(load_access_fault)
    );

endmodule

/*

module cpu (
    input  logic clk,
    input  logic reset, // active low due to pico-ice button
    input  logic intr_ext,

    input  logic so,
    output logic si,
    output logic sclk,
    output logic sram_ce,

    output logic scl,
    inout  logic sda,

    output logic tx,

    input  logic [7:0] gpio_in,
    output logic [7:0] gpio_out
);

    // ------------------------------------------------------------
    // 1) Reset activo-bajo del botón -> reset interno activo-alto
    // ------------------------------------------------------------
    logic rst;
    assign rst = ~reset;  // lo que muestra el diagrama con la tilde

    // ------------------------------------------------------------
    // Señales internas
    // ------------------------------------------------------------
    logic [31:0] iword;

    // Control Unit
    logic        csr_write, mret, jump_to_isr;
    logic [31:0] immediate;
    logic [5:0]  control_flags; // [0]=mem_phase,[1]=memwrite,[2]=regwrite,[3]=auipc,[4]=imm_flag,[5]=jump_flag
    logic        wbflag, memflag, pcflag, fetchflag;
    logic        mem_ce;

    // Regs
    logic [31:0] rs1, rs2;
    logic [31:0] regs_rd_data;
    logic        regs_regwrite;

    // PC unit
    logic [15:0] pc_new;
    logic        pc_misaligned;
    logic [1:0]  jump;
    logic [15:0] pc_imm;

    // ALU
    logic [31:0] alu_a, alu_b;
    logic [16:0] alu_instruction;
    logic [31:0] alu_rd;
    logic        illegal_instruction;

    // Registro para guardar salida ALU (rd_alu) como en el esquema
    logic [31:0] rd_alu;

    // Memory
    logic [31:0] mem_addr;
    logic [31:0] mem_dataout;
    logic        mem_busy, mem_valid;
    logic        intr_timer;
    logic        load_access_fault;
    logic        memwrite_cpu;

    // CSR
    logic [2:0]  exceptions;
    logic        interrupt_pending;
    logic [31:0] csr_data_out;
    logic [15:0] isr_target, isr_return;

    // ------------------------------------------------------------
    // 2) Exceptions vector (bit2=load_access_fault, bit1=illegal, bit0=pc_misaligned)
    // ------------------------------------------------------------
    assign exceptions = {load_access_fault, illegal_instruction, pc_misaligned};

    // ------------------------------------------------------------
    // 3) iword register: cargar desde memoria cuando fetchflag=1, reset => 0
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            iword <= 32'd0;
        else if (fetchflag)
            iword <= mem_dataout;
    end

    // ------------------------------------------------------------
    // 4) Capturar salida ALU en rd_alu (multi-cycle: EX -> MEM/WB)
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst)
            rd_alu <= 32'd0;
        else
            rd_alu <= alu_rd;
    end

    // ------------------------------------------------------------
    // 5) instruction para ALU = {funct7, funct3, opcode} (17 bits)
    // ------------------------------------------------------------
    assign alu_instruction = { iword[31:25], iword[14:12], iword[6:0] };

    // ------------------------------------------------------------
    // 6) ALU input a: rs1 o pc_new según auipc
    // ------------------------------------------------------------
    assign alu_a = (control_flags[3]) ? {16'd0, pc_new} : rs1;

    // ------------------------------------------------------------
    // 7) ALU input b: imm o rs2 según imm_flag
    // ------------------------------------------------------------
    assign alu_b = (control_flags[4]) ? immediate : rs2;

    // ------------------------------------------------------------
    // 8) memwrite gating: sólo en fase memflag, si no => 0 (mux f)
    // ------------------------------------------------------------
    assign memwrite_cpu = (memflag) ? control_flags[1] : 1'b0;

    // ------------------------------------------------------------
    // 9) mem_addr mux (c): memflag ? rd_alu : pc_new (zero-extend)
    // ------------------------------------------------------------
    assign mem_addr = (memflag) ? rd_alu : {16'd0, pc_new};

    // ------------------------------------------------------------
    // 10) jalr immediate mux (e): pc_imm = jalr ? rd_alu[15:0] : immediate[15:0]
    //     Detectamos jalr por opcode (1100111)
    // ------------------------------------------------------------
    logic is_jal, is_jalr, is_csrr;
    assign is_jal  = (iword[6:0] == 7'b1101111);
    assign is_jalr = (iword[6:0] == 7'b1100111);
    assign is_csrr = (iword[6:0] == 7'b1110011) && (iword[14:12] == 3'b010);

    assign pc_imm = (is_jalr) ? rd_alu[15:0] : immediate[15:0];

    // ------------------------------------------------------------
    // 11) jump mux (d):
    //     - si mret => 11
    //     - si jump_flag => rd_alu[17:16]
    //     - si no => 10 (increment +4)
    // ------------------------------------------------------------
    always @* begin
        if (mret)
            jump = 2'b11;
        else if (control_flags[5])
            jump = rd_alu[17:16];
        else
            jump = 2'b10;
    end

    // ------------------------------------------------------------
    // 12) rd mux hacia regs (rd multiplexer)
    //     - jal/jalr => pc_new + 4
    //     - si mem_phase => mem_dataout
    //     - si csrr => csr_data_out
    //     - else => rd_alu
    // ------------------------------------------------------------
    always @* begin
        if (is_jal || is_jalr)
            regs_rd_data = {16'd0, pc_new} + 32'd4;
        else if (control_flags[0]) // mem_phase (lw/sw)
            regs_rd_data = mem_dataout;
        else if (is_csrr)
            regs_rd_data = csr_data_out;
        else
            regs_rd_data = rd_alu;
    end

    // regs_regwrite debe ir sólo en WB para no pisar registros con basura:contentReference[oaicite:16]{index=16}
    assign regs_regwrite = control_flags[2] & wbflag;

    // ------------------------------------------------------------
    // Instanciaciones
    // ------------------------------------------------------------

    control u_control (
        .clk              (clk),
        .reset            (rst),
        .iword            (iword),
        .interrupt_pending(interrupt_pending),
        .exceptions       (exceptions),
        .mem_busy         (mem_busy),
        .mem_valid        (mem_valid),

        .csr_write        (csr_write),
        .mret             (mret),
        .jump_to_isr      (jump_to_isr),

        .immediate        (immediate),
        .control_flags    (control_flags),

        .wbflag           (wbflag),
        .memflag          (memflag),
        .pcflag           (pcflag),
        .fetchflag        (fetchflag),
        .mem_ce           (mem_ce)
    );

    regs u_regs (
        .clk      (clk),
        .reset    (rst),
        .rs1adr   (iword[19:15]),
        .rs2adr   (iword[24:20]),
        .rdadr    (iword[11:7]),
        .rd       (regs_rd_data),
        .regwrite (regs_regwrite),
        .rs1      (rs1),
        .rs2      (rs2)
    );

    alu u_alu (
        .a                 (alu_a),
        .b                 (alu_b),
        .instruction       (alu_instruction),
        .rd                (alu_rd),
        .illegal_instruction(illegal_instruction)
    );

    pc_unit u_pc (
        .clk         (clk),
        .reset       (rst),
        .pcflag     (pcflag),
        .jump        (jump),
        .imm         (pc_imm),
        .isr_target  (isr_target),
        .isr_return  (isr_return),
        .interrupt   (jump_to_isr),
        .pc_new      (pc_new),
        .pc_misaligned(pc_misaligned)
    );

    csr u_csr (
        .clk              (clk),
        .reset            (rst),
        .exceptions       (exceptions),
        .intr_timer       (intr_timer),
        .intr_ext         (intr_ext),
        .mret             (mret),
        .enter_isr        (jump_to_isr),

        .data_in          (rs1),
        .addr             (iword[31:20]),
        .write_en         (csr_write),
        .pc               (pc_new),

        .interrupt_pending(interrupt_pending),
        .data_out         (csr_data_out),
        .isr_return       (isr_return),
        .isr_target       (isr_target)
    );

    memory u_mem (
        .clk              (clk),
        .reset            (rst),
        .ce               (mem_ce),
        .addr             (mem_addr),
        .datain           (rs2),
        .memwrite         (memwrite_cpu),

        .so               (so),
        .sda              (sda),
        .gpio_in          (gpio_in),

        .dataout          (mem_dataout),
        .busy             (mem_busy),
        .valid            (mem_valid),

        .si               (si),
        .sclk             (sclk),
        .sram_ce          (sram_ce),

        .scl              (scl),
        .tx               (tx),
        .gpio_out         (gpio_out),

        .intr_timer       (intr_timer),
        .load_access_fault(load_access_fault)
    );

endmodule


*/