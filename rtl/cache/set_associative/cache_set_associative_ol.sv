/*
* module replaces spi_master
* address: [23 .tag. 9|8 .set. 5|4 .offset. 2|1 .bytes. 0]
*          [   15     |     4   |     3      |     2     ]
*
* cache line: [272 .valid. 272|271 .tag. 256|255 .data. 0]
*/

module cache_set_associative (
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
    input logic idle     //true, when
);

localparam set_end = 8;
localparam set_start = 5;
localparam offset_end = 4;
localparam offset_start = 2;

localparam c_end = 15;

localparam ways = 8;
localparam way_bits = 3;
localparam sets = 16;
localparam set_bits = 4;

//typedef logic [31:0] data [8];
//             0     1           2     3           4            5      6      7
typedef enum  {IDLE, LOAD_AWAIT, LOAD, LOAD_RESET, WRITE_AWAIT, WRITE, VALID, FAULT} states;

logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;

logic [31:0] i_cache[1024];//[16][8][8], set, offset, way
//logic [14:0] i_tag[ways][16];
logic [14:0] i_tag[128];
logic i_valid[128];

logic [31:0] d_cache[1024];
//logic [14:0] d_tag[ways][16];
logic [14:0] d_tag[128];
logic d_valid [128];

logic [c_end:0] current_line;


states state;

logic [2:0] count; //variable for loading 8 words

logic unaligned;

// replacement
logic [ways - 1:0] i_vec_hit;      // one-hot vector indicating which way was hit
logic [ways - 1:0] d_vec_hit;
logic i_hit;
logic d_hit;
logic hit;
logic [way_bits - 1:0] i_way_hit; // the "number" of the way that was hit
logic [way_bits - 1:0] d_way_hit; // the "number" of the way that was hit

logic i_hit_flag;
logic d_hit_flag;
logic [2:0] i_way_replace;
logic [2:0] d_way_replace;
logic i_rep_finished;
logic d_rep_finished;
logic rep_finished;

spi_master sram (
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

plru_m #(
    .ways(ways),
    .way_bits(way_bits),
    .sets(sets),
    .set_bits(set_bits)
) i_rep (
    .clk(clk),
    .reset(reset),
    .hit(i_hit_flag),            //set high to mark way "way_hit" as hit
    .set(addr[set_end:set_start]),
    .way_hit(i_way_hit),
    .way_replace(i_way_replace), //output
    .finished(i_rep_finished)     //output
);

plru_m #(
    .ways(ways),
    .way_bits(way_bits),
    .sets(sets),
    .set_bits(set_bits)
) d_rep (
    .clk(clk),
    .reset(reset),
    .hit(d_hit_flag),            //set high to mark way "way_hit" as hit
    .set(addr[set_end:set_start]),
    .way_hit(d_way_hit),
    .way_replace(d_way_replace), //output
    .finished(d_rep_finished)     //output
);

// state transition
always_ff @( posedge clk ) begin
    if(reset) begin
        state <= IDLE;
        count <= 3'b0;
        i_hit <= 1'b0;
        d_hit <= 1'b0;
        for(int i = 0; i < ways * sets; i++) begin
            //i_valid[i] <= 1'b0;
            /*for(int j = 0; j < 16; j++) begin
                i_valid[i][j] <= 1'b0;
                d_valid[i][j] <= 1'b0;
            end*/
        end
    end else begin
        case(state)
            IDLE: begin
                if(idle) state <= IDLE;
                else if(unaligned) state <= FAULT;
                else if(write) state <= WRITE_AWAIT;
                else begin
                    // data is cached
                    if(hit) begin
                        state <= VALID;
                        i_hit <= iread;
                        d_hit <= ~iread;
                    //load line
                    end else begin
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
                            i_cache[{addr[set_end:set_start], count, i_way_replace}] <= sram_data_out;
                            i_tag[{addr[set_end:set_start], i_way_replace}]          <= addr[23:set_end + 1];   //set tag
                            //i_tag[i_way_replace][addr[set_end:set_start]]            <= addr[23:set_end + 1];   //set tag
                            i_valid[{addr[set_end:set_start], i_way_replace}]        <= 1'b1;
                        end else begin
                            d_cache[{{addr[set_end:set_start], count}, d_way_replace}] <= sram_data_out;
                            d_tag[{addr[set_end:set_start], d_way_replace}]            <= addr[23:set_end + 1];   //set tag
                            //d_tag[d_way_replace][addr[set_end:set_start]]              <= addr[23:set_end + 1];   //set tag
                            d_valid[{addr[set_end:set_start], d_way_replace}]          <= 1'b1;
                        end
                    end
                    else state <= FAULT;
                end
            end
            LOAD_RESET: begin
                if(count == 0) begin
                    state <= VALID;
                    i_hit <= iread;
                    d_hit <= ~iread;
                end
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
                    if(i_hit) begin
                        i_cache[{addr[set_end:offset_start], i_way_hit}] <= data_in;
                    end
                    if(d_hit) begin
                        d_cache[{addr[set_end:offset_start], d_way_hit}] <= data_in;
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
                i_hit <= 1'b0;
                d_hit <= 1'b0;
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
    sram_reset = 1'b1; //reset sram on IDLE, READ_OUT, VALID, FAULT
    case(state)
        IDLE: begin
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

always_ff @( posedge clk ) begin
    if(reset)
        data_out <= 32'b0;
    else if(iread)
        data_out <= i_cache[{addr[set_end:offset_start], i_way_hit}];
    else
        data_out <= d_cache[{addr[set_end:offset_start], d_way_hit}];
end

assign unaligned = addr[0] || addr[1];
assign sram_addr = write ? addr : {addr[23:set_start], count, 2'b0}; //sram_addr changes when loading words into cache
assign hit = (iread && i_hit) || (~iread && d_hit);

//determine which way was hit, if any, represented as a one-hot vector
always_comb begin
    i_hit = 1'b0;
    d_hit = 1'b0;

    for(int i = 0; i < ways; i++) begin
        i_vec_hit[i] = i_valid[{addr[set_end:offset_start], i[way_bits - 1:0]}] && (i_tag[{addr[set_end:offset_start], i[way_bits - 1:0]}] == addr[23:set_end + 1]);
        //i_vec_hit[i] = i_valid[{addr[set_end:offset_start], i[way_bits - 1:0]}] && (i_tag[i][addr[set_end:offset_start]] == addr[23:set_end + 1]);
        d_vec_hit[i] = d_valid[{addr[set_end:offset_start], i[way_bits - 1:0]}] && (d_tag[{addr[set_end:offset_start], i[way_bits - 1:0]}] == addr[23:set_end + 1]);
        //d_vec_hit[i] = d_valid[{addr[set_end:offset_start], i[way_bits - 1:0]}] && (d_tag[d][addr[set_end:offset_start]] == addr[23:set_end + 1]);
        //i_vec_hit[i] = addr[23:set_end + 1] == 2;
        //d_vec_hit[i] = addr[23:set_end + 1] == 2;

        i_hit |= i_vec_hit[i];
        d_hit |= d_vec_hit[i];
    end
end

//determine the way that was hit
always_comb begin
    i_way_hit = 0;
    d_way_hit = 0;

    for(int i = 0; i < ways; i++) begin
        i_way_hit |= i[way_bits - 1:0] && {(way_bits){i_vec_hit[i]}};
        d_way_hit |= i[way_bits - 1:0] && {(way_bits){d_vec_hit[i]}};
    end
end


endmodule