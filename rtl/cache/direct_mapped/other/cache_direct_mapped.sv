/*
* module replaces spi_master
* address: [23 .tag. 9|8 .index. 5|4 .offset. 2|1 .bytes. 0]
*          [   15     |     4     |     3      |     2     ]
*
* cache line: [272 .valid. 272|271 .tag. 256|255 .data. 0]
*/

module cache_direct_mapped (
    input logic clk,
    input logic reset, // reset should be held high if not in use

    input  logic so,
    output logic si,
    output logic sclk,  // clk exported to the SRAM
    output logic ce,    // ce signal to enable the SRAM (active high on pico ice, low on its own)

    input  logic [23:0] addr,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,

    input  logic write,
    output logic busy,
    output logic valid,

    input logic iread   //instruction-word load, only caching iwords
);

localparam index_end = 8;
localparam index_start = 5;
localparam offset_end = 4;
localparam offset_start = 2;

//typedef logic [31:0] data [8];
//            0      1     2          3     4           5           6      7      8
typedef enum {RESET, COMP, LOAD_WAIT, LOAD, LOAD_RESET, WRITE_WAIT, WRITE, VALID, FAULT} states;

logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;

logic [31:0] i_cache[128];//[16][8];
logic [15:0] i_control[16];

logic [15:0] current_control;

states state;

logic [2:0] count; //variable for loading 8 words

spi_master sram_master (
     .clk(clk),
     .reset(sram_reset),
     .si(si),
     .so(so),
     .sclk(sclk),
     .ce(ce),
     .addr(sram_addr),
     .data_in(data_in),
     .data_out(sram_data_out),
     .write(write),   // write signal just passed to sram
     .busy(sram_busy),
     .valid(sram_valid)
 );

// state transition
always_ff @( posedge clk ) begin
    if(reset) begin
        state <= RESET;
        count <= 3'b0;
    end else begin
        case(state)
            RESET: begin
                if(write) state <= WRITE_WAIT;
                else state <= COMP;
            end
            COMP: begin
                //entry valid    and    tag         matches address tag
                if(current_control[15] & current_control[14:0] == addr[23:9]) begin
                    state <= VALID;
                end else begin
                    state <= LOAD_WAIT;
                    count <= 3'b111;
                end
            end
            LOAD_WAIT: begin
                //load 8 consecutive words, beginning by address addr (ignoring offset)
                if(sram_busy) state <= LOAD;
                else state <= LOAD_WAIT;  //wait for sram to respond
            end
            LOAD: begin
                if(sram_busy) state <= LOAD;
                else state <= LOAD_RESET;
            end
            LOAD_RESET: begin
                if(count == 0) begin
                    if(sram_valid) begin
                        state <= VALID;
                    end else begin
                        state <= FAULT;
                    end
                end
                else state <= LOAD_WAIT;

                count <= count - 1;

                i_cache[{addr[8:5], count}] <= sram_data_out;
                i_control[addr[index_end:index_start]] <= {1'b1, addr[23:9]};   //set valid and tag
            end
            WRITE_WAIT: begin //missing check for overwrite of i_cached data
                if(sram_busy) begin
                    state <= WRITE;

                    //write word to cache if hit
                    //entry valid    and    tag         matches address tag
                    if(current_control[15] & current_control[14:0] == addr[23:9]) begin
                        i_cache[addr[index_end:offset_start]] <= data_in;
                    end
                end else begin
                    state <= WRITE_WAIT;
                end
            end
            WRITE: begin
                if(sram_busy) state <= WRITE;
                else state <= VALID;
            end
            VALID: begin
                state <= VALID;
            end
            FAULT: begin
                state <= FAULT;
            end
            default: state <= RESET;
        endcase
    end
end

always_comb begin
    busy = 1'b1;
    valid = 1'b0;
    sram_reset = 1'b1;
    case(state)
        RESET: begin
            busy = 1'b0;
        end
        COMP: begin
        end
        LOAD_WAIT: begin
            sram_reset = 1'b0; //enable sram, reset high if sram not in use
        end
        LOAD: begin
            sram_reset = 1'b0;
        end
        LOAD_RESET: begin
            //reset sram here to initiate next load
        end
        WRITE_WAIT: begin
            sram_reset = 1'b0;
        end
        WRITE: begin
            sram_reset = 1'b0;
        end
        VALID: begin
            valid = 1'b1;
            busy = 1'b0;
        end
        FAULT: begin
            busy = 1'b0; //busy and valid low
        end
    endcase
end

always_comb begin
    //current_line = i_cache[addr[8:5]];
    current_control = i_control[addr[index_end:index_start]];
    //current_control = iread ? i_control[addr[index_end:index_start]] : d_control[addr[index_end:index_start]];

    //data_out = reset ? 32'b0 : i_cache[addr[8:5]][addr[4:2]];
    if(reset)
        data_out = 32'b0;
    else if(iread)
        data_out = i_cache[addr[8:2]];
    else
        data_out = sram_data_out;

    sram_addr = iread ? {addr[23:5], count, 2'b0} : addr;
    //sram_addr changes when i_cache loads data on miss
    //if(iread && (state == LOAD || state == LOAD_WAIT))
    //    sram_addr = {addr[31:5], count, 2'b0};
    //else
    //    sram_addr = addr;
end


endmodule