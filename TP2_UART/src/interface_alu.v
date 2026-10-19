// ============================================================================
// Interface Circuit (INTF) entre la UART y la ALU
// ----------------------------------------------------------------------------
// Protocolo: la PC manda 3 bytes en este orden ->  A, B, OP
// La interfaz los guarda en registros (que alimentan a la ALU), ordena al Tx
// que transmita el resultado y espera a que termine.
//
// Estados:
//   WAIT_A  : espero el 1er byte (operando A)                 -> WAIT_B
//   WAIT_B  : espero el 2do byte (operando B)                 -> WAIT_OP
//   WAIT_OP : espero el 3er byte (código de operación)        -> SEND
//   SEND    : en el 1er ciclo doy tx_start (pulso) y guardo el resultado;
//             me quedo acá hasta que el Tx avise tx_done_tick -> WAIT_TX
//   WAIT_TX : estado de transición, dura 1 ciclo               -> WAIT_A
//
// TIMEOUT: en WAIT_B, WAIT_OP y SEND, si pasan TIMEOUT_MS milisegundos sin
// que ocurra el evento esperado (byte o fin de transmisión), vuelvo a
// WAIT_A. Así la máquina nunca queda trabada si se pierde un byte.
//
// "Llegó un byte" = pulso rx_done_tick del receptor.
// ============================================================================
module interface_alu #(
    parameter NB_DATA    = 8,            // ancho de A, B y resultado
    parameter NB_OP      = 6,            // ancho del código de operación
    parameter CLK_FREQ   = 100_000_000,  // para calcular el timeout
    parameter TIMEOUT_MS = 500           // timeout: 0,5 s
) (
    input                       clk,
    input                       reset,

    // Desde el Rx
    input       [NB_DATA-1:0]   rx_data,
    input                       rx_done_tick,

    // Hacia / desde el Tx
    input                       tx_done_tick,
    output reg                  tx_start,
    output      [NB_DATA-1:0]   tx_data,

    // Hacia / desde la ALU
    output      [NB_DATA-1:0]   alu_a,
    output      [NB_DATA-1:0]   alu_b,
    output      [NB_OP-1:0]     alu_op,
    input       [NB_DATA-1:0]   alu_result,

    // Último resultado enviado (para mostrar en LEDs)
    output      [NB_DATA-1:0]   last_result
);

    // ------------------------------------------------------------------
    // Estados (codificación binaria, 3 bits)
    // ------------------------------------------------------------------
    localparam [2:0] WAIT_A  = 3'b000,
                     WAIT_B  = 3'b001,
                     WAIT_OP = 3'b010,
                     SEND    = 3'b011,
                     WAIT_TX = 3'b100;

    // Ciclos de clock del timeout: (100.000.000 / 1000) * 500 = 50.000.000
    localparam TIMEOUT_CYCLES = (CLK_FREQ / 1000) * TIMEOUT_MS;
    localparam NB_TIMER       = $clog2(TIMEOUT_CYCLES + 1);   // 26 bits

    // ------------------------------------------------------------------
    // Registros
    // ------------------------------------------------------------------
    reg [2:0]           state_reg,  state_next;
    reg [NB_DATA-1:0]   a_reg,      a_next;
    reg [NB_DATA-1:0]   b_reg,      b_next;
    reg [NB_OP-1:0]     op_reg,     op_next;
    reg [NB_DATA-1:0]   res_reg,    res_next;
    reg [NB_TIMER-1:0]  timer_reg,  timer_next;   // ciclos que llevo esperando

    // Timeout cumplido: pasaron 0,5 s en el estado actual
    wire timeout = (timer_reg == TIMEOUT_CYCLES - 1);

    // ------------------------------------------------------------------
    // Memoria
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state_reg <= WAIT_A;
            a_reg     <= 0;
            b_reg     <= 0;
            op_reg    <= 0;
            res_reg   <= 0;
            timer_reg <= 0;
        end
        else begin
            state_reg <= state_next;
            a_reg     <= a_next;
            b_reg     <= b_next;
            op_reg    <= op_next;
            res_reg   <= res_next;
            timer_reg <= timer_next;
        end
    end

    // ------------------------------------------------------------------
    // Lógica de próximo estado y salidas
    // ------------------------------------------------------------------
    always @(*) begin
        // Valores por defecto: me quedo como estoy
        state_next = state_reg;
        a_next     = a_reg;
        b_next     = b_reg;
        op_next    = op_reg;
        res_next   = res_reg;
        timer_next = 0;            // al cambiar de estado el timer arranca de 0
        tx_start   = 1'b0;

        case (state_reg)

            WAIT_A: begin
                if (rx_done_tick) begin
                    a_next     = rx_data;
                    state_next = WAIT_B;
                end
            end

            WAIT_B: begin
                if (rx_done_tick) begin
                    b_next     = rx_data;
                    state_next = WAIT_OP;
                end
                else if (timeout)
                    state_next = WAIT_A;          // timeout: descarto A
                else
                    timer_next = timer_reg + 1;
            end

            WAIT_OP: begin
                if (rx_done_tick) begin
                    op_next    = rx_data[NB_OP-1:0];  // uso los 6 bits bajos
                    state_next = SEND;
                end
                else if (timeout)
                    state_next = WAIT_A;          // timeout: descarto A y B
                else
                    timer_next = timer_reg + 1;
            end

            SEND: begin
                // 1er ciclo en SEND (timer en 0): A, B y OP ya están cargados,
                // la ALU ya tiene el resultado -> ordeno transmitir (pulso de
                // 1 ciclo) y guardo el resultado para los LEDs.
                if (timer_reg == 0) begin
                    tx_start = 1'b1;
                    res_next = alu_result;
                end

                // Me quedo en SEND hasta que el Tx termine la trama
                if (tx_done_tick)
                    state_next = WAIT_TX;
                else if (timeout)
                    state_next = WAIT_A;          // el Tx no terminó: aborto
                else
                    timer_next = timer_reg + 1;
            end

            WAIT_TX: begin
                // Estado de transición: dura 1 ciclo y vuelve al inicio
                state_next = WAIT_A;
            end

            default: state_next = WAIT_A;         // máquina segura

        endcase
    end

    // ------------------------------------------------------------------
    // Salidas
    // ------------------------------------------------------------------
    assign alu_a       = a_reg;
    assign alu_b       = b_reg;
    assign alu_op      = op_reg;
    assign tx_data     = alu_result;
    assign last_result = res_reg;

endmodule
