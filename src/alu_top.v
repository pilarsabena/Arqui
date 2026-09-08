module alu_top (
    input  wire        i_clk,        // oscilador de 100MHz de la placa (pin W5)
    input  wire        i_reset,      // botón BTNU
    input  wire        i_load_a,     // botón BTND
    input  wire        i_load_b,     // botón BTNR
    input  wire        i_load_c,     // botón BTNL (carga el opcode)
    input  wire [7:0]  i_switches,   // SW8 a SW15 de la placa
    output wire [7:0]  o_leds        // LD8 a LD15
);

    localparam NB_DATA = 8;
    localparam NB_OP   = 6;

    reg signed [NB_DATA-1:0] r_a;
    reg signed [NB_DATA-1:0] r_b;
    reg        [NB_OP-1:0]   r_op;

    always @(posedge i_clk) begin
        if (i_reset) begin
            r_a  <= {NB_DATA{1'b0}};
            r_b  <= {NB_DATA{1'b0}};
            r_op <= {NB_OP{1'b0}};
        end else begin
           
            if (i_load_a) r_a  <= i_switches;
            if (i_load_b) r_b  <= i_switches;
            if (i_load_c) r_op <= i_switches[NB_OP-1:0];
        end
    end

    wire signed [NB_DATA-1:0] w_alu_out;

    alu #(
        .NB_DATA(NB_DATA),
        .NB_OP(NB_OP)
    ) u_alu (
        .i_a(r_a),
        .i_b(r_b),
        .i_op(r_op),
        .o_alu(w_alu_out)
    );


    assign o_leds = w_alu_out;

endmodule
