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

    logic [31:0] mstatus = 32'b0;
    logic [31:0] mcause = 32'b0;
    logic [31:0] mie = 32'b0;
    logic [31:0] mip = 32'b0;
    logic [31:0] mtvec = 32'b0;
    logic [31:0] mepc = 32'b0;

    always_ff @(posedge clk) begin
        if (reset) begin
            mstatus <= 32'b0;
            mcause <= 32'b0;
            mie <= 32'b0;
            mip <= 32'b0;
            mtvec <= 32'b0;
            mepc <= 32'b0;
        end
        else begin
            if (write_en) begin
                case (addr)
                    12'h300 :   mstatus <= data_in;
                    12'h342 :   mcause <= data_in;
                    12'h304 :   mie <= data_in;
                    12'h344 :   mip <= data_in;
                    12'h305 :   mtvec <= data_in;
                    12'h341 :   mepc <= data_in;
                    default :   mstatus <= mstatus;
                endcase
            end
            else begin
                if (intr_ext) mip[11] <= 1;
                if (enter_isr) begin
                    mstatus[3] <= 0;
                    mip[11] <= 0;
                    mepc <= pc;
                end
                mip[7] <= intr_timer;
                if (mret) mstatus[3] <= 1;
                if (mstatus[3]) begin
                    mcause <= 32'b0;
                    if (mie[11] & mip[11]) begin
                        mcause[31] <= 1;
                        mcause[3:0] <= 4'b1011;
                    end
                    else if (mie[7] & mip[7]) begin
                        mcause[31] <= 1;
                        mcause[2:0] <= 3'b111;
                    end
                    else if (exceptions[1]) mcause[1:0] <= 2'b10;
                    else if (exceptions[0]) mcause[0] <= 0;
                    else if (exceptions[2]) mcause[2:0] <= 3'b101;
                end
            end
        end
    end

    always_comb begin
        interrupt_pending = 0;
        case (addr)
            12'h300 :   data_out = mstatus;
            12'h342 :   data_out = mcause;
            12'h304 :   data_out = mie;
            12'h344 :   data_out = mip;
            12'h305 :   data_out = mtvec;
            12'h341 :   data_out = mepc;
            default :   data_out = 32'b0;
        endcase
        if (mstatus[3] & (mip[7] & mie[7] | mip[11] & mie [11])) interrupt_pending = 1;
        if (mcause[31]) isr_target = {mtvec[31:2], 2'b00} + (mcause << 2);
        else isr_target = {mtvec[31:2], 2'b00};
    end

    assign isr_return = mepc;

endmodule
