module csr (
    input logic clk,
    input logic reset,

    // Interrupt signals
    input  logic       intr_timer,
    input  logic       intr_ext,
    input  logic [2:0] exceptions,
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
//addresses:
localparam [11:0] addr_mstatus  = 12'h300; 
localparam [11:0] addr_mcause   = 12'h342; 
localparam [11:0] addr_mie      = 12'h304; //machine interrupt enable
localparam [11:0] addr_mip      = 12'h344; //machine interrupt pending
localparam [11:0] addr_mtvec    = 12'h305; //machine trap-vector base-addres
localparam [11:0] addr_mepc     = 12'h341; //machine exception program counter

logic [31:0] mstatus = 32'b0, mcause = 32'b0, mie = 32'b0, mip = 32'b0, mtvec = 32'b0, mepc = 32'b0;
always_comb begin //data_out is always set to the register specified by addr
    case(addr)
        addr_mstatus: data_out = mstatus;
        addr_mcause: data_out = mcause;
        addr_mie: data_out = mie;
        addr_mip: data_out = mip;
        addr_mtvec: data_out = mtvec;
        addr_mepc: data_out = mepc;
        default: begin
            data_out = 32'b0;
        end
    endcase

    interrupt_pending = (mip[11] && mie[11] || mip[7] && mie[7]) && mstatus[3];

    isr_target = {mtvec[31:2], 2'b0};
    if(mcause[31]) isr_target += (mcause << 2);

    isr_return = mepc;
end

always_ff @( posedge clk ) begin 
    if(reset) begin 
        mstatus <= 32'b0; mcause <= 32'b0; mie <= 32'b0; mip <= 32'b0; mtvec <= 32'b0; mepc <= 32'b0;
    end else begin 
        if(write_en) begin 
            case(addr)
                addr_mstatus: mstatus <= data_in;
                addr_mcause: mcause <= data_in;
                addr_mie: mie <= data_in;
                addr_mip: mip <= data_in;
                addr_mtvec: mtvec <= data_in;
                addr_mepc: mepc <= data_in;
                default: begin
                end
            endcase
        end else begin 
            if(intr_ext) mip[11] <= 1'b1;
            mip[7] <= intr_timer;

            if(enter_isr) begin
                mstatus[3] <= 1'b0; //disable interrupts
                if(mip[11]) mip[11] <= 1'b0;
                mepc <= pc;
            end else if(mret) begin //return from isr
                mstatus[3] <= 1'b1; //enable interrupts
            end

            if(mstatus[3]) begin
                if(mip[11] && mie[11]) begin            //in mie: MEIE, machine external interrupt enable
                    mcause <= {1'b1, 27'b0, 4'b1011};   //d'11
                end else if(mip[7] && mie[7]) begin     //in mie: MTIE, machine timer interrupt enable
                    mcause <= {1'b1, 28'b0, 3'b111};    //d'7
                end else if(exceptions[1]) begin        //illegal instruction
                    mcause <= {30'b0, 2'b10};           //d'2
                end else if(exceptions[0]) begin        //pc misaligned
                    mcause <= 32'b0;                    //d'0
                end else if(exceptions[2]) begin        //load access fault
                    mcause <= {29'b0, 3'b101};          //d'5
                end
            end
        end
    end
end

endmodule
