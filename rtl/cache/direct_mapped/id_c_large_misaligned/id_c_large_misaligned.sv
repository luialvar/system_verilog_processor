/*
* module replaces spi_master
* address: [23 .tag. 16|15 .index. 9|8 .offset. 2|1 .bytes. 0], 8 bit words
*          [   7       |     7      |     7      |      2    ]
*
* misaligned read:
* read out upper, read out lower
* if value isn't cached and cache-line boundary is crossed, cache next line as well (slow)
*/

module id_c_large_misaligned (
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

    input logic iread,   //instruction-word load, only caching iwords
    input logic idle
);
//use sbram40K as storage for valid/tags?
//two spram blocks for i/d cache each.
//separate modules from state machine, only use control bits to drive them.

localparam index_bits = 7;  // 2**14, intex_bits + offset_bits 14 max
localparam offset_bits = 7;

localparam offset_start = 2;
localparam offset_end = offset_start + offset_bits - 1;
localparam index_start = offset_end + 1;
localparam index_end = index_start + index_bits - 1;

localparam tag_bits = 23 - index_end;

//typedef logic [31:0] data [8];
//            0     1        2           3     4           5        6            7      8         9         10     11
typedef enum {IDLE, COMPARE, LOAD_AWAIT, LOAD, LOAD_RESET, CH_ADDR, WRITE_AWAIT, WRITE, FINISH_A, FINISH_B, VALID, FAULT} states;
states state;

// sram control
logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;


// variable for loading offset-number of words
logic [offset_bits - 1:0] count;


// handling of misaligned accesses
logic misaligned;
logic misaligned_line;
logic should_load_next;
logic next_line_index;

logic [23 - offset_end:0] ch_index;
logic [23:0] load_addr;
logic [63:0] combined;


// control for cache modules
logic [1:0] read_enable;
logic [1:0] write_enable;
logic set_valid;

logic [31:0] d_data_out, i_data_out;
logic i_hit;
logic d_hit;
logic hit;


