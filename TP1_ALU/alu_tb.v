
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Testbench autoverificable para el modulo "alu"
//  - Casos dirigidos (esquinas: overflow, cero, todo unos, etc.)
//  - Barrido de las 8 operaciones con datos aleatorios
//  - Bateria grande de estimulos aleatorios adicionales
//  - Modelo de referencia (funcion "expected_result") que calcula el valor
//    esperado y se compara automaticamente contra la salida del DUT
//  - Contador de errores y reporte final PASA/FALLA
//////////////////////////////////////////////////////////////////////////////

module alu_tb;

    localparam integer DATA_WIDTH       = 32;
    localparam integer NUM_RANDOM_TESTS = 500;
    localparam integer STEP             = 10; // ns entre estimulos (para ver en el waveform)

    localparam [5:0] OP_ADD = 6'b100000;
    localparam [5:0] OP_SUB = 6'b100010;
    localparam [5:0] OP_AND = 6'b100100;
    localparam [5:0] OP_OR  = 6'b100101;
    localparam [5:0] OP_XOR = 6'b100110;
    localparam [5:0] OP_SRA = 6'b000011;
    localparam [5:0] OP_SRL = 6'b000010;
    localparam [5:0] OP_NOR = 6'b100111;

    localparam integer NUM_OPS = 8;
    reg [5:0] op_table [0:NUM_OPS-1];

    localparam integer SHAMT_WIDTH = $clog2(DATA_WIDTH);

    reg  [DATA_WIDTH-1:0] a, b;
    reg  [5:0]             op;
    wire [DATA_WIDTH-1:0] result;
    wire                   zero;
    wire                   overflow;
    wire                   carry;

    integer tests  = 0;
    integer errors = 0;
    integer i, j;

    // -----------------------------------------------------------------
    // Instancia del DUT
    // -----------------------------------------------------------------
    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .zero(zero),
        .overflow(overflow),
        .carry(carry)
    );

    // -----------------------------------------------------------------
    // Tabla de operaciones validas (para elegir aleatoriamente entre ellas)
    // -----------------------------------------------------------------
    initial begin
        op_table[0] = OP_ADD;
        op_table[1] = OP_SUB;
        op_table[2] = OP_AND;
        op_table[3] = OP_OR;
        op_table[4] = OP_XOR;
        op_table[5] = OP_SRA;
        op_table[6] = OP_SRL;
        op_table[7] = OP_NOR;
    end

    // -----------------------------------------------------------------
    // Modelo de referencia: calcula el resultado esperado en software
    // -----------------------------------------------------------------
    function [DATA_WIDTH-1:0] expected_result;
        input [DATA_WIDTH-1:0] ta;
        input [DATA_WIDTH-1:0] tb;
        input [5:0]            top;
        reg   [SHAMT_WIDTH-1:0] shamt;
        begin
            shamt = ta[SHAMT_WIDTH-1:0];
            case (top)
                OP_ADD:  expected_result = ta + tb;
                OP_SUB:  expected_result = ta - tb;
                OP_AND:  expected_result = ta & tb;
                OP_OR:   expected_result = ta | tb;
                OP_XOR:  expected_result = ta ^ tb;
                OP_NOR:  expected_result = ~(ta | tb);
                OP_SRL:  expected_result = tb >> shamt;
                OP_SRA:  expected_result = $signed(tb) >>> shamt;
                default: expected_result = {DATA_WIDTH{1'b0}};
            endcase
        end
    endfunction

    // -----------------------------------------------------------------
    // Tarea que aplica un estimulo, espera la propagacion combinacional
    // y compara automaticamente contra el modelo de referencia
    // -----------------------------------------------------------------
    task automatic run_test(input [DATA_WIDTH-1:0] ta,
                             input [DATA_WIDTH-1:0] tb,
                             input [5:0]            top);
        reg [DATA_WIDTH-1:0] exp;
        reg                  exp_zero;
        begin
            a  = ta;
            b  = tb;
            op = top;
            #(STEP);

            exp      = expected_result(ta, tb, top);
            exp_zero = (exp == {DATA_WIDTH{1'b0}});
            tests    = tests + 1;

            if ((result !== exp) || (zero !== exp_zero)) begin
                errors = errors + 1;
                $display("[%0t ns] FALLO  op=%b a=%h b=%h -> result=%h (esperado=%h) zero=%b (esperado=%b)",
                          $time, top, ta, tb, result, exp, zero, exp_zero);
            end else begin
                $display("[%0t ns] OK     op=%b a=%h b=%h -> result=%h zero=%b carry=%b overflow=%b",
                          $time, top, ta, tb, result, zero, carry, overflow);
            end
        end
    endtask

    // -----------------------------------------------------------------
    // Secuencia principal de estimulos
    // -----------------------------------------------------------------
    reg [DATA_WIDTH-1:0] ra, rb;
    integer               rop_idx;

    initial begin
        a = 0; b = 0; op = 0;
        #(STEP);

        $display("=====================================================");
        $display(" INICIO DEL TESTBENCH - ALU DATA_WIDTH=%0d", DATA_WIDTH);
        $display("=====================================================");

        // ---- Casos dirigidos (esquinas conocidas) ----
        run_test(32'h0000_0000, 32'h0000_0000, OP_ADD); // 0+0=0 -> zero=1
        run_test(32'h7FFF_FFFF, 32'h0000_0001, OP_ADD); // overflow positivo
        run_test(32'h8000_0000, 32'hFFFF_FFFF, OP_SUB); // overflow negativo
        run_test(32'hFFFF_FFFF, 32'h0000_0001, OP_ADD); // wrap sin overflow (signos distintos)
        run_test(32'hAAAA_AAAA, 32'hAAAA_AAAA, OP_XOR); // resultado 0 -> zero=1
        run_test(32'hFFFF_FFFF, 32'hFFFF_FFFF, OP_NOR); // NOR de todos unos = 0
        run_test(32'h8000_0001, 32'h0000_0004, OP_SRA); // corrimiento aritmetico, MSB=1
        run_test(32'h8000_0001, 32'h0000_0004, OP_SRL); // corrimiento logico, MSB=1
        run_test(32'hF0F0_F0F0, 32'h0F0F_0F0F, OP_AND);
        run_test(32'hF0F0_F0F0, 32'h0F0F_0F0F, OP_OR);

        // ---- Barrido de las 8 operaciones con datos pseudoaleatorios ----
        for (j = 0; j < NUM_OPS; j = j + 1) begin
            run_test($random, $random, op_table[j]);
        end

        // ---- Generacion aleatoria masiva ----
        for (i = 0; i < NUM_RANDOM_TESTS; i = i + 1) begin
            ra      = {$random, $random};
            rb      = {$random, $random};
            rop_idx = $unsigned($random) % NUM_OPS;
            run_test(ra, rb, op_table[rop_idx]);
        end

        // ---- Reporte final ----
        $display("=====================================================");
        $display(" TOTAL DE PRUEBAS : %0d", tests);
        $display(" ERRORES          : %0d", errors);
        if (errors == 0)
            $display(" RESULTADO: TODAS LAS PRUEBAS PASARON (PASS)");
        else
            $display(" RESULTADO: %0d PRUEBAS FALLARON (FAIL)", errors);
        $display("=====================================================");

        if (errors != 0)
            $fatal(1, "El testbench detecto errores en la ALU");

        $finish;
    end

endmodule