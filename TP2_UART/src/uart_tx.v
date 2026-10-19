// ============================================================================
// UART Transmisor (Tx)
// ----------------------------------------------------------------------------
// Adaptado del Listing 8.3 de Pong P. Chu.
// Usa el MISMO tick que el Rx (16 por bit), así que mantiene cada bit
// en la línea durante 16 ticks.
//
//   - IDLE : línea en 1, espera tx_start y carga el byte
//   - START: pone 0 durante 16 ticks
//   - DATA : saca b[0] y desplaza a la derecha, DBIT veces (LSB primero)
//   - STOP : pone 1 durante SB_TICK ticks y avisa que terminó
// ============================================================================
module uart_tx #(
    parameter DBIT    = 8,
    parameter SB_TICK = 16
) (
    input                   clk,
    input                   reset,
    input                   tx_start,      // pulso: empezar a transmitir din
    input                   s_tick,        // tick del baud rate generator
    input      [DBIT-1:0]   din,           // byte a transmitir
    output reg              tx_done_tick,  // pulso de 1 ciclo: terminó
    output                  tx             // línea serie de salida
);

    // ------------------------------------------------------------------
    // Estados
    // ------------------------------------------------------------------
    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    // ------------------------------------------------------------------
    // Registros
    // ------------------------------------------------------------------
    reg [1:0]               state_reg, state_next;
    reg [3:0]               s_reg,     s_next;     // cuenta ticks
    reg [$clog2(DBIT)-1:0]  n_reg,     n_next;     // cuenta bits enviados
    reg [DBIT-1:0]          b_reg,     b_next;     // byte que se va desplazando
    reg                     tx_reg,    tx_next;    // salida registrada (sin glitches)

    // ------------------------------------------------------------------
    // Memoria
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 0;
            n_reg     <= 0;
            b_reg     <= 0;
            tx_reg    <= 1'b1;     // línea en reposo = 1
        end
        else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            tx_reg    <= tx_next;
        end
    end

    // ------------------------------------------------------------------
    // Lógica de próximo estado y salidas
    // ------------------------------------------------------------------
    always @(*) begin
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        tx_next      = tx_reg;
        tx_done_tick = 1'b0;

        case (state_reg)

            IDLE: begin
                tx_next = 1'b1;               // reposo
                if (tx_start) begin
                    state_next = START;
                    s_next     = 0;
                    b_next     = din;         // guardo el byte a enviar
                end
            end

            START: begin
                tx_next = 1'b0;               // start bit
                if (s_tick) begin
                    if (s_reg == 15) begin    // pasó un bit completo
                        state_next = DATA;
                        s_next     = 0;
                        n_next     = 0;
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            DATA: begin
                tx_next = b_reg[0];           // bit actual (LSB primero)
                if (s_tick) begin
                    if (s_reg == 15) begin
                        s_next = 0;
                        b_next = b_reg >> 1;  // preparo el siguiente bit
                        if (n_reg == DBIT - 1)
                            state_next = STOP;
                        else
                            n_next = n_reg + 1;
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            STOP: begin
                tx_next = 1'b1;               // stop bit
                if (s_tick) begin
                    if (s_reg == SB_TICK - 1) begin
                        state_next   = IDLE;
                        tx_done_tick = 1'b1;
                    end
                    else
                        s_next = s_reg + 1;
                end
            end

            default: state_next = IDLE;       // máquina segura

        endcase
    end

    assign tx = tx_reg;

endmodule
