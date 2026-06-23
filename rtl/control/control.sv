module control (
    input  logic        clk,
    input  logic        reset,
    input  logic [31:0] iword,
    input  logic        mem_busy,
    input  logic        mem_valid,

    output logic [31:0] immediate,
    output logic [ 5:0] control_flags,
    output logic        wbflag,
    output logic        memflag,
    output logic        pcflag,
    output logic        fetchflag,
    output logic        mem_ce,

    input  logic        interrupt_pending,
    input  logic [2:0]  exceptions,     // [2]=load_access_fault, [1]=illegal_instruction, [0]=pc_misaligned
    output logic        jump_to_isr,
    output logic        mret,
    output logic        csr_write
);

    // -----------------------------
    // Instancia del Immediate Gen
    // -----------------------------
    imm_gen imm_gen_inst (
        .iword     (iword),      // entra la instrucción completa
        .immediate (immediate)   // sale el inmediato extendido a 32 bits
    );

    // -----------------------------
    // Estados de la Control Unit
    // -----------------------------
    typedef enum logic [3:0] {
        ST_RST,      // Reset
        ST_FE_A,     // Fetch_Await
        ST_FE,       // Fetch
        ST_ID,       // Instruction Decode
        ST_EX,       // Execute
        ST_MEM_A,    // Memory Await
        ST_MEM,      // Memory
        ST_WB,       // Writeback1
        ST_INTR      // Interrupt
    } state_t;

    state_t state, next_state;

    // -----------------------------
    // Decodificación básica del iword
    // -----------------------------
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [11:0] funct12;

    assign opcode  = iword[6:0];
    assign funct3  = iword[14:12];
    assign funct7  = iword[31:25];
    assign funct12 = iword[31:20];

    // Excepciones desglosadas
    logic pc_misaligned;
    logic illegal_instruction;
    logic load_access_fault;

    assign pc_misaligned     = exceptions[0];
    assign illegal_instruction = exceptions[1];
    assign load_access_fault = exceptions[2];

    // -----------------------------
