module alu #(
    parameter NB_DATA = 8,
    parameter NB_OP   = 6,
    localparam NB_SHIFT = $clog2(NB_DATA)
)
(
    input  wire signed [NB_DATA-1:0] i_a,
    input  wire signed [NB_DATA-1:0] i_b,
    input  wire        [NB_OP-1:0]   i_op,
    output reg  signed [NB_DATA-1:0] o_alu
);

always @(*) begin
    case (i_op)
        // código           acción                     operación
        6'b100000 : o_alu = i_a + i_b;              // ADD
        6'b100010 : o_alu = i_a - i_b;              // SUB
        6'b100100 : o_alu = i_a & i_b;              // AND
        6'b100101 : o_alu = i_a | i_b;              // OR
        6'b100110 : o_alu = i_a ^ i_b;              // XOR
        6'b000011 : o_alu = i_a >>> i_b[NB_SHIFT-1:0]; // SRA
        6'b000010 : o_alu = i_a >>  i_b[NB_SHIFT-1:0]; // SRL
        6'b100111 : o_alu = ~(i_a | i_b);            // NOR
        default   : o_alu = {NB_DATA{1'bx}};
    endcase
    end

endmodule