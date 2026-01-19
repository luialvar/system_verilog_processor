/*
* module replaces spi_master
* address: [23 .tag. 12|11 .index. 5|4 .offset. 2|1 .bytes. 0], 8 bit words
*          [   12      |     7      |     3      |      2    ]
*
* misaligned read:
* read out upper, read out lower
* if value isn't cached and cache-line boundary is crossed, cache next line as well (slow)
*/

module id_cache_direct_mapped_large_misaligned (
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

localparam index_end = 11;
localparam index_start = 5;
localparam offset_end = 4;
localparam offset_start = 2;

localparam tag_bits = 23 - index_end;
//localparam tag_bits = 16;//23 - index_end;

//typedef logic [31:0] data [8];
//            0      1           2     3           4        5            6      7         8         9
typedef enum {RESET, LOAD_AWAIT, LOAD, LOAD_RESET, CH_ADDR, WRITE_AWAIT, WRITE, FINISH_A, FINISH_B, FAULT, COMP} states;

logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;

logic [32:0] i_cache[2**10];//[128][8], 2^11 2^3;  //4KiB 
logic [tag_bits:0] i_control[2**7];

logic [32:0] d_cache[2**10];//[128][8], 2^11 2^3;   //4KiB
logic [tag_bits:0] d_control[2**7];

logic [tag_bits:0] current_control;

states state;

logic [2:0] count; //variable for loading 8 words

logic misaligned;
logic misaligned_line;
logic load_next_line;

logic [23:0] load_addr;
logic [63:0] combined;

logic [31:0] d_data_out, i_data_out;

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
                load_addr <= addr;

                if(misaligned && iread) state <= FAULT; 
                else if(write) state <= WRITE_AWAIT;
                else begin
                    if(current_control[tag_bits] & current_control[tag_bits - 1:0] == addr[23:index_end + 1]) begin
                        if(misaligned_line) begin //missaligned and next line might has to be loaded
                           // $display("Misaligned line");
                            state <= CH_ADDR;
                            load_next_line <= 1'b0;
                            load_addr[23:index_start] <= addr[23:index_start] + 1;
                            load_addr[index_start - 1:0] <= 5'b0;
                        end else begin //data is cached
                            state <= FINISH_A;
                            load_addr[23:offset_start] <= addr[23:offset_start] + 1;
                            load_addr[offset_start - 1:0] <= 3'b0;
                        end
                        
                    end else begin //load line
                        state <= LOAD_AWAIT;
                        load_next_line <= misaligned;
                    end                    
                    //$display("d_cache: %h", d_cache[addr[index_end:offset_start]]);
                    combined[31:0] <= d_cache[addr[index_end:offset_start]];
                    count <= 3'b111;
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
                            i_cache[{load_addr[index_end:index_start], count}] <= sram_data_out;
                            i_control[load_addr[index_end:index_start]] <= {1'b1, load_addr[23:index_end + 1]};   //set valid and tag
                        end else begin 
                            d_cache[{load_addr[index_end:index_start], count}] <= sram_data_out;
                            d_control[load_addr[index_end:index_start]] <= {1'b1, load_addr[23:index_end + 1]};   //set valid and tag    
                        end
                    end
                    else state <= FAULT;
                end
            end
            LOAD_RESET: begin
                if(count == 0) begin
                    //load next cache line on line-misaligned read
                    if(load_next_line) begin
                        load_next_line <= 1'b0;
                        state <= CH_ADDR;
                        count <= 3'b111;
                        combined[31:0] <= d_cache[load_addr[index_end:index_start]];
                        load_addr[23:index_start] <= addr[23:index_start] + 1;
                        load_addr[index_start - 1:0] <= 5'b0;
                    end else begin
                        state <= FINISH_A;
                        load_addr[23:offset_start] <= addr[23:offset_start] + 1;
                        load_addr[offset_start - 1:0] <= 3'b0;
                    end
                    combined[31:0] <= d_cache[addr[index_end:offset_start]];
                    
                end else begin 
                    state <= LOAD_AWAIT;
                    count <= count - 1;
                end
            end
            CH_ADDR: begin
                if(d_control[load_addr[index_end:index_start]][tag_bits] & d_control[load_addr[index_end:index_start]][tag_bits - 1:0] == load_addr[23:index_end + 1]) 
                    state <= FINISH_A;
                else 
                    state <= LOAD_AWAIT;
            end
            WRITE_AWAIT: begin //missing check for overwrite of i_cached data
                if(sram_busy) begin 
                    state <= WRITE;

                    //write word to cache if hit
                    //entry valid    and    tag         matches address tag
                    if(i_control[addr[index_end:index_start]][tag_bits] & i_control[addr[index_end:index_start]][tag_bits - 1:0] == addr[23:index_end+1]) begin
                        i_cache[addr[index_end:offset_start]] <= data_in;
                    end
                    if(d_control[addr[index_end:index_start]][tag_bits] & d_control[addr[index_end:index_start]][tag_bits - 1:0] == addr[23:index_end+1]) begin
                        d_cache[addr[index_end:offset_start]] <= data_in;
                    end
                end else begin 
                    state <= WRITE_AWAIT;                   
                end
            end
            WRITE: begin
                if(sram_busy) state <= WRITE;
                else state <= FINISH_A;
            end
            FINISH_A: begin
                if(misaligned) begin
                    state <= FINISH_B;
                    //$display("d_cache: %h", d_cache[load_addr[index_end:offset_start]]);
                    combined[63:32] <= d_cache[load_addr[index_end:offset_start]];
                end else
                    state <= FINISH_A;
            end
            FINISH_B: begin
                state <= FINISH_B;
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
    sram_reset = 1'b1; //reset sram on RESET, READ_OUT, FINISH_A, FAULT
    case(state)
        RESET, COMP: begin
            //module always busy, saves one state --- eh, not optimal 
            //busy = 1'b0;
        end
        LOAD_AWAIT, LOAD, WRITE_AWAIT, WRITE: begin
            sram_reset = 1'b0; //enable sram, reset high if sram not in use
        end
        FINISH_A: begin
            valid = !misaligned;
            busy = misaligned;
        end
        FINISH_B: begin
            valid = 1'b1;
            busy = 1'b0;
        end
        FAULT: begin
            busy = 1'b0; //busy and valid low
        end
    endcase
end


assign misaligned = addr[1] || addr[0];
assign misaligned_line = addr[4] && addr[3] && addr[2] && misaligned;

always_ff @( posedge clk) begin
    i_data_out <= i_cache[addr[index_end:offset_start]];
    d_data_out <= d_cache[addr[index_end:offset_start]];
end 

always_comb begin
    if(iread) current_control = i_control[addr[index_end:index_start]];
    else current_control = d_control[addr[index_end:index_start]];

    if(reset)
        data_out = 32'b0;
    else if(iread)
        data_out = i_data_out; //i_cache[addr[index_end:offset_start]];//data_out_reg;
    else begin
        if(misaligned) begin
            data_out = combined >> {addr[1:0], 3'b0};
        end else 
            data_out = d_data_out; //d_cache[addr[index_end:offset_start]];
    end

    /*if(write) 
        sram_addr = addr;
    else begin
        sram_addr = load_next_line ? {load_addr[23:index_start], count, 2'b0} : {addr[23:index_start], count, 2'b0};
    end*/
    sram_addr = write ? addr : {load_addr[23:index_start], count, 2'b0}; //sram_addr changes when loading words into cache
end

endmodule