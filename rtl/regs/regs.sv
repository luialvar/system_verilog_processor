module regs (
    input  logic        clk,
    input  logic        reset,       // reset síncrono: fuerza rs1/rs2 a 0 en el flanco

    input  logic        regwrite,    // 1 => escribir en el flanco
    input  logic [4:0]  rs1adr,      // dirección de lectura 1 (0..31)
    input  logic [4:0]  rs2adr,      // dirección de lectura 2 (0..31)
    input  logic [4:0]  rdadr,       // dirección de escritura (0..31)

    input  logic [31:0] rd,          // dato a escribir
    output logic [31:0] rs1,         // salida lectura 1 (registrada, 1 ciclo de latencia)
    output logic [31:0] rs2          // salida lectura 2 (registrada, 1 ciclo de latencia)
);

    // Banco de 32 registros de 32 bits
    logic [31:0] R [0:31];

    // Lectura síncrona (salidas registradas) + posible escritura
    always_ff @(posedge clk) begin
        if (reset) begin
            rs1 <= 32'h0;
            rs2 <= 32'h0;
        end else begin
            // Escritura (ignora x0)
            if (regwrite && (rdadr != 5'd0)) begin
                R[rdadr] <= rd;
            end

            // Lectura rs1 (x0 siempre devuelve 0)
            if (rs1adr == 5'd0) begin
                rs1 <= 32'h0;
            end else begin
                rs1 <= R[rs1adr];
            end

            // Lectura rs2 (x0 siempre devuelve 0)
            if (rs2adr == 5'd0) begin
                rs2 <= 32'h0;
            end else begin
                rs2 <= R[rs2adr];
            end
        end
    end

endmodule
