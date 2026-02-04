/*
* This is somewhat of a mess
* module replaces spi_master
* address: [23 .tag. 10|9 .set. 6|5 .offset. 2|1 .bytes. 0]
*          [   14      |     4   |     4      |     2     ]
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
    input logic idle     //true, when cache is not in use
);
localparam replacement_policy = 1;  //select replacement policy


localparam offset_bits  = 4;   //4 better than 3 here?
localparam sets         = 16;
localparam set_bits     = 4;
localparam ways         = 4;
localparam way_bits     = 2;

localparam offset_start = 2;
localparam offset_end   = offset_start + offset_bits - 1;
localparam set_start    = offset_end + 1;
localparam set_end      = set_start + set_bits - 1;
localparam tag_bits     = 24 - set_end - 1;

//typedef logic [31:0] data [8];
//             0     1        2           3     4           5            6      7      8
typedef enum  {IDLE, COMPARE, LOAD_AWAIT, LOAD, LOAD_RESET, WRITE_AWAIT, WRITE, VALID, FAULT} states;

logic sram_busy, sram_reset, sram_write, sram_valid;
logic [31:0] sram_data_out;
logic [23:0] sram_addr;

states state;

logic [offset_bits - 1:0] offset; 
logic [offset_bits - 1:0] count; //variable for loading 16 words

logic unaligned;

// cache_way
logic [31:0] cache_data_in;
logic [1:0] vec_hit[ways];        // "one-hot" vector indicating which way was hit
logic [31:0] vec_data_out[ways];  //array holding the data_out of all cache ways
logic hit;                        //indicating whether a hit occured
logic i_hit;
logic d_hit;
logic [31:0] data_hit = 0;        //the data from the way that was hit
logic [way_bits - 1:0] way_hit = 0;

logic [1:0] enable[ways - 1:0];

logic valid_flag; //used to set the valid bit in the cache
logic [1:0] cache_write_mode;

// replacement_policy
logic cache_replace_flag; // high when cache line is replaced
logic i_hit_flag = 0;
logic d_hit_flag = 0;
logic [way_bits - 1:0] way_replace;
logic [way_bits - 1:0] i_way_replace;           // replacement policy output
logic [way_bits - 1:0] d_way_replace;           // replacement policy output
logic [way_bits - 1:0] way_hit_replace = 0;     // indicate the way that was hit or the way that was replaced to update the replacement policy
logic i_rep_finished;
logic d_rep_finished;

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

// state transition
always_ff @( posedge clk ) begin
    if(idle || reset) begin
        state <= IDLE;
        count <= 0;
    end else begin
        case(state)
            IDLE: begin
                if(idle) state <= IDLE;
                else if(unaligned) state <= FAULT;
                else if(write) state <= WRITE_AWAIT;
                else begin 
                    state <= COMPARE; 
                end
            end
            COMPARE: begin
                if(hit) begin 
                    //data cached
                    state <= VALID;
                end else begin                    
                    //load line
                    state <= LOAD_AWAIT;
                    count <= {(offset_bits){1'b1}};
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
                    end
                    else state <= FAULT;
                end
            end
            LOAD_RESET: begin

                if(count == 0) begin
                    state <= VALID;;
                end
                else begin 
                    state <= LOAD_AWAIT;
                    count <= count - 1;
                end

            end
            WRITE_AWAIT: begin //missing check for overwrite of i_cached data
                if(sram_busy) begin 
                    state <= WRITE;
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
            default: state <= IDLE;
        endcase
    end
end

always_comb begin
    for(int i = 0; i < ways; i++) begin
        enable[i] = 2'b0;  //d, i
    end 
    offset = addr[offset_end:offset_start];

    cache_write_mode = 2'b00; //default to read
    busy = 1'b1;
    valid = 1'b0;
    sram_reset = 1'b1; //reset sram on IDLE, COMPARE, READ_OUT, VALID, FAULT, enable otherwise
    valid_flag = 1'b0;
    cache_replace_flag = 1'b0;
    way_hit_replace = way_hit;

    //replacement policy
    i_hit_flag = 1'b0;
    d_hit_flag = 1'b0;
    case(state)
        IDLE: begin
            //enable all ways to load and compare the data for the current set
            if(!(idle || unaligned)) begin
                for(int i = 0; i < ways; i++) begin
                    enable[i] = 2'b11; //{~iread, iread};  //d, i
                end 
            end

            //module always busy, saves one state --- eh, not optimal 
            //busy = 1'b0;
        end
        COMPARE: begin
            if(hit) begin
                //update replacement policy
                i_hit_flag = iread;
                d_hit_flag = ~iread;
            end
        end
        LOAD_AWAIT: begin
            offset = count;
            sram_reset = 1'b0; 
        end
        LOAD: begin
            if(!sram_busy && sram_valid) begin
                //overwrite data in the way that should be replaced next and update tag/valid
                cache_write_mode = 2'b01;
                enable[way_replace] = {~iread, iread};
            end
            offset = count;
            sram_reset = 1'b0;
        end
        LOAD_RESET: begin
            if(count == 0) begin
                //update replacement policy
                valid_flag = 1'b1;  //set valid bit in cache line to true
                cache_write_mode = 2'b10;
                cache_replace_flag = 1'b1;
                i_hit_flag = iread;
                d_hit_flag = ~iread;
                way_hit_replace = way_replace;

                //enable cache once more to read out data before jumping to valid (offset is either equal to count or the actual offset)
                enable[way_replace] = {~iread, iread};
            end
        end
        WRITE_AWAIT: begin
            if(sram_busy) begin
                //write word to cache if hit, don't update tag/valid
                cache_write_mode = 2'b01;
                if(i_hit || d_hit) begin
                    enable[way_hit] = vec_hit[way_hit];
                end
            end
            valid_flag = 1'b1; //set valid flag to keep cache line valid when data is overwritten
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

assign data_out = reset ? 32'b0 : data_hit;
assign unaligned = addr[0] || addr[1];
assign sram_addr = write ? addr : {addr[23:set_start], offset, 2'b0}; //sram_addr changes when loading words into cache
assign hit = (i_hit && iread) || (d_hit && ~iread);
assign way_replace = iread ? i_way_replace : d_way_replace;   //assign the next way that should be replaced
assign cache_data_in = write ? data_in : sram_data_out; //cache uses data_in on write, otherwise we want to write the data comming from the sram to the cache

//determine the way that was hit and store the word
always_comb begin
    i_hit = 1'b0;
    d_hit = 1'b0;
    way_hit = 0;
    data_hit = 32'b0;

    for(int i = 0; i < ways; i++) begin //vec_hit is "one-hot" vector indicating which way was hit
        i_hit |= vec_hit[i][0];
        d_hit |= vec_hit[i][1];


        if((vec_hit[i][1] && ~iread) || (vec_hit[i][0] && iread)) begin //only interested in the one-hot vector from either iread or dataread, not both
            data_hit |= vec_data_out[i];            
            way_hit |= i[way_bits - 1:0];
        end
        //way_hit |= i[way_bits - 1:0] && {(way_bits){vec_hit[i][1] || vec_hit[i][0]}};
        //data_hit |= {(32){(vec_hit[i][1] || vec_hit[i][0])}} && vec_data_out[i];
    end
end

genvar t;
generate
    for(t = 0; t < ways; t++) begin
        cache_way #(
            .set_bits(set_bits),
            .tag_bits(tag_bits),
            .offset_bits(offset_bits)
        ) way (
            .clk(clk),
            .reset(reset),
            .enable(enable[t]),
            .mode(cache_write_mode),
            .iread(iread),
            .tag(addr[23:set_end + 1]),
            .set(addr[set_end:set_start]),
            .offset(offset),
            .data_in(cache_data_in),
            .valid(valid_flag),
            .hit(vec_hit[t]),
            .data_out(vec_data_out[t])
        );
    end
endgenerate


// generate replacement policy, 1 - plrum, 0 - fifo
generate
    if(replacement_policy) begin
        plru_m #(
            .ways(ways),
            .way_bits(way_bits),
            .sets(sets),
            .set_bits(set_bits)
        ) i_rep (
            .clk(clk),
            .reset(reset),
            .hit(i_hit_flag),            //set high to mark way "way_hit" as hit
            .replace(cache_replace_flag),
            .set(addr[set_end:set_start]),
            .way_hit(way_hit_replace),
            .way_replace(i_way_replace),  //output
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
            .replace(cache_replace_flag),
            .set(addr[set_end:set_start]),
            .way_hit(way_hit_replace),
            .way_replace(d_way_replace),  //output
            .finished(d_rep_finished)     //output
        );
    end else begin
        fifo #(
            .ways(ways),
            .way_bits(way_bits),
            .sets(sets),
            .set_bits(set_bits)
        ) i_rep (
            .clk(clk),
            .reset(reset),
            .hit(i_hit_flag),            //set high to mark way "way_hit" as hit
            .replace(cache_replace_flag),
            .set(addr[set_end:set_start]),
            .way_hit(way_hit_replace),
            .way_replace(i_way_replace),  //output
            .finished(i_rep_finished)     //output
        );

        fifo #(
            .ways(ways),
            .way_bits(way_bits),
            .sets(sets),
            .set_bits(set_bits)
        ) d_rep (
            .clk(clk),
            .reset(reset),
            .hit(d_hit_flag),            //set high to mark way "way_hit" as hit
            .replace(cache_replace_flag),
            .set(addr[set_end:set_start]),
            .way_hit(way_hit_replace),
            .way_replace(d_way_replace),  //output
            .finished(d_rep_finished)     //output
        );
    end
endgenerate



endmodule


/*
genvar t;
generate
    for(t = 0; t < ways; t++) begin
        cache_way #(
            .set_bits(set_bits),
            .tag_bits(tag_bits),
            .offset_bits(offset_end - offset_start + 1)
        ) i_way (
            .clk(clk),
            .reset(reset),
            .enable(i_enable[t]),
            .write(cache_write),
            .tag(addr[23:set_end + 1]),
            .set(addr[set_end:set_start]),
            .offset(offset),
            .data_in(sram_data_out),
            .valid(valid_flag),
            .hit(i_vec_hit[t]),
            .data_out(i_data_out[t])
        );
        cache_way #(
            .set_bits(set_bits),
            .tag_bits(tag_bits),
            .offset_bits(offset_end - offset_start + 1)
        ) d_way (
            .clk(clk),
            .reset(reset),
            .enable(d_enable[t]),
            .write(cache_write),
            .tag(addr[23:set_end + 1]),
            .set(addr[set_end:set_start]),
            .offset(offset),
            .data_in(sram_data_out),
            .valid(valid_flag),
            .hit(d_vec_hit[t]),
            .data_out(d_data_out[t])
        );
    end
endgenerate

*/
/*
always_ff @( posedge clk ) begin
    if(reset)
        data_out <= 32'b0;
    else if(iread)
        data_out <= i_data_hit;
    else 
        data_out <= d_data_hit;
end 
*/