// Flags de control a partir del opcode
// control_flags[0] = mem_phase   // 1 cuando la instrucción necesita fase de MEM de datos (LOAD/STORE: LW, SW)
// control_flags[1] = memwrite    // 1 solo para instrucciones que escriben en memoria de datos (STORE: SW)
// control_flags[2] = regwrite    // 1 cuando se escribe en un registro (R-type, I-type, LUI, AUIPC, LOAD, JAL, JALR, CSRR)
// control_flags[3] = auipc       // 1 solo en AUIPC, para indicar que la ALU debe usar PC como operando 'a'
// control_flags[4] = imm_flag    // 1 cuando la ALU debe usar el inmediato como operando 'b' (I-type, LOAD, STORE, JALR, LUI, AUIPC)
// control_flags[5] = jump_flag   // 1 en instrucciones que cambian el PC mediante salto (BRANCH, JAL, JALR)
    // -----------------------------
    logic mem_phase;
    logic memwrite;
    logic regwrite;
    logic auipc_flag;
    logic imm_flag;
    logic jump_flag;

    // Para CSR_write / MRET
    logic is_csrw_instr;
    logic is_mret_instr;

    // Constantes de opcodes RISC-V RV32I
    localparam logic [6:0] OPCODE_OP      = 7'b0110011; // R-Type
    localparam logic [6:0] OPCODE_OP_IMM  = 7'b0010011; // I-Type ALU
    localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;
    localparam logic [6:0] OPCODE_LOAD    = 7'b0000011; // LW
    localparam logic [6:0] OPCODE_STORE   = 7'b0100011; // SW
    localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
    localparam logic [6:0] OPCODE_SYSTEM  = 7'b1110011; // CSRR, CSRW, MRET

    // -----------------------------
    // DECODIFICACIÓN DE INSTRUCCIÓN
    // (solo para flags de control + CSRs)
    // basicamente esto nos dice que tipo de cosa se va a hacer con que tipo de inst
    // -----------------------------
    always_comb begin
        // Valores por defecto
        mem_phase      = 1'b0;
        memwrite       = 1'b0;
        regwrite       = 1'b0;
        auipc_flag     = 1'b0;
        imm_flag       = 1'b0;
        jump_flag      = 1'b0;
        is_csrw_instr  = 1'b0;
        is_mret_instr  = 1'b0;

        case (opcode)
            // R-type ALU (ADD, SUB, AND, OR, ...)
            OPCODE_OP: begin
                regwrite = 1'b1;
                // no immediate, no jump
            end

            // I-type ALU (ADDI, ANDI, ORI, ...)
            OPCODE_OP_IMM: begin
                regwrite = 1'b1;
                imm_flag = 1'b1;
            end

            // LUI
            OPCODE_LUI: begin
                regwrite   = 1'b1;
                imm_flag   = 1'b1; // b = immediate U-type
            end

            // AUIPC
            OPCODE_AUIPC: begin
                regwrite   = 1'b1;
                imm_flag   = 1'b1;
                auipc_flag = 1'b1; // a = pc
            end

            // LOAD (LW)
            OPCODE_LOAD: begin
                mem_phase  = 1'b1;
                regwrite   = 1'b1;
                imm_flag   = 1'b1; // dirección = rs1 + imm
            end

            // STORE (SW)
            OPCODE_STORE: begin
                mem_phase  = 1'b1;
                memwrite   = 1'b1;
                imm_flag   = 1'b1; // dirección = rs1 + imm
            end

            // Branches (BEQ, BNE, ...)
            OPCODE_BRANCH: begin
                // Comparación rs1/rs2 en ALU, sin inmediato en b
                jump_flag  = 1'b1; // salto condicional
            end

            // JAL
            OPCODE_JAL: begin
                regwrite   = 1'b1; // R[rd] = pc + 4
                jump_flag  = 1'b1; // salto indirecto (pc + imm)
                imm_flag   = 1'b1;
            end

            // JALR
            OPCODE_JALR: begin
                regwrite   = 1'b1;
                imm_flag   = 1'b1; // pc = rs1 + imm (ALU usa b=imm)
                jump_flag  = 1'b1; // salto directo
            end

            // CSRR / CSRW / MRET (SYSTEM / Y-Type)
            OPCODE_SYSTEM: begin
                case (funct3)
                    3'b001: begin
                        // CSRW csr, rs1
                        is_csrw_instr = 1'b1;
                        // no regwrite
                    end
                    3'b010: begin
                        // CSRR rd, csr
                        regwrite = 1'b1;
                    end
                    3'b000: begin
                        // Posible MRET
                        // MRET = 0x30200073 → funct12 = 0x302 = 0011_0000_0010
                        if (funct12 == 12'b0011_0000_0010) begin
                            is_mret_instr = 1'b1;
                        end
                    end
                    default: begin
                        // otras SYSTEM no se implementan
                    end
                endcase
            end

            default: begin
                regwrite = 1'b1;
            end
        endcase
    end

    // Empaquetado de control_flags
    assign control_flags = {
        jump_flag,   // [5]
        imm_flag,    // [4]
        auipc_flag,  // [3]
        regwrite,    // [2]
        memwrite,    // [1]
        mem_phase    // [0]
    };

    // -----------------------------
    // REGISTRO DE ESTADO
    // -----------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_RST;
        end else begin
            state <= next_state;
        end
    end

    // -----------------------------
    // LÓGICA DE SALIDA + NEXT STATE
    // -----------------------------
    always_comb begin
        // Valores por defecto de salidas
        wbflag      = 1'b0;
        memflag     = 1'b0;
        pcflag      = 1'b0;
        fetchflag   = 1'b0;
        mem_ce      = 1'b1;   // low-active → 1 = inactivo
        jump_to_isr = 1'b0;
        mret        = 1'b0;
        csr_write   = 1'b0;

        // Por defecto nos quedamos en el mismo estado
        next_state  = state;

        case (state)
            // -------------------------
            // RST: estado inicial
            // -------------------------
            ST_RST: begin
                // Tras reset, empezamos el primer fetch
                next_state = ST_FE_A;
            end

            // -------------------------
            // FE_A: pedir instrucción
            // -------------------------
            ST_FE_A: begin
                // Lanzamos acceso a memoria de instrucciones
                mem_ce = 1'b0;   // CE activo (bajo)

                // Excepciones de PC / acceso
                if (pc_misaligned || load_access_fault) begin
                    next_state = ST_INTR;
                end else if (mem_busy) begin
                    // Memoria ha aceptado la operación → esperamos a que termine
                    next_state = ST_FE;
                end else begin
                    // Aún no se ha puesto busy → seguimos aquí manteniendo mem_ce=0
                    next_state = ST_FE_A;
                end
            end

            // -------------------------
            // FE: esperando fin de fetch
            // -------------------------
            ST_FE: begin
                mem_ce = 1'b0;   // CE activo (bajo)
                // Cuando mem_valid=1, la CPU debe capturar iword
                fetchflag = mem_valid;

                // Salimos de FE cuando la memoria deja de estar ocupada
                if (!mem_busy) begin
                    next_state = ST_ID;
                end else begin
                    next_state = ST_FE;
                end
            end

            // -------------------------
            // ID: decodificación
            // -------------------------
            ST_ID: begin

                // Solo un ciclo: regs leen rs1/rs2, imm ya está calculado
                next_state = ST_EX;
            end

            // -------------------------
            // EX: ejecución en ALU
            // -------------------------
            ST_EX: begin
                if (illegal_instruction) begin
                    // Excepción de instrucción ilegal
                    next_state = ST_INTR;
                end else if (mem_phase) begin
                    // Instrucciones LW/SW → fase de memoria
                    next_state = ST_MEM_A;
                end else begin
                    // R-type, I-type, LUI, AUIPC, JAL, JALR, CSRR, CSRW, MRET, branches sin acceso a MEM
                    next_state = ST_WB;
                end
            end

            // -------------------------
            // MEM_A: lanzar acceso a datos
            // -------------------------
            ST_MEM_A: begin
                memflag = 1'b1;  // estamos en fase de memoria de datos
                mem_ce  = 1'b0;  // lanzamos acceso (load/store)

                if (load_access_fault) begin
                    // fallo de acceso → excepción
                    next_state = ST_INTR;
                end else if (mem_busy) begin
                    // memoria ha aceptado la operación
                    next_state = ST_MEM;
                end else begin
                    // aún no ha entrado en busy → mantenemos petición
                    next_state = ST_MEM_A;
                end
            end

            // -------------------------
            // MEM: esperando fin de acceso
            // -------------------------
            ST_MEM: begin
                memflag = 1'b1;  // seguimos en fase de memoria de datos
                mem_ce  = 1'b0;  // CE liberado, operación en curso

                if (!mem_busy) begin
                    // acceso de datos terminado
                    next_state = ST_WB;
                end else begin
                    next_state = ST_MEM;
                end
            end

            // -------------------------
            // WB: writeback + actualización PC
            // -------------------------
            ST_WB: begin
                pcflag = 1'b1;          // PC se actualiza siempre en WB
                wbflag = regwrite;      // solo escribir registros si regwrite=1

                // Señales especiales para CSRs/MRET
                if (is_mret_instr) begin
                    mret = 1'b1;
                end
                if (is_csrw_instr) begin
                    csr_write = 1'b1;
                end

                // Si hay interrupción pendiente, pasamos a INTR
                if (interrupt_pending) begin
                    next_state = ST_INTR;
                end else begin
                    // Siguiente instrucción: volvemos a FE_A
                    next_state = ST_FE_A;
                end
            end

            // -------------------------
            // INTR: entrar en ISR
            // -------------------------
            ST_INTR: begin
                // Señal para PC Unit + CSR Unit de "entrar en ISR"
                jump_to_isr = 1'b1;
                // Tras señalar la entrada a la ISR, volvemos al flujo normal de fetch
                next_state  = ST_FE_A;
            end

            default: begin
                // fallback de seguridad
                next_state = ST_RST;
            end
        endcase
    end

endmodule
