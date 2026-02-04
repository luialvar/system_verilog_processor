// Memory Map:
// 0x000000 - 0xFFFFFF: SRAM
// 0x1000000: GPIO Outputs
// 0x1000001: GPIO Inputs
// 0x1000002: Send via UART
// 0x1000003: I2C data
// 0x1000004: I2C device address
// 0x1000005: I2C byte mask
// 0x1000006: mtime
// 0x1000007: mtimeh
// 0x1000008: mtimecmp
// 0x1000009: mtimecmph
// 0x1000010 - end: load_access_fault

module memory_cache_set (
    input logic clk,
    input logic reset,
    input logic ce,     // active low

    input logic [31:0] addr,
    input logic [31:0] datain,
    input logic        memwrite,

    output logic [31:0] dataout,
    output logic        busy,
    output logic        valid,

    // SPI interface to SRAM
    input  logic so,
    output logic si,
    output logic sclk,
    output logic sram_ce,

    // I2C interface
    output logic scl,
    inout  logic sda,

    // UART Interface
    output logic tx,

    // GPIOs
    input  logic [7:0] gpio_in,
    output logic [7:0] gpio_out,

    output logic intr_timer,
    output logic load_access_fault,

    input logic iread  //read command issued for instruction
);

  localparam int SRAM_LOW_ADDR = 32'h0000000;
  localparam int SRAM_HIGH_ADDR = 32'h0FFFFFF;
  localparam int GPIO_OUT_ADDR = 32'h1000000;
  localparam int GPIO_IN_ADDR = 32'h1000001;
  localparam int UART_TX_ADDR = 32'h1000002;
  localparam int I2C_DATA_ADDR = 32'h1000003;
  localparam int I2C_DEVICE_ADDR = 32'h1000004;
  localparam int I2C_MASK_ADDR = 32'h1000005;
  localparam int MTIME_ADDR = 32'h1000006;
  localparam int MTIMEH_ADDR = 32'h1000007;
  localparam int MTIMECMP_ADDR = 32'h1000008;
  localparam int MTIMECMPH_ADDR = 32'h1000009;

  typedef enum {
    IDLE,
    WRITING,
    READING,
    GPIO_WAIT,
    CONTROL_REG,
    VALID,
    FINISH,
    FAULT
  } states_t;

  typedef enum {
    SRAM,
    I2C,
    UART,
    GPIO
  } target_t;

  states_t        state = IDLE;
  target_t        target = SRAM;

  logic    [63:0] mtime = 0;
  logic    [63:0] mtimecmp = 0;

  logic    [31:0] addr_reg;
  logic    [31:0] datain_reg;
  logic           memwrite_reg;

  logic master_reset, master_busy, master_valid;
  logic sram_reset, sram_busy, sram_valid;
  logic i2c_reset, i2c_busy, i2c_valid;
  logic [7:0] i2c_addr;
  logic [3:0] i2c_mask;

  logic [31:0] master_dataout, sram_dataout, i2c_dataout;

  // This ensures that the spi_master actually started working
  // Otherwise we would assume it has finished before it began
  // TODO: Rewrite as seperate states like READING_AWAIT, ...
  logic sclk_flag;

  //spi_master sram_master (
  cache_set_associative cache(
      .clk(clk),
      .reset(reset), //original has sram_reset here
      .si(si),
      .so(so),
      .sclk(sclk),
      .ce(sram_ce),
      .addr(addr_reg),
      .data_in(datain_reg),
      .data_out(sram_dataout),
      .write(memwrite_reg),
      .busy(sram_busy),
      .valid(sram_valid),
      .iread(iread),     //added, 
      .idle(sram_reset)
  );

  i2c_master i2c_master (
      .clk(clk),
      .reset(i2c_reset),
      .sda(sda),
      .scl(scl),
      .device_addr(i2c_addr),
      .mask(i2c_mask),
      .data_in(datain_reg),  // TODO: Refactor
      .data_out(i2c_dataout),
      .write(memwrite_reg),
      .busy(i2c_busy),
      .valid(i2c_valid)
  );

  logic uart_busy;
  logic uart_en = 0;

  uart_tx uart_transmitter (
      .clk(clk),
      .resetn(~reset),
      .uart_txd(tx),
      .uart_tx_busy(uart_busy),
      .uart_tx_en(uart_en),
      .uart_tx_data(datain_reg[7:0])
  );

  always_ff @(posedge clk) begin
    mtime <= mtime + 1;

    if (reset || ce) begin
      state   <= IDLE;
      uart_en <= 0;
      // mtime <= 0;
      // mtimecmp <= 0;
    end else begin
      // starting when ce falls to 0
      unique case (state)
        IDLE: begin
          if (memwrite == 1) state <= WRITING;
          else state <= READING;
          // Storing all inputs before transmission
          addr_reg <= addr;
          memwrite_reg <= memwrite;
          sclk_flag <= 0;

          // == SRAM ==================================
          if (addr >= SRAM_LOW_ADDR && addr <= SRAM_HIGH_ADDR) begin
            target <= SRAM;
            datain_reg <= {datain[7:0], datain[15:8], datain[23:16], datain[31:24]};

            // == GPIO ==================================
          end else if (addr == GPIO_OUT_ADDR) begin
            target <= GPIO;
            state  <= GPIO_WAIT;

            if (memwrite) gpio_out <= datain[7:0];
            else begin
              // Set to a defined value, just in case
              dataout <= 0;
              state   <= FAULT;
            end
          end else if (addr == GPIO_IN_ADDR) begin
            target <= GPIO;
            state  <= GPIO_WAIT;

            if (~memwrite) dataout <= {24'b0, gpio_in};
            else state <= FAULT;

            // == UART ==================================
          end else if (addr == UART_TX_ADDR) begin
            if (memwrite) begin
              target <= UART;
              datain_reg <= datain;
              uart_en <= 1;
            end else state <= FAULT;  // Reading from UART not possible here

            // == I2C data ==================================
          end else if (addr == I2C_DATA_ADDR) begin
            datain_reg <= datain;
            target <= I2C;

            // == Control registers ==================================
          end else if (addr >= I2C_DEVICE_ADDR && addr <= MTIMECMPH_ADDR) begin
            datain_reg <= datain;
            state <= CONTROL_REG;

            // == Load Access Fault ==================================
          end else state <= FAULT;
        end

        READING: begin
          if (master_busy) sclk_flag <= 1;

          // Master became busy (sclk_flag) and is now finished
          if (sclk_flag && master_valid && ~master_busy) begin
            state <= VALID;

            if (target == SRAM)
              dataout <= {
                master_dataout[7:0],
                master_dataout[15:8],
                master_dataout[23:16],
                master_dataout[31:24]
              };
            else dataout <= master_dataout;
          end
        end

        WRITING: begin
          // HACK: Das mit uart_en is net schön gelöst
          if (master_busy) begin
            sclk_flag <= 1;
            if (target == UART) uart_en <= 0;
          end

          // Master became busy (sclk_flag) and is now finished
          if (sclk_flag && ~master_busy) state <= FINISH;
        end

        GPIO_WAIT: state <= FINISH;
        CONTROL_REG: begin
          state <= FINISH;
          if (memwrite) begin
            case (addr_reg)
              I2C_DEVICE_ADDR: i2c_addr <= datain_reg[7:0];
              I2C_MASK_ADDR:   i2c_mask <= datain_reg[3:0];
              MTIME_ADDR:      mtime[31:0] <= datain_reg;
              MTIMEH_ADDR:     mtime[63:32] <= datain_reg;
              MTIMECMP_ADDR:   mtimecmp[31:0] <= datain_reg;
              MTIMECMPH_ADDR:  mtimecmp[63:32] <= datain_reg;
            endcase
          end else begin
            case (addr_reg)
              I2C_DEVICE_ADDR: dataout <= {24'b0, i2c_addr};
              I2C_MASK_ADDR:   dataout <= {28'b0, i2c_mask};
              MTIME_ADDR:      dataout <= mtime[31:0];
              MTIMEH_ADDR:     dataout <= mtime[63:32];
              MTIMECMP_ADDR:   dataout <= mtimecmp[31:0];
              MTIMECMPH_ADDR:  dataout <= mtimecmp[63:32];
            endcase
          end
        end
        VALID:     state <= VALID;
        FINISH:    state <= FINISH;
        FAULT:     state <= FAULT;
      endcase  // unique case (state)
    end
  end

  always_comb begin
    master_dataout = sram_dataout;
    master_busy = sram_busy;
    master_valid = sram_valid;

    if (target == I2C) begin
      master_dataout = i2c_dataout;
      master_busy = i2c_busy;
      master_valid = i2c_valid;
    end else if (target == UART) begin
      master_busy = uart_busy;
    end
  end

  assign busy = (state == READING || state == WRITING || state == GPIO_WAIT || state == CONTROL_REG) ? 1'b1 : 1'b0;
  assign valid = (state == VALID) ? 1'b1 : 1'b0;

  // reset master if not doing anything
  assign master_reset = (state == READING || state == WRITING) ? 1'b0 : 1'b1;

  assign i2c_reset = (target == I2C) ? master_reset : 1;
  assign sram_reset = (target == SRAM) ? master_reset : 1;

  assign intr_timer = (mtime >= mtimecmp) ? 1 : 0;
  assign load_access_fault = (state == FAULT) ? 1 : 0;
endmodule  // memory
