
//////////////////////////////////////////////////////////////////////////////
// ALU parametrizable (ancho de bus configurable)
//
// Codigos de operacion (formato tipo funct de MIPS, 6 bits):
//   ADD  100000
//   SUB  100010
//   AND  100100
//   OR   100101
//   XOR  100110
//   SRA  000011
//   SRL  000010
//   NOR  100111
//
// Para SRA/SRL se desplaza el operando B en una cantidad dada por los bits
// bajos de A (A[SHAMT_WIDTH-1:0]), donde SHAMT_WIDTH = ceil(log2(DATA_WIDTH)).
// Esta convencion es la habitual cuando no hay un campo "shamt" separado.
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module alu #(
    parameter integer DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    input  wire [5:0]            op,
    output reg  [DATA_WIDTH-1:0] result,
    output wire                  zero,
    output reg                   overflow,
    output reg                   carry
);

    localparam [5:0] OP_ADD = 6'b100000;
    localparam [5:0] OP_SUB = 6'b100010;
    localparam [5:0] OP_AND = 6'b100100;
    localparam [5:0] OP_OR  = 6'b100101;
    localparam [5:0] OP_XOR = 6'b100110;
    localparam [5:0] OP_SRA = 6'b000011;
    localparam [5:0] OP_SRL = 6'b000010;
    localparam [5:0] OP_NOR = 6'b100111;

    localparam integer SHAMT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

    wire [SHAMT_WIDTH-1:0] shamt = a[SHAMT_WIDTH-1:0];

    wire [DATA_WIDTH:0] add_ext = {1'b0, a} + {1'b0, b};
    wire [DATA_WIDTH:0] sub_ext = {1'b0, a} + {1'b0, ~b} + 1'b1;

    always @(*) begin
        result   = {DATA_WIDTH{1'b0}};
        overflow = 1'b0;
        carry    = 1'b0;
        case (op)
            OP_ADD: begin
                result   = add_ext[DATA_WIDTH-1:0];
                carry    = add_ext[DATA_WIDTH];
                overflow = (a[DATA_WIDTH-1] == b[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end
            OP_SUB: begin
                result   = sub_ext[DATA_WIDTH-1:0];
                carry    = sub_ext[DATA_WIDTH]; // 1 = no hubo prestamo (a >= b sin signo)
                overflow = (a[DATA_WIDTH-1] != b[DATA_WIDTH-1]) &&
                           (result[DATA_WIDTH-1] != a[DATA_WIDTH-1]);
            end
            OP_AND:  result = a & b;
            OP_OR:   result = a | b;
            OP_XOR:  result = a ^ b;
            OP_NOR:  result = ~(a | b);
            OP_SRL:  result = b >> shamt;
            OP_SRA:  result = $signed(b) >>> shamt;
            default: result = {DATA_WIDTH{1'b0}};
        endcase
    end

    assign zero = (result == {DATA_WIDTH{1'b0}});

endmodule