// data_in select for caches
logic [31:0] cache_data_in;
logic data_in_select;        // 1 - sram_out, 0 - data_in

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
    if(reset || idle) begin
        state <= IDLE;
        count <= 0;
    end else begin
        case(state)
            IDLE: begin
                if(misaligned && iread) state <= FAULT;
                else if(write) state <= WRITE_AWAIT;
                else state <= COMPARE;

                if(misaligned_line) begin
                    next_line_index <= 1'b1;
                end
            end
            COMPARE: begin
                if(hit) begin
                    if(misaligned_line) begin //missaligned and next line might has to be loaded
                            state <= CH_ADDR;
                            should_load_next <= 1'b0;

                        end else begin //data is cached
                            state <= FINISH_A;
                        end

                end else begin
                    state <= LOAD_AWAIT;
                    should_load_next <= misaligned;
                    next_line_index <= 1'b0;
                end
                count <= {(offset_bits){1'b1}};
            end
            LOAD_AWAIT: begin
                // load offset consecutive words, beginning by address addr (ignoring offset)
                if(sram_busy)
                    state <= LOAD;
                else
                    state <= LOAD_AWAIT;  // wait for sram to respond
            end
            LOAD: begin
                if(sram_busy) state <= LOAD;
                else begin
                    if(sram_valid) begin
                        state <= LOAD_RESET;
                        if(count == 0 && should_load_next)
                            // change index to load from next line on line-change. Count = 0, because then we change to CH_ADDR in the follow-up state
                            next_line_index <= 1'b1;
                    end else
                        state <= FAULT;
                end
            end
            LOAD_RESET: begin
                if(count == 0) begin
                    // load next cache line on line-misaligned read
                    if(should_load_next) begin
                        should_load_next <= 1'b0;
                        state <= CH_ADDR;
                        count <= {(offset_bits){1'b1}};
                    end else begin
                        state <= FINISH_A;
                    end

                end else begin
                    state <= LOAD_AWAIT;
                    count <= count - 1;
                end
            end
            CH_ADDR: begin
                if(d_hit)
                    state <= FINISH_A;
                else
                    state <= LOAD_AWAIT;
            end
            WRITE_AWAIT: begin
                if(sram_busy)
                    state <= WRITE;
                else
                    state <= WRITE_AWAIT;
            end
            WRITE: begin
                if(sram_busy)
                    state <= WRITE;
                else
                    state <= FINISH_A;
            end
            FINISH_A: begin
                if(misaligned) begin
                    state <= FINISH_B;
                    $display("put %h in lower combined", d_data_out);
                    combined[31:0] <= d_data_out;
                end else
                    state <= FINISH_A;
            end
            FINISH_B: begin
                $display("put %h in upper combined", d_data_out);
                combined[63:32] <= d_data_out;
                state <= VALID;
            end
            VALID: begin
                state <= VALID;
            end
            FAULT: begin
                state <= FAULT;
            end
            default: state <= IDLE;
        endcase
    end
end

always_comb begin
    busy = 1'b1;
    valid = 1'b0;
    sram_reset = 1'b1; //reset sram on RESET, READ_OUT, FINISH_A, FAULT
    read_enable = 2'b0;
    write_enable = 2'b0;
    set_valid = 1'b0;
    data_in_select = 1'b0;
    load_addr = addr;

    case(state)
        IDLE: begin
            if(!idle)
                read_enable = 2'b11; //enable both data and instruction cache to compare hits on next cycle
        end
        COMPARE: begin
            if(hit)
                read_enable = 2'b11;  //enable both data and instruction cache again to compare hits on changed address, because read spans accross two lines

            // can't check hit because that creates loop, but should work without
            // always change line when we are misaligned, because if next state is LOAD_AWAIT, don't care about cache output
            // for COMPARE -> FINISH_A, load_addr should be equal to addr though
            if(misaligned_line)
                load_addr[23:index_start] = ch_index;
        end
        LOAD_AWAIT: begin
            sram_reset = 1'b0;
            load_addr[offset_end:offset_start] = count;
            if(next_line_index)
                load_addr[23:index_start] = ch_index;
        end
        LOAD: begin
            sram_reset = 1'b0;
            if(sram_valid && !sram_busy) begin
                write_enable = {~iread, iread};
                load_addr[offset_end:offset_start] = count;
                set_valid = 1'b1;
                data_in_select = 1'b1; //load from sram
            end
            if(next_line_index)
                load_addr[23:index_start] = ch_index;
        end
        LOAD_RESET: begin
            if(count == 0) begin
                read_enable = 2'b11;  // read again on should_load_next as well as normal read, as cache modules need to output the correct data
            end
            if(should_load_next || (next_line_index && count != 0))
                load_addr[23:index_start] = ch_index;
        end
        CH_ADDR: begin
            if(d_hit)
                read_enable = 2'b11;
        end
        WRITE_AWAIT: begin
            if(sram_busy)
                write_enable = {d_hit, i_hit};
                set_valid = 1'b1;
            sram_reset = 1'b0;
        end
        WRITE: begin
            sram_reset = 1'b0; //enable sram, reset high if sram not in use
        end
        FINISH_A: begin
            // already valid in this state, if we don't have to load second part
            valid = !misaligned;
            busy = misaligned;
            if(misaligned) begin
                read_enable = 2'b11;
                load_addr[23:offset_start] = addr[23:offset_start] + 1;
                load_addr[offset_start - 1:0] = {(offset_start){1'b0}};
            end
        end
        FINISH_B: begin
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


assign misaligned = addr[1] || addr[0];
assign misaligned_line = addr[4] && addr[3] && addr[2] && misaligned;

assign cache_data_in = data_in_select ? sram_data_out : data_in;
assign hit = (iread && i_hit) || (~iread && d_hit);

assign ch_index = addr[23:index_start] + 1;

always_comb begin
    if(reset)
        data_out = 32'b0;
    else if(iread)
        data_out = i_data_out;
    else begin
        if(misaligned) begin
            data_out = combined >> {addr[1:0], 3'b0};
        end else
            data_out = d_data_out;
    end

    //sram_addr changes when loading words into cache
    sram_addr = write ? addr : {load_addr[23:index_start], count, 2'b0};
end

cache_module #(
    .tag_bits(tag_bits),
    .index_bits(index_bits),
    .offset_bits(offset_bits),
    .cell_select(1)   //spram
) i_cache (
    .clk(clk),
    .reset(reset),
    .tag(load_addr[23:index_end + 1]),
    .index(load_addr[index_end:index_start]),
    .offset(load_addr[offset_end:offset_start]),
    .valid(set_valid),
    .read_enable(read_enable[0]),
    .write_enable(write_enable[0]),
    .data_in(cache_data_in),
    .data_out(i_data_out),
    .hit(i_hit)
);

cache_module #(
    .tag_bits(tag_bits),
    .index_bits(index_bits),
    .offset_bits(offset_bits),
    .cell_select(1)   //spram
) d_cache (
    .clk(clk),
    .reset(reset),
    .tag(load_addr[23:index_end + 1]),
    .index(load_addr[index_end:index_start]),
    .offset(load_addr[offset_end:offset_start]),
    .valid(set_valid),
    .read_enable(read_enable[1]),
    .write_enable(write_enable[1]),
    .data_in(cache_data_in),
    .data_out(d_data_out),
    .hit(d_hit)
);

endmodule