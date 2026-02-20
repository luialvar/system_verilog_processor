module control (
    input logic        clk,
    input logic        reset,
    input logic [31:0] iword,
    input logic        mem_busy,
    input logic        mem_valid,
    input logic        alu_busy,

    output logic [31:0] immediate,
    output logic [ 5:0] control_flags, //[jump_flag, imm_flag, auipc, regwrite, memwrite, mem_phase]
    output logic        wbflag,
    output logic        memflag,  // I assume this is mem_flag (cpu_manual.pdf)
    output logic        pcflag,   // I assume this is pc_flag (cpu_manual.pdf)
    output logic        fetchflag,
    output logic        mem_ce,
    output logic        reset_alu,

    input logic interrupt_pending,
    input logic [2:0] exceptions, // [2:load access fault, 1: illegal instruction, 0: misaligned pc]
    output logic jump_to_isr,
    output logic mret,
    output logic csr_write,

    output logic ireadflag,  // added, iread indicates if cpu is currently accessing the memory to fetch an instruction
    output logic ntlflag
);

`include "../constants.sv"
`include "../ntlconstants.sv"


logic muldiv;
logic ntl_active_d;
logic ntl_active_q = 0;
logic ntl_pending_d;
logic ntl_pending_q = 0;

logic is_ntl_instruction;

enum {RST,FE_A,FE,ID,EX,MEM_A,MEM,WB,INTR} state_d, state_q;

imm_gen imm (.iword(iword), .immediate(immediate));

assign ntlflag = ntl_active_q;

always_comb begin
    is_ntl_instruction = 1'b0;
    if (iword[6:0] == OP_RTYPE && iword[14:12] == FUNCT3_ADD && iword[11:7] == X0 && iword[19:15] == X0) begin
        case (iword[24:20])
            X2, X3, X4, X5: is_ntl_instruction = 1'b1;
            default: is_ntl_instruction = 1'b0;
        endcase
    end
end

always_ff @( posedge clk ) begin
    if(reset) begin
        state_q <= RST;
        ntl_active_q <= 1'b0;
        ntl_pending_q <= 1'b0;
    end else begin
        state_q <= state_d;
        ntl_active_q <= ntl_active_d;
        ntl_pending_q <= ntl_pending_d;
    end
end

always_comb begin
    muldiv = 0;
    if (iword[6:0] == OP_RTYPE & iword[31:25] == 7'b0000001) muldiv = 1;
    case (iword[6:0])
        OP_LW, OP_SW    :   control_flags[0] = 1;
        default         :   control_flags[0] = 0;
    endcase
    case (iword[6:0])
        OP_SW       :   control_flags[1] = 1;
        default     :   control_flags[1] = 0;
    endcase
    case (iword[6:0])
        OP_AUIPC    :   control_flags[3] = 1;
        default     :   control_flags[3] = 0;
    endcase
    case (iword[6:0])
        OP_LUI, OP_ITYPE, OP_SW, OP_LW, OP_AUIPC, OP_JAL, OP_JALR   :   control_flags[4] = 1;
        default     :   control_flags[4] = 0;
    endcase
    case (iword[6:0])
        OP_JAL, OP_JALR, OP_BRANCH  :   control_flags[5] = 1;
        default :   control_flags[5] = 0;
    endcase
    case (iword[6:0])
        OP_BRANCH, OP_SW   :   control_flags[2] = 0;
        OP_CSR  :
            begin
                if (iword[14:12] == 3'b010) control_flags[2] = 1;
                else control_flags[2] = 0;
            end
        default :   control_flags[2] = 1;
    endcase
end
always_comb begin
    mem_ce = 1;
    wbflag = 0;
    memflag = 0;
    pcflag = 0;
    fetchflag = 0;
    mret = 0;
    csr_write = 0;
    jump_to_isr = 0;
    reset_alu = 0;
    ireadflag = 1'b0;
    ntl_active_d = ntl_active_q;
    ntl_pending_d = ntl_pending_q;
    case (state_q)
        RST     :   state_d = FE_A;
        FE_A    :
            begin
                mem_ce = 0;
                if (exceptions[0] | exceptions[2]) begin
                    state_d = INTR;
                end
                else if (mem_busy) begin
                    state_d = FE;
                end
                else begin
                    state_d = state_q;
                end
                ireadflag = 1'b1;
            end
        FE      :
            begin
                if (mem_busy == 0) begin
                    if (mem_valid) begin
                        fetchflag = 1;
                    end
                    state_d = ID;
                end
                else begin
                    state_d = state_q;
                end
                mem_ce = 0;
                reset_alu = 1;
                ireadflag = 1'b1;
            end
        ID      :   
            begin
                state_d = EX;
                if (is_ntl_instruction) begin
                    ntl_active_d = 1'b1;
                    ntl_pending_d = 1'b1;
                end else begin
                    if (ntl_pending_q)
                        ntl_pending_d = 1'b0;
                    else 
                        ntl_active_d = 1'b0;
                end
            end
        EX      :
            begin
                reset_alu = 0;
                if (exceptions[1]) state_d = INTR;
                else if (alu_busy) state_d = state_q;
                else if (control_flags[0]) state_d = MEM_A;
                else state_d = WB;
            end
        MEM_A   :
            begin
                mem_ce = 0;
                memflag = 1;
                if (exceptions[2]) state_d = INTR;
                else if (mem_busy) begin
                    state_d = MEM;
                end
                else begin
                    state_d = state_q;
                end
            end
        MEM     :
            begin
                mem_ce = 0;
                memflag = 1;
                if (mem_busy == 0) state_d = WB;
                else state_d = state_q;
            end
        WB      :
            begin
                pcflag = 1;
                if (interrupt_pending) state_d = INTR;
                else state_d = FE_A;
                if (control_flags[2] | muldiv) wbflag = 1;
                else if (iword[6:0] == OP_CSR & iword[14:12] == 001) csr_write = 1;
                else if (iword[6:0] == OP_CSR & iword[14:12] == 000) mret = 1;
            end
        INTR    :
            begin
                state_d = FE_A;
                jump_to_isr = 1;
                ntl_active_d = 1'b0;
                ntl_pending_d = 1'b0;
            end
        default :   
            begin
                state_d = RST;
            end
    endcase
    end


endmodule
