
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
// Top level para Basys3 con carga de operandos por botones.
//
//   SW[7:0]   -> bus de datos compartido, se carga en A o B segun el boton
//   SW[13:8]  -> codigo de operacion (6 bits)
//   btnL      -> carga SW[7:0] en el registro A
//   btnR      -> carga SW[7:0] en el registro B
//   LED[7:0]  -> resultado
//   LED[13]   -> carry
//   LED[14]   -> overflow
//   LED[15]   -> zero
//////////////////////////////////////////////////////////////////////////////

module top_alu #(
    parameter integer DATA_WIDTH = 8
)(
    input  wire                    clk,
    input  wire                    btn_load_a,
    input  wire                    btn_load_b,
    input  wire [DATA_WIDTH-1:0]   sw_data,
    input  wire [5:0]              sw_op,
    output wire [DATA_WIDTH-1:0]   led_result,
    output wire                    led_carry,
    output wire                    led_overflow,
    output wire                    led_zero
);

    reg [DATA_WIDTH-1:0] reg_a, reg_b;
    reg btn_a_prev, btn_b_prev;

    // Deteccion de flanco ascendente: carga el registro una sola vez por
    // pulsacion, no en cada ciclo de clock mientras el boton esta apretado.
    always @(posedge clk) begin
        btn_a_prev <= btn_load_a;
        btn_b_prev <= btn_load_b;

        if (btn_load_a && !btn_a_prev)
            reg_a <= sw_data;

        if (btn_load_b && !btn_b_prev)
            reg_b <= sw_data;
    end

    wire [DATA_WIDTH-1:0] result;
    wire                   zero;
    wire                   overflow;
    wire                   carry;

    alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_alu (
        .a(reg_a),
        .b(reg_b),
        .op(sw_op),
        .result(result),
        .zero(zero),
        .overflow(overflow),
        .carry(carry)
    );

    assign led_result   = result;
    assign led_carry    = carry;
    assign led_overflow = overflow;
    assign led_zero     = zero;

endmodule