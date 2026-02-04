/*
* module replaces spi_master
* address: [23 .tag. 9|8 .index. 5|4 .offset. 2|1 .bytes. 0]
*          [   15     |     4     |     3      |     2     ]
*
* cache line: [272 .valid. 272|271 .tag. 256|255 .data. 0]
*/

module id_cache_direct_mapped (
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

localparam c_end = 15;

//typedef logic [31:0] data [8];
//            0      1           2     3           4            5      6      7
typedef enum {RESET, LOAD_AWAIT, LOAD, LOAD_RESET, WRITE_AWAIT, WRITE, VALID, FAULT} states;

logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;

logic [31:0] i_cache[128];//[16][8];   
logic [15:0] i_control[16];

logic [31:0] d_cache[128];//[16][8];   
logic [15:0] d_control[16];

logic [c_end:0] current_control;

states state;

logic [2:0] count; //variable for loading 8 words

logic unaligned;

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
                if(unaligned) state <= FAULT;
                else if(write) state <= WRITE_AWAIT;
                else begin 
                    // data is cached
                    if(current_control[c_end] & current_control[c_end - 1:0] == addr[23:index_end + 1]) 
                        state <= VALID;
                    //load line
                    else begin
                        state <= LOAD_AWAIT;
                        count <= 3'b111;
                    end                    
                end
            end
            LOAD_AWAIT: begin
                //load 8 consecutive words, beginning by address addr (ignoring offset)
                if(sram_busy) state <= LOAD;
                else state <= LOAD_AWAIT;  //wait for sram to respond
            end
            LOAD: begin
                if(sram_busy) state <= LOAD;
                else begin
                    if(sram_valid) begin
                        state <= LOAD_RESET;

                        if(iread) begin
                            i_cache[{addr[index_end:index_start], count}] <= sram_data_out;
                            i_control[addr[index_end:index_start]] <= {1'b1, addr[23:index_end + 1]};   //set valid and tag
                        end else begin 
                            d_cache[{addr[index_end:index_start], count}] <= sram_data_out;
                            d_control[addr[index_end:index_start]] <= {1'b1, addr[23:index_end + 1]};   //set valid and tag    
                        end
                    end
                    else state <= FAULT;
                end
            end
            LOAD_RESET: begin
                if(count == 0) state <= VALID;
                else begin 
                    state <= LOAD_AWAIT;
                    count <= count - 1;
                end
            end
            WRITE_AWAIT: begin //missing check for overwrite of i_cached data
                if(sram_busy) begin 
                    state <= WRITE;

                    //write word to cache if hit
                    //entry valid    and    tag         matches address tag
                    if(i_control[addr[index_end:index_start]][c_end] & i_control[addr[index_end:index_start]][c_end - 1:0] == addr[23:index_end+1]) begin
                        i_cache[addr[index_end:offset_start]] <= data_in;
                    end
                    if(d_control[addr[index_end:index_start]][c_end] & d_control[addr[index_end:index_start]][c_end - 1:0] == addr[23:index_end+1]) begin
                        d_cache[addr[index_end:offset_start]] <= data_in;
                    end
                end else begin 
                    state <= WRITE_AWAIT;                   
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
    sram_reset = 1'b1; //reset sram on RESET, READ_OUT, VALID, FAULT
    case(state)
        RESET: begin
            //module always busy, saves one state --- eh, not optimal 
            //busy = 1'b0;
        end
        LOAD_AWAIT, LOAD, WRITE_AWAIT, WRITE: begin
            sram_reset = 1'b0; //enable sram, reset high if sram not in use
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

assign unaligned = addr[0] || addr[1];

always_ff @( posedge clk) begin
    if(reset)
        data_out <= 32'b0;
    else if(iread)
        data_out <= i_cache[addr[index_end:offset_start]];
    else 
        data_out <= d_cache[addr[index_end:offset_start]];
end 

always_comb begin
    if(iread) current_control = i_control[addr[index_end:index_start]];
    else current_control = d_control[addr[index_end:index_start]];

    sram_addr = write ? addr : {addr[23:index_start], count, 2'b0}; //sram_addr changes when loading words into cache
end


endmodule