module traffic_light (
    input logic clk,
    input logic reset,     // active-low reset
    output logic red,
    output logic yellow,
    output logic green
);
    // Definición de estados
    typedef enum logic [1:0] {S_R, S_RY, S_G, S_Y} state_t; //[1:0], it says that the width is 2, so 4 posibilities
    state_t state;

    // Contadores para las duraciones (reloj de 12 MHz), localparam es como const en C
    localparam int CYCLES_R  = 6 * 12000000;  // 6 segundos
    localparam int CYCLES_RY = 2 * 12000000;  // 2 segundos
    localparam int CYCLES_G  = 6 * 12000000;  // 6 segundos
    localparam int CYCLES_Y  = 3 * 12000000;  // 3 segundos
    int unsigned count;

    // Lógica secuencial: transiciones de estado y conteo
    always_ff @(posedge clk or negedge reset) begin //posedge clk es cuando el reloj se activa 0 a 1. y lo otro es cuando se pulsa el pulsador 1 a 0
        if (!reset) begin
            // Reset activo (bajo): volver al estado RED
            state <= S_R;
            count <= 0;
        end else begin
            // Incrementar contador en cada flanco de reloj
            count <= count + 1;
            case (state)
                S_R: begin
                    if (count == CYCLES_R - 1) begin
                        state <= S_RY;
                        count <= 0;
                    end
                end
                S_RY: begin
                    if (count == CYCLES_RY - 1) begin
                        state <= S_G;
                        count <= 0;
                    end
                end
                S_G: begin
                    if (count == CYCLES_G - 1) begin
                        state <= S_Y;
                        count <= 0;
                    end
                end
                S_Y: begin
                    if (count == CYCLES_Y - 1) begin
                        state <= S_R;
                        count <= 0;
                    end
                end
                default: begin
                    // En caso de estado inválido, volver a RED
                    state <= S_R;
                    count <= 0;
                end
            endcase
        end
    end

    // Lógica de salida (Máquina de Moore): la salida depende solo del estado actual
    assign red    = (state == S_R)  || (state == S_RY);
    assign yellow = (state == S_RY) || (state == S_Y);
    assign green  = (state == S_G);
endmodule
