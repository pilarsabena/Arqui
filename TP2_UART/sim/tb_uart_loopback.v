// ============================================================================
// Testbench 1: LOOPBACK Tx -> Rx
// ----------------------------------------------------------------------------
// Conecta la salida tx del transmisor a la entrada rx del receptor.
// Manda N_TESTS bytes aleatorios y verifica automáticamente que cada byte
// recibido sea igual al enviado.
//
// Para que la simulación sea rápida se usa un BRATE alto (625000):
//   100 MHz / (625000 * 16) = 10 ciclos por tick.
// La lógica es la misma que a 9600, solo cambia el divisor.
// ============================================================================
`timescale 1ns / 1ps

module tb_uart_loopback;

    localparam CLK_FREQ = 100_000_000;
    localparam BRATE    = 625_000;       // rápido SOLO para simular
    localparam N_TESTS  = 50;

    reg         clk = 0;
    reg         reset = 1;
    reg         tx_start = 0;
    reg  [7:0]  tx_data = 0;

    wire        tick;
    wire        serial_line;             // el "cable" entre tx y rx
    wire        tx_done_tick;
    wire        rx_done_tick;
    wire [7:0]  rx_data;

    integer     i;
    integer     errores = 0;

    always #5 clk = ~clk;                // 100 MHz

    // --- Dispositivos bajo prueba ---
    baudio_generator #(.CLK_FREQ(CLK_FREQ), .BRATE(BRATE)) u_baud (
        .clk(clk), .reset(reset), .enable(1'b1), .tick_uart(tick)
    );

    uart_tx u_tx (
        .clk(clk), .reset(reset), .tx_start(tx_start), .s_tick(tick),
        .din(tx_data), .tx_done_tick(tx_done_tick), .tx(serial_line)
    );

    uart_rx u_rx (
        .clk(clk), .reset(reset), .rx(serial_line), .s_tick(tick),
        .rx_done_tick(rx_done_tick), .dout(rx_data)
    );

    // --- Estímulos y chequeo ---
    initial begin
        $dumpfile("tb_uart_loopback.vcd");
        $dumpvars(0, tb_uart_loopback);

        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        for (i = 0; i < N_TESTS; i = i + 1) begin
            // 1) cargo un byte aleatorio y doy un pulso de tx_start
            @(posedge clk);
            tx_data  <= $random;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;

            // 2) espero que el receptor avise que llegó
            @(posedge rx_done_tick);
            @(negedge clk);
            if (rx_data !== tx_data) begin
                $display("ERROR  test %0d: enviado %h, recibido %h", i, tx_data, rx_data);
                errores = errores + 1;
            end
            else
                $display("OK     test %0d: %h", i, rx_data);

            // 3) espero que el transmisor termine antes del próximo
            @(posedge tx_done_tick);
        end

        if (errores == 0) $display("\n*** LOOPBACK OK: %0d/%0d bytes correctos ***", N_TESTS, N_TESTS);
        else              $display("\n*** LOOPBACK FALLÓ: %0d errores ***", errores);
        $finish;
    end

endmodule
