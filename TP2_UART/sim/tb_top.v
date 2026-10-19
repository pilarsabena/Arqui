// ============================================================================
// Testbench 2: SISTEMA COMPLETO (top)
// ----------------------------------------------------------------------------
// El testbench hace de "PC": manda por RsRx los bytes A, B, OP en formato
// UART (bit a bit), después escucha RsTx, decodifica el byte de respuesta
// y lo compara con un modelo de referencia de la ALU.
//
// También verifica los flags en los LEDs (15 = Z, 14 = V, 13 = C, como en
// el TP1) y que la interfaz se resincronice sola por timeout si se pierde
// un byte.
//
// Shifts como la ALU del TP1 (estilo MIPS): se desplaza B, A indica cuántas
// posiciones (se usan los 3 bits bajos de A).
// ============================================================================
`timescale 1ns / 1ps

module tb_top;

    localparam CLK_FREQ = 100_000_000;
    localparam BRATE    = 625_000;                 // rápido SOLO para simular
    localparam N_TESTS  = 100;
    localparam TIMEOUT_MS = 1;                     // timeout corto SOLO para simular

    // Duración de un bit en ns: 1e9 / BRATE
    localparam real BIT_NS = 1.0e9 / BRATE;

    // Códigos de operación (los mismos del TP1)
    localparam [5:0] OP_ADD = 6'b100000,
                     OP_SUB = 6'b100010,
                     OP_AND = 6'b100100,
                     OP_OR  = 6'b100101,
                     OP_XOR = 6'b100110,
                     OP_SRA = 6'b000011,
                     OP_SRL = 6'b000010,
                     OP_NOR = 6'b100111;

    reg         clk  = 0;
    reg         btnC = 1;
    reg         RsRx = 1;          // línea en reposo = 1
    wire        RsTx;
    wire [15:0] led;

    reg  [7:0]  a, b, esperado, recibido;
    reg  [2:0]  flags_esp;                     // {C, V, Z} esperados
    reg  [5:0]  op;
    integer     i;
    integer     errores = 0;

    always #5 clk = ~clk;

    // --- Dispositivo bajo prueba ---
    // Timeout corto solo para simular (el top no tiene este parámetro)
    defparam dut.u_intf.TIMEOUT_MS = TIMEOUT_MS;

    top #(.CLK_FREQ(CLK_FREQ), .BRATE(BRATE)) dut (
        .clk(clk), .btnC(btnC), .RsRx(RsRx), .RsTx(RsTx), .led(led)
    );

    // ------------------------------------------------------------------
    // Task: la "PC" manda un byte por la línea RsRx
    // ------------------------------------------------------------------
    task uart_enviar(input [7:0] dato);
        integer k;
        begin
            RsRx = 1'b0;  #(BIT_NS);                 // start bit
            for (k = 0; k < 8; k = k + 1) begin
                RsRx = dato[k];  #(BIT_NS);          // datos, LSB primero
            end
            RsRx = 1'b1;  #(BIT_NS);                 // stop bit
        end
    endtask

    // ------------------------------------------------------------------
    // Task: la "PC" recibe un byte desde la línea RsTx
    // ------------------------------------------------------------------
    task uart_recibir(output [7:0] dato);
        integer k;
        begin
            @(negedge RsTx);                         // empieza el start bit
            #(BIT_NS / 2);                           // me paro en la mitad
            for (k = 0; k < 8; k = k + 1) begin
                #(BIT_NS);                           // mitad del bit k
                dato[k] = RsTx;
            end
            #(BIT_NS);                               // mitad del stop
            if (RsTx !== 1'b1) $display("  (aviso: stop bit inválido)");
        end
    endtask

    // ------------------------------------------------------------------
    // Modelo de referencia de la ALU
    // ------------------------------------------------------------------
    function [7:0] alu_modelo(input [7:0] x, input [7:0] y, input [5:0] o);
        case (o)
            OP_ADD: alu_modelo = x + y;
            OP_SUB: alu_modelo = x - y;
            OP_AND: alu_modelo = x & y;
            OP_OR : alu_modelo = x | y;
            OP_XOR: alu_modelo = x ^ y;
            OP_SRA: alu_modelo = $signed(y) >>> x[2:0];   // B desplazado A
            OP_SRL: alu_modelo = y >> x[2:0];
            OP_NOR: alu_modelo = ~(x | y);
            default: alu_modelo = 8'h00;
        endcase
    endfunction

    // Modelo de los flags: {carry, overflow, zero}
    function [2:0] flags_modelo(input [7:0] x, input [7:0] y, input [5:0] o, input [7:0] r);
        reg [8:0] t;
        reg c, v;
        begin
            c = 0; v = 0;
            if (o == OP_ADD) begin
                t = {1'b0, x} + {1'b0, y};
                c = t[8];
                v = (x[7] == y[7]) && (r[7] != x[7]);
            end
            else if (o == OP_SUB) begin
                t = {1'b0, x} - {1'b0, y};
                c = t[8];                                   // borrow
                v = (x[7] != y[7]) && (r[7] != x[7]);
            end
            flags_modelo = {c, v, (r == 8'h00)};
        end
    endfunction

    // Manda A, B, OP, recibe la respuesta y la verifica (resultado + LEDs)
    task operacion(input [7:0] xa, input [7:0] xb, input [5:0] xop, input integer id);
        begin
            esperado  = alu_modelo(xa, xb, xop);
            flags_esp = flags_modelo(xa, xb, xop, esperado);
            fork
                begin
                    uart_enviar(xa);
                    uart_enviar(xb);
                    uart_enviar({2'b00, xop});
                end
                uart_recibir(recibido);
            join
            if (recibido !== esperado || led[15:13] !== {flags_esp[0], flags_esp[1], flags_esp[2]} || led[7:0] !== esperado) begin
                $display("ERROR  test %0d: A=%h B=%h OP=%b -> esperado %h CVZ=%b, recibido %h LEDs CVZ=%b res=%h",
                         id, xa, xb, xop, esperado, flags_esp, recibido, {led[13], led[14], led[15]}, led[7:0]);
                errores = errores + 1;
            end
            else
                $display("OK     test %0d: A=%h B=%h OP=%b -> %h  CVZ=%b", id, xa, xb, xop, recibido, {led[13], led[14], led[15]});
            #(BIT_NS * 2);
        end
    endtask

    // Elige una operación válida al azar
    function [5:0] op_random(input integer r);
        case (r % 8)
            0: op_random = OP_ADD;  1: op_random = OP_SUB;
            2: op_random = OP_AND;  3: op_random = OP_OR;
            4: op_random = OP_XOR;  5: op_random = OP_SRA;
            6: op_random = OP_SRL;  default: op_random = OP_NOR;
        endcase
    endfunction

    // ------------------------------------------------------------------
    // Estímulos
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        #100 btnC = 0;
        #1000;

        // --- Casos con flags conocidos ---
        operacion(8'd25,  8'd17,  OP_ADD, 1000);   // CVZ = 000
        operacion(8'd5,   8'd5,   OP_SUB, 1001);   // Z
        operacion(8'd200, 8'd100, OP_ADD, 1002);   // C
        operacion(8'd100, 8'd50,  OP_ADD, 1003);   // V
        operacion(8'h80,  8'h80,  OP_ADD, 1004);   // C, V, Z
        operacion(8'h80,  8'd1,   OP_SUB, 1005);   // V
        operacion(8'd5,   8'd10,  OP_SUB, 1006);   // C (borrow)
        operacion(8'hCC,  8'h33,  OP_AND, 1007);   // Z

        // --- Recuperación por timeout: se "pierde" un byte ---
        $display("\n-- Mando solo A y B (se pierde OP) y espero el timeout --");
        uart_enviar(8'd7);
        uart_enviar(8'd3);
        #(TIMEOUT_MS * 1_000_000 * 1.5);           // espero 1,5 x timeout
        operacion(8'd40, 8'd2, OP_ADD, 2000);      // tiene que andar igual
        $display("");

        // --- Pruebas aleatorias ---
        for (i = 0; i < N_TESTS; i = i + 1) begin
            a  = $random;
            b  = $random;
            op = op_random($unsigned($random));
            if (op == OP_SRA || op == OP_SRL) a = a % 8;   // A = cantidad de posiciones
            operacion(a, b, op, i);
        end

        if (errores == 0) $display("\n*** SISTEMA OK: %0d/%0d operaciones correctas ***", N_TESTS, N_TESTS);
        else              $display("\n*** SISTEMA FALLÓ: %0d errores ***", errores);
        $finish;
    end

endmodule
