module cpu (
    input logic clk,
    input logic reset, // active low due to pico-ice button
    input logic intr_ext,

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

//reset:
logic inv_reset;
assign inv_reset = ~reset;

//cpu:
logic [31:0] iword;
logic [31:0] rd_alu;
logic [2:0] exceptions;     //i // [2:load access fault; 1: illegal instruction; 0: misaligned pc]

//regs:  
logic [31:0] rd_r;          //i, rd-mux
logic [31:0] rs1;           //o, d
logic [31:0] rs2;           //o, d

//pc_unit:
logic [ 1:0] jump_pc;       //i, d-mux
logic [15:0] imm_pc;        //i, e-mux  
logic [15:0] pc_new;        //o
logic pc_misaligned;        //o

//alu:
logic [31:0] a;             //i, a-mux
logic [31:0] b;             //i, b-mux
logic [16:0] instruction;   //i, driven from iword. Holds only the func7, func3 and opcode part
logic [31:0] rd;            //o, drives register rd_alu
logic illegal_instruction;  //o

//memory:
logic [31:0] mem_addr;      //i, c-mux    
logic        memwrite;      //i, f-mux
logic        busy;          //o
logic        valid;         //o
logic intr_timer;           //o
logic load_access_fault;    //o
logic [31:0] mem_dataout;   //o

//control:
logic [31:0] immediate;     //o
logic [ 5:0] control_flags; //o
logic        wbflag;        //o
logic        memflag;       //o
logic        pcflag;        //o 
logic        fetchflag;     //o
logic        mem_ce;        //o
logic jump_to_isr;          //o
logic mret;                 //o
logic csr_write;            //o
logic ireadflag;            //o added

//csr:
logic interrupt_pending;    //o
logic [31:0] csr_data_out;  //o
logic [15:0] isr_return;    //o
logic [15:0] isr_target;    //o

regs regs (
    .clk(clk), 
    .reset(inv_reset), 
    .regwrite(wbflag),
    .rs1adr(iword[19:15]),
    .rs2adr(iword[24:20]),
    .rdadr(iword[11:7]),
    .rd(rd_r),
    .rs1(rs1),
    .rs2(rs2)
    );

pc_unit pc_unit (
    .clk(clk), 
    .reset(inv_reset),
    .pcflag(pcflag),
    .interrupt(jump_to_isr),
    .jump(jump_pc),         //d-mux
    .imm(imm_pc),           //e-mux
    .isr_target(isr_target),
    .isr_return(isr_return),
    .pc_new(pc_new),
    .pc_misaligned(pc_misaligned)
     );

alu alu (
    .a(a),                  //a-mux
    .b(b),                  //b-mux
    .instruction(instruction),
    .rd(rd),
    .illegal_instruction(illegal_instruction)
    );

//memory_cache memory (
memory_cache_set memory (
    .clk(clk),            
    .reset(inv_reset), 
    .ce(mem_ce),
    .addr(mem_addr),        //c-mux
    .datain(rs2),
    .memwrite(memwrite),    //f-mux
    .dataout(mem_dataout),
    .busy(busy),
    .valid(valid),
    .so(so),
    .si(si),
    .sclk(sclk),
    .sram_ce(sram_ce),
    .scl(scl),
    .sda(sda),
    .tx(tx),
    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .intr_timer(intr_timer),
    .load_access_fault(load_access_fault),
    .iread(ireadflag)
    );
    
control control (
    .clk(clk), 
    .reset(inv_reset), 
    .iword(iword),
    .mem_busy(busy),  //lines mixed up in the diagram?
    .mem_valid(valid),
    .immediate(immediate),
    .control_flags(control_flags),
    .wbflag(wbflag),
    .memflag(memflag),
    .pcflag(pcflag),
    .fetchflag(fetchflag),
    .mem_ce(mem_ce),
    .interrupt_pending(interrupt_pending),
    .exceptions(exceptions),  //exceptions
    .jump_to_isr(jump_to_isr),
    .mret(mret),
    .csr_write(csr_write),
    .ireadflag(ireadflag)
    );

csr csr (
    .clk(clk), 
    .reset(inv_reset), 
    .intr_timer(intr_timer),
    .intr_ext(intr_ext),
    .exceptions(exceptions), //exceptions
    .mret(mret),
    .enter_isr(jump_to_isr),
    .interrupt_pending(interrupt_pending),
    .data_in(rs1),
    .addr(iword[31:20]), //csr part of instruction, csr-reg address
    .write_en(csr_write),
    .data_out(csr_data_out),
    .pc(pc_new),
    .isr_return(isr_return),
    .isr_target(isr_target)
    );

always_ff @( posedge clk ) begin
    if(inv_reset) begin
        iword <= 32'b0;
        rd_alu <= 32'b0;
    end else begin
        if(fetchflag) begin
            iword <= mem_dataout;
        end 
        rd_alu <= rd;
    end
end

assign instruction = {iword[31:25], iword[14:12], iword[6:0]};

assign a = control_flags[3] ? pc_new : rs1;                     //a-mux, auipc_flag
assign b = control_flags[4] ? immediate : rs2;                  //b-mux, imm_flag
assign mem_addr = memflag ? rd_alu : {16'b0, pc_new[15:0]};     //c-mux
always_comb begin                                               //d-mux, controlle mret (11) and control_flags[5], otherwise increment by 4 (10)
    if(control_flags[5]) begin
        jump_pc = rd_alu[17:16];                                //jalr 2'b00, direct 2'b01
    end else begin  
        jump_pc = mret ? 2'b11 : 2'b10;                         //mret 2'b11, jump to isr_return, 2'b10: normal increment
    end
end 
assign imm_pc = (iword[6:0] == 7'b1100111) ? rd_alu[15:0] : immediate;    //e-mux, jalr uses rd_alu, to compute rs1+imm, lsb always set to 0 by alu unit, not sure if this is the correct one
assign memwrite = memflag ? control_flags[1] : 1'b0;            //f-mux


always_comb begin                                               //rd-mux, data to be written to regs
    if(iword[6:0] == 7'b1110011 && iword[14:12] == 3'b010) begin  //if csr_read instruction, store output of csr_data_out in rd_r
        rd_r = csr_data_out;
    end else begin
        case({control_flags[0], control_flags[5]})       //mem_phase,  jump. Only one signal should be 1 at any given time
            2'b10: rd_r = mem_dataout;
            2'b01: begin
                //$display("jump");
                case(iword[6:0])   //only for jal and jalr
                    7'b1101111, 7'b1100111: rd_r = pc_new + 4;
                    default: rd_r = rd_alu; 
                endcase
            end
            default: rd_r = rd_alu;
        endcase
    end
end

assign exceptions = {load_access_fault, illegal_instruction, pc_misaligned};   //i // [2:load access fault; 1: illegal instruction; 0: misaligned pc]

endmodule  // cpu
