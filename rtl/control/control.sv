module control (
    input logic        clk,
    input logic        reset,
    input logic [31:0] iword,
    input logic        mem_busy,
    input logic        mem_valid,

    output logic [31:0] immediate,
    output logic [ 5:0] control_flags, //[jump_flag, imm_flag, auipc, regwrite, memwrite, mem_phase]
    output logic        wbflag,
    output logic        memflag,  // I assume this is mem_flag (cpu_manual.pdf)
    output logic        pcflag,   // I assume this is pc_flag (cpu_manual.pdf)
    output logic        fetchflag,
    output logic        mem_ce,

    input logic interrupt_pending,
    input logic [2:0] exceptions, // [2:load access fault, 1: illegal instruction, 0: misaligned pc]
    output logic jump_to_isr,
    output logic mret,
    output logic csr_write,

    output logic ireadflag  // added, iread indicates if cpu is currently accessing the memory to fetch an instruction
);

`include "../constants.sv"

imm_gen imm (.iword(iword), .immediate(immediate));

//RST=0, FE_A=1, FE=2, ID=3, EX=4, MEM_A=5, MEM=6, WB=7, INTR=8
enum {RST=0, FE_A, FE, ID, EX, MEM_A, MEM, WB, INTR} state_d, state_q;

always_ff @( posedge clk ) begin
    if(reset) 
        state_q <= RST;
    else
        state_q <= state_d;
end


//control_flags:
always_comb begin
    case(iword[6:0]) //LW, SW, mem_phase flag, is mem_phase needed for this instruction
        OP_LW, OP_SW: control_flags[0] = 1'b1;
        default: control_flags[0] = 1'b0;
    endcase
    
    control_flags[1] = iword[6:0] == OP_SW; //SW, memwrite flag

    case(iword[6:0]) // regwrite 
        OP_SW, OP_BRANCH: control_flags[2] = 1'b0; 
        OP_CSR: control_flags[2] = iword[14:12] == FUNCT3_CSRR; //only CSRR reads from CSR and writes it to R[rd], not CSRW or MRET
        
        //OP_RTYPE, OP_ITYPE, OP_LUI, OP_AUIPC, OP_LW, OP_JAL, OP_JALR, ILLEGAL:
        default: control_flags[2] = 1'b1;
    endcase

    control_flags[3] = iword[6:0] == OP_AUIPC; //AUIPC, auipc flag
 
    case(iword[6:0]) // imm_flag  
        OP_ITYPE, OP_LUI, OP_AUIPC, OP_LW, OP_SW, OP_JAL, OP_JALR: control_flags[4] = 1'b1;
        default: control_flags[4] = 1'b0; //all other instructions don't require imm value
    endcase

    case(iword[6:0]) // jump_flag
        OP_BRANCH, OP_JAL, OP_JALR: control_flags[5] = 1'b1;
        default: control_flags[5] = 1'b0;
    endcase
end

//determine next state, state dependent outputs:
always_comb begin
    mem_ce = 1'b1;
    {fetchflag, memflag, pcflag, fetchflag, jump_to_isr, mret, csr_write, wbflag, ireadflag} = 9'b0;
    case(state_q)
        RST: begin
            state_d = FE_A;
        end

        FE_A: begin
            if(exceptions[0] | exceptions[2]) begin //pc_misaligned, load_access_fault
                state_d = INTR;
            end else begin
                if(mem_busy) state_d = FE;//memory is "working" on retrieving iword
                else state_d = FE_A;
            end
            mem_ce = 1'b0;
            ireadflag = 1'b1;
        end

        FE: begin
            if(mem_busy) state_d = FE; //stay until memory finishes (mem_busy low)
            else state_d = ID;
            fetchflag = mem_valid;
            mem_ce = 1'b0;
            ireadflag = 1'b1;
        end

        ID: begin
            state_d = EX;
        end

        EX: begin
            if(exceptions[1]) begin //illegal instruction detected by alu
                state_d = INTR;
            end else begin    
                if(control_flags[0]) state_d = MEM_A;      //mem_phase flag
                else state_d = WB;
            end
        end

        MEM_A: begin
            if(exceptions[2]) begin //load_access_fault
                state_d = INTR;
            end else begin
                if(mem_busy) state_d = MEM; //memory is "working" on retrieving iword
                else state_d = MEM_A;    
            end
            mem_ce = 1'b0;
            memflag = 1'b1;  //load or store data in memory
        end

        MEM: begin
            if(mem_busy) state_d = MEM; //stay until memory finishes (mem_busy low)
            else state_d = WB;
            mem_ce = 1'b0;
            memflag = 1'b1;
        end

        WB: begin
            if(interrupt_pending) state_d = INTR;
            else state_d = FE_A;
            wbflag = control_flags[2]; //regwrite flag
            pcflag = 1'b1;
            //OP_MRET and OP_CSR are the same: 7'b1110011
            if(iword[6:0] == OP_MRET && iword[14:12] == FUNCT3_MRET) mret = 1'b1;
            if(iword[6:0] == OP_CSR && iword[14:12] == FUNCT3_CSRW) csr_write = 1'b1;
        end

        INTR: begin
            state_d = FE_A;
            jump_to_isr = 1'b1;
        end

        default: begin
            state_d = RST;
        end        
    endcase
end

endmodule
