// ============================================================================
// Baud Rate Generator
// ----------------------------------------------------------------------------
// Genera un pulso (tick) de UN ciclo de clock cada BAUD_TICK_COUNT ciclos.
// Ese tick NO es un clock: es una señal de enable que usan Rx y Tx.
// Hay OVERSAMPLING (16) ticks por cada bit de la trama.
//
// Fórmula (filmina / libro sección 8.2.2):
//      BAUD_TICK_COUNT = CLK_FREQ / (BRATE * OVERSAMPLING)
//      100 MHz / (9600 * 16) = 651,04  -> 651
// ============================================================================
module baudio_generator #(
    parameter   CLK_FREQ     = 100_000_000, // 100 MHz (clock de la Basys3)
    parameter   BRATE        = 9600,        // baudios
    parameter   OVERSAMPLING = 16           // ticks por bit
) (
    input       clk,
    input       reset,
    input       enable,
    output      tick_uart
);

    // Cada cuántos ciclos de clk pasa 1/16 de bit.
    // Se suma la mitad del divisor para REDONDEAR en vez de truncar
    // (ej: 19200 baud -> 325,52 -> 326 en lugar de 325).
    localparam BAUD_TICK_COUNT = (CLK_FREQ + (BRATE * OVERSAMPLING) / 2)
                                 / (BRATE * OVERSAMPLING);

    // Contador descendente: va de BAUD_TICK_COUNT-1 hasta 0
    reg [$clog2(BAUD_TICK_COUNT)-1:0] clk_counter;

    always @(posedge clk) begin
        if (reset)
            clk_counter <= BAUD_TICK_COUNT - 1;      // vuelve al valor inicial
        else if (enable) begin
            if (clk_counter == 0)
                clk_counter <= BAUD_TICK_COUNT - 1;  // llegó a 0: recarga
            else
                clk_counter <= clk_counter - 1;      // sino, decrementa
        end
    end

    // El tick solo vale si el generador está habilitado
    // (evita que quede clavado en 1 si enable baja con el contador en 0)
    assign tick_uart = enable && (clk_counter == 0);

endmodule
