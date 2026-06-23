module csr (
    input  logic clk,
    input  logic reset,

    // Interrupt signals
    input  logic       intr_timer,
    input  logic       intr_ext,
    input  logic [2:0] exceptions,   // [2]=load fault, [1]=illegal, [0]=pc misaligned
    input  logic       mret,
    input  logic       enter_isr,
    output logic       interrupt_pending,

    // Signals for reading/writing CSRs
    input  logic [31:0] data_in,
    input  logic [11:0] addr,
    input  logic        write_en,
    output logic [31:0] data_out,

    input  logic [15:0] pc,
    output logic [15:0] isr_return,
    output logic [15:0] isr_target
);

    // Direcciones CSRs
    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MIP     = 12'h344;

    // Registros físicos
    logic [31:0] mstatus, mie, mtvec, mepc, mcause, mip;

    // isr_return = mepc (16 bits)
    assign isr_return = mepc[15:0];

    // -------------------------
    // Pendings y enables mínimos
    // -------------------------
    logic ext_pending;
    logic timer_pending;
    logic ext_fire;
    logic timer_fire;

//checks if there is one
    assign timer_pending = intr_timer;
    assign ext_pending   = mip[11] | intr_ext; // latch + input (para no perder pulsos)

//checks if it can be now executed
    assign ext_fire   = mstatus[3] && mie[11] && ext_pending;
    assign timer_fire = mstatus[3] && mie[7]  && timer_pending;

    // interrupt_pending: SOLO interrupts habilitadas (no exceptions)
    assign interrupt_pending = ext_fire || timer_fire;

    // -------------------------
    // Selección de causa (prioridad) -> mcause “actual”
    // -------------------------
    logic        trap_valid;
    logic [31:0] trap_mcause; //sirve porque si usara mcause al ser registro solo podria cambiar en ciclos

    always @* begin
        trap_valid  = 1'b0;
        trap_mcause = mcause; // por defecto, lo latcheado

        // Prioridad (según enunciado):
        // External IRQ > Timer IRQ > Illegal > PC misaligned > Load fault
        if (ext_fire) begin
            trap_valid  = 1'b1;
            trap_mcause = {1'b1, 27'b0, 4'd11}; // interrupt, cause=11
        end else if (timer_fire) begin
            trap_valid  = 1'b1;
            trap_mcause = {1'b1, 27'b0, 4'd7};  // interrupt, cause=7
        end else if (exceptions[1]) begin
            trap_valid  = 1'b1;
            trap_mcause = {1'b0, 27'b0, 4'd2};  // exception, cause=2
        end else if (exceptions[0]) begin
            trap_valid  = 1'b1;
            trap_mcause = {1'b0, 27'b0, 4'd0};  // exception, cause=0
        end else if (exceptions[2]) begin
            trap_valid  = 1'b1;
            trap_mcause = {1'b0, 27'b0, 4'd5};  // exception, cause=5
        end
    end

    // -------------------------
    // isr_target: mtvec base, y si interrupt -> base + 4*cause
    // -------------------------
    always @* begin
        logic [31:0] base;
        logic [31:0] target;
        logic [31:0] use_mcause;

        // si hay trap pendiente, úsalo; si no, usa el mcause latcheado
        use_mcause = trap_valid ? trap_mcause : mcause;

        base = {mtvec[31:2], 2'b00};

        if (use_mcause[31] == 1'b0) begin
            target = base; // exception
        end else begin
            target = base + ({28'b0, use_mcause[3:0]} << 2); // interrupt: base+4*cause
        end

        isr_target = target[15:0];
    end

    // -------------------------
    // SECUENCIAL: reset + CSRW + HW updates
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mstatus <= 32'b0;
            mie     <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
            mip     <= 32'b0;
        end else begin
            // 1) CSRW: escribe CSR[addr] = data_in
            if (write_en) begin
                case (addr)
                    CSR_MSTATUS: mstatus <= data_in;
                    CSR_MIE    : mie     <= data_in;
                    CSR_MTVEC  : mtvec   <= data_in;
                    CSR_MEPC   : mepc    <= data_in;
                    CSR_MCAUSE : mcause  <= data_in;
                    CSR_MIP    : mip     <= data_in;   // HW pisará 11 y 7 luego
                    default    : /* nada */;
                endcase
            end

            // 2) Al entrar a ISR: deshabilita ints y guarda PC en mepc
            if (enter_isr) begin
                mstatus[3] <= 1'b0;
                mepc       <= {16'b0, pc};

                // latch de mcause al entrar
                if (trap_valid) mcause <= trap_mcause;

                // si es ISR externa, limpiar pending mip[11]
                if (trap_valid && trap_mcause[31] && (trap_mcause[3:0] == 4'd11))
                    mip[11] <= 1'b0;
            end else if (mret) begin
                // 3) Al volver con MRET: re-habilita ints
                mstatus[3] <= 1'b1;
            end

            // 4) Latch de external pending (puede ser pulso corto)
            if (intr_ext) mip[11] <= 1'b1;

            // 5) mip[7] refleja timer (hardwired/registrado)
            mip[7] <= intr_timer;
        end
    end

    // -------------------------
    // Lectura CSRR (data_out)
    // -------------------------
    always @* begin
        case (addr)
            CSR_MSTATUS: data_out = mstatus;
            CSR_MIE    : data_out = mie;
            CSR_MTVEC  : data_out = mtvec;
            CSR_MEPC   : data_out = mepc;

            // (muchos Tbs agradecen ver la causa “actual” si hay una pendiente)
            CSR_MCAUSE : data_out = trap_valid ? trap_mcause : mcause;

            CSR_MIP: begin
                data_out     = mip;
                data_out[7]  = intr_timer;         // timer pending “real”
                data_out[11] = mip[11] | intr_ext; // external pending “real”
            end

            default: data_out = 32'b0;
        endcase
    end

endmodule
