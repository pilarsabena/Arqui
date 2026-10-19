// ============================================================================
// UART Receptor (Rx)
// ----------------------------------------------------------------------------
// Adaptado del Listing 8.1 de Pong P. Chu.
// Trama: 1 start (0) + DBIT datos (LSB primero) + stop (1). Sin paridad.
//
// Sobremuestreo x16 (sección 8.2.1):
//   - IDLE : espera que la línea baje a 0 (comienza el start bit)
//   - START: cuenta 7 ticks -> estoy en la MITAD del start bit
//   - DATA : cada 16 ticks estoy en la mitad del siguiente bit -> lo guardo
//   - STOP : espera SB_TICK ticks (16 = 1 stop bit) y avisa que terminó
// ============================================================================
module uart_rx #(
    parameter DBIT    = 8,   // cantidad de bits de datos
    parameter SB_TICK = 16   // ticks para el stop: 16/24/32 = 1/1.5/2 stop bits
) (
    input                   clk,
    input                   reset,
    input                   rx,            // línea serie de entrada
    input                   s_tick,        // tick del baud rate generator
    output reg              rx_done_tick,  // pulso de 1 ciclo: llegó un byte
    output     [DBIT-1:0]   dout           // byte recibido
);

    // ------------------------------------------------------------------
    // Estados (codificación binaria, 2 bits)
    // ------------------------------------------------------------------
    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    // ------------------------------------------------------------------
    // Sincronizador de 2 flip-flops para la entrada rx
    // (rx viene de afuera, es asíncrona a nuestro clock -> metaestabilidad)
    // ------------------------------------------------------------------
    reg rx_meta, rx_sync;

    always @(posedge clk) begin
        if (reset) begin
            rx_meta <= 1'b1;   // la línea en reposo vale 1
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    // ------------------------------------------------------------------
    // Registros: estado actual + datapath (por eso es una FSMD)
    // ------------------------------------------------------------------
    reg [1:0]               state_reg, state_next;
    reg [3:0]               s_reg,     s_next;     // cuenta ticks (0..15)
    reg [$clog2(DBIT)-1:0]  n_reg,     n_next;     // cuenta bits recibidos
    reg [DBIT-1:0]          b_reg,     b_next;     // byte que se va armando

    // ------------------------------------------------------------------
    // Memoria: actualiza todos los registros en cada flanco de clock
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 0;
            n_reg     <= 0;
            b_reg     <= 0;
        end
        else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
        end
    end

    // ------------------------------------------------------------------
    // Lógica de próximo estado y salidas
    // ------------------------------------------------------------------
    always @(*) begin
        // Valores por defecto: "me quedo como estoy" (evita latches)
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        rx_done_tick = 1'b0;

        case (state_reg)

            IDLE: begin
                if (rx_sync == 1'b0) begin        // flanco de bajada: start bit
                    state_next = START;
                    s_next     = 0;
                end
            end

            START: begin
                if (s_tick) begin
                    if (s_reg == 7) begin         // mitad del start bit
                        if (rx_sync == 1'b0) begin    // sigue en 0: start válido
                            state_next = DATA;
                            s_next     = 0;
                            n_next     = 0;
                        end
                        else                          // era un glitch: descarto
                            state_next = IDLE;
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            DATA: begin
                if (s_tick) begin
                    if (s_reg == 15) begin        // mitad del bit de datos
                        s_next = 0;
                        // LSB llega primero: entra por arriba y desplaza a la derecha
                        b_next = {rx_sync, b_reg[DBIT-1:1]};
                        if (n_reg == DBIT - 1)    // ya recibí todos los bits
                            state_next = STOP;
                        else
                            n_next = n_reg + 1;
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            STOP: begin
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin   // terminó el stop bit
                        state_next   = IDLE;
                        rx_done_tick = 1'b1;          // aviso: byte listo
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            default: state_next = IDLE;   // máquina segura: estado de recuperación

        endcase
    end

    // ------------------------------------------------------------------
    // Salida
    // ------------------------------------------------------------------
    assign dout = b_reg;

endmodule
