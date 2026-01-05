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
    logic invreset;
    logic mem_ce;
    logic [31:0] addr;              //c
    logic [31:0] mem_data_in;
    logic memwrite;                 //f
    logic [31:0] iword;
    logic fetchflag;
    logic [31:0] mem_data_out;
    logic busy;
    logic valid;
    logic intr_timer;
    logic mret;
    logic jump_to_isr;
    logic load_access_fault;
    logic [31:0] rd;                //rd
    logic [31:0] rs1;
    logic [31:0] rs2;
    logic pcflag;
    logic [1:0] jump;               //d
    logic [15:0] imm;               //e
    logic [15:0] isr_target;
    logic [15:0] isr_return;
    logic [15:0] pc_new;
    logic pc_misaligned;
    logic illegal_instruction;
    logic [16:0] instruction;
    logic [31:0] a;                 //a
    logic [31:0] b;                 //b
    logic [2:0] exceptions;
    logic [31:0] data_out;
    logic interrupt_pending;
    logic csr_write;
    logic memflag;
    logic wbflag;
    logic [5:0] control_flags;
    logic [31:0] immediate;
    logic [31:0] rd_alu;
    logic [31:0] rd_muxed;
    


    memory memory(  .clk(clk),
                    .reset(invreset),
                    .ce(mem_ce),
                    .addr(addr),
                    .datain(rs2),
                    .memwrite(memwrite),
                    .so(so),
                    .sda(sda),
                    .gpio_in(gpio_in),
                    .dataout(mem_data_out),
                    .busy(busy),
                    .valid(valid),
                    .si(si),
                    .sclk(sclk),
                    .sram_ce(sram_ce),
                    .scl(scl),
                    .tx(tx),
                    .gpio_out(gpio_out),
                    .intr_timer(intr_timer),
                    .load_access_fault(load_access_fault));

    pc_unit pc_unit( .clk(clk),
                .reset(invreset),
                .pcflag(pcflag),
                .jump(jump),
                .imm(imm),
                .isr_target(isr_target),
                .isr_return(isr_return),
                .interrupt(jump_to_isr),
                .pc_new(pc_new),
                .pc_misaligned(pc_misaligned));

    regs regs(  .clk(clk),
                .reset(invreset),
                .regwrite(wbflag),
                .rs1adr(iword[19:15]),
                .rs2adr(iword[24:20]),
                .rdadr(iword[11:7]),
                .rd(rd_muxed),
                .rs1(rs1),
                .rs2(rs2));

    alu alu(    .a(a),
                .b(b),
                .instruction(instruction),
                .rd(rd),
                .illegal_instruction(illegal_instruction));

    csr csr(    .clk(clk),
                .reset(invreset),
                .exceptions(exceptions),
                .intr_timer(intr_timer),
                .intr_ext(intr_ext),
                .mret(mret),
                .enter_isr(jump_to_isr),
                .data_in(rs1),
                .addr(iword[31:20]),
                .write_en(csr_write),
                .pc(pc_new),
                .interrupt_pending(interrupt_pending),
                .data_out(data_out),
                .isr_return(isr_return),
                .isr_target(isr_target));

    control control(    .clk(clk),
                        .reset(invreset),
                        .iword(iword),
                        .interrupt_pending(interrupt_pending),
                        .exceptions(exceptions),
                        .mem_valid(valid),
                        .mem_busy(busy),
                        .fetchflag(fetchflag),
                        .pcflag(pcflag),
                        .mem_ce(mem_ce),
                        .memflag(memflag),
                        .wbflag(wbflag),
                        .control_flags(control_flags),
                        .immediate(immediate),
                        .jump_to_isr(jump_to_isr),
                        .mret(mret),
                        .csr_write(csr_write));
    

    always_ff @(posedge clk) begin
        if(invreset) begin
            iword <= 32'b0;
        end
        else begin
            if (fetchflag) begin
                iword <= mem_data_out;
            end
            rd_alu <= rd;
        end
    end

    always_comb begin
        //f & c multiplexer
        if (memflag) begin
            memwrite = control_flags[1];
            addr = rd_alu;
        end
        else begin
            memwrite = 0;
            addr = {16'b0, pc_new};
        end
        //e multiplexer
        if (iword[6:0] == 7'b1100111)begin
            imm = rd_alu[15:0];
        end
        else imm = immediate;
        //d multiplexer
        if (control_flags[5])begin
            jump = rd[17:16];
        end
        else begin
            if (iword[6:0] == 7'b1110011 & iword[14:12] == 3'b000) begin
                jump = 2'b11;
            end
            else begin
                jump = 2'b10;
            end
        end
        //a & b multiplexer
        if (control_flags[3]) begin
            a = {16'b0, pc_new};
        end
        else begin
            a = rs1;
        end
        if (control_flags[4]) b = immediate;
        else begin
            b = rs2;
        end
        //rd multiplexer
        if (iword[6:0] == 7'b1101111 | iword[6:0] == 7'b1100111) begin
            rd_muxed = pc_new + 4;
        end
        else if (control_flags[0]) begin
            rd_muxed = mem_data_out;
        end
        else if (iword[6:0] == 7'b1110011 & iword[14:12] == 3'b010) begin
            rd_muxed = data_out;
        end
        else begin
            rd_muxed = rd_alu;
        end
    end

    assign invreset = ~reset;
    assign instruction = {iword[31:25], iword[14:12], iword[6:0]};
    assign exceptions = {load_access_fault, illegal_instruction, pc_misaligned};

endmodule  // cpu
