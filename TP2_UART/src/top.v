// ============================================================================
// TOP: Baud Rate Generator + Rx + Tx + Interface + ALU del TP1
// ----------------------------------------------------------------------------
// Conexiones (igual que la filmina "TP: UART"):
//
//   RsRx --> [Rx] --rx_data/rx_done--> [INTF] --A,B,OP--> [ALU]
//                                         ^                  |
//                                         +---- resultado ---+
//   RsTx <-- [Tx] <--tx_data/tx_start--- [INTF]
//
//   [Baud Rate Generator] --tick--> Rx y Tx (como ENABLE, no como clock)
//
// LEDs (igual que en el TP1):
//   15 = Zero   14 = Overflow   13 = Carry   12..8 = apagados
//   7..0 = resultado de la última operación
//
// Los flags salen directo de la ALU del TP1. Como A, B y OP vienen de los
// registros de la interfaz (que quedan fijos después de cada operación),
// los flags también quedan fijos y corresponden a la última operación.
// ============================================================================
module top #(
    parameter CLK_FREQ = 100_000_000,
    parameter BRATE    = 9600,
    parameter NB_DATA  = 8,
    parameter NB_OP    = 6
) (
    input               clk,      // 100 MHz
    input               btnC,     // reset (botón central)
    input               RsRx,     // desde la PC (USB-UART)
    output              RsTx,     // hacia la PC
    output      [15:0]  led
);

    // Señales internas
    wire                tick;
    wire [NB_DATA-1:0]  rx_data;
    wire                rx_done_tick;
    wire [NB_DATA-1:0]  tx_data;
    wire                tx_start;
    wire                tx_done_tick;
    wire [NB_DATA-1:0]  alu_a, alu_b, alu_result, last_result;
    wire [NB_OP-1:0]    alu_op;
    wire                zero, overflow, carry;   // flags de la ALU del TP1

    wire reset = btnC;

    // ------------------------------------------------------------------
    baudio_generator #(
        .CLK_FREQ     (CLK_FREQ),
        .BRATE        (BRATE),
        .OVERSAMPLING (16)
    ) u_baud (
        .clk       (clk),
        .reset     (reset),
        .enable    (1'b1),
        .tick_uart (tick)
    );

    // ------------------------------------------------------------------
    uart_rx #(
        .DBIT    (NB_DATA),
        .SB_TICK (16)
    ) u_rx (
        .clk          (clk),
        .reset        (reset),
        .rx           (RsRx),
        .s_tick       (tick),
        .rx_done_tick (rx_done_tick),
        .dout         (rx_data)
    );

    // ------------------------------------------------------------------
    uart_tx #(
        .DBIT    (NB_DATA),
        .SB_TICK (16)
    ) u_tx (
        .clk          (clk),
        .reset        (reset),
        .tx_start     (tx_start),
        .s_tick       (tick),
        .din          (tx_data),
        .tx_done_tick (tx_done_tick),
        .tx           (RsTx)
    );

    // ------------------------------------------------------------------
    interface_alu #(
        .NB_DATA (NB_DATA),
        .NB_OP   (NB_OP)
    ) u_intf (
        .clk          (clk),
        .reset        (reset),
        .rx_data      (rx_data),
        .rx_done_tick (rx_done_tick),
        .tx_done_tick (tx_done_tick),
        .tx_start     (tx_start),
        .tx_data      (tx_data),
        .alu_a        (alu_a),
        .alu_b        (alu_b),
        .alu_op       (alu_op),
        .alu_result   (alu_result),
        .last_result  (last_result)
    );

    // ------------------------------------------------------------------
    // ALU DEL TP1 (calcula el resultado y los flags)
    alu #(
        .DATA_WIDTH (NB_DATA)
    ) u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .op       (alu_op),
        .result   (alu_result),
        .zero     (zero),
        .overflow (overflow),
        .carry    (carry)
    );

    // ------------------------------------------------------------------
    // LEDs (como en el TP1): [15] zero, [14] overflow, [13] carry,
    //                        [7:0] resultado de la última operación
    assign led = {zero, overflow, carry, 5'b00000, last_result};

endmodule
