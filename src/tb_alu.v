
`timescale 1ns/1ps
// escala de tiempo del simulador: 1ns es la unidad, 1ps la precisión.


module tb_alu;
// Un testbench NO tiene puertos (sin input/output) porque no va a ninguna placa, solo corre en simulación.

    localparam NB_DATA = 8;
    localparam NB_OP   = 6;
    localparam NB_SHIFT = $clog2(NB_DATA);


    reg  signed [NB_DATA-1:0] i_a, i_b;   // señales que YO controlo 
    reg         [NB_OP-1:0]   i_op;       
    wire signed [NB_DATA-1:0] o_alu;    

    reg  signed [NB_DATA-1:0] esperado;   
    integer casos = 0;                    
    integer errores = 0;                 

    alu #(.NB_DATA(NB_DATA), .NB_OP(NB_OP)) dut (
        .i_a(i_a), .i_b(i_b), .i_op(i_op), .o_alu(o_alu)
    );

    task alu_task;
        input signed [NB_DATA-1:0] a, b;  // lo que este task recibe cuando lo llamo
        input        [NB_OP-1:0]   op;
        begin
            i_a = a; i_b = b; i_op = op;
          
            #1;

            case (op)
                
                6'b100000: esperado = a + b;      // ADD
                6'b100010: esperado = a - b;      // SUB
                6'b100100: esperado = a & b;      // AND
                6'b100101: esperado = a | b;      // OR
                6'b100110: esperado = a ^ b;      // XOR
                6'b100111: esperado = ~(a | b);   // NOR
                6'b000011: esperado = a >>> b[NB_SHIFT-1:0];   // SRA
                6'b000010: esperado = a >>  b[NB_SHIFT-1:0];   // SRL

                default:   esperado = {NB_DATA{1'bx}};
            endcase

            casos = casos + 1;  

            if (o_alu !== esperado) begin
                // !== compara también los bits x/z, no solo 0 y 1 (!= no los detecta)
                errores = errores + 1;
                $display("ERROR caso %0d: op=%b a=%0d b=%0d esperado=%0d obtenido=%0d",
                          casos, op, a, b, esperado, o_alu);
                // $display imprime esta línea en la consola de simulación, como un print
            end
        end
    endtask

    integer i;   // variable auxiliar solo para contar el for, no tiene nada que ver con la ALU

    initial begin
        

        for (i = 0; i < 100; i = i + 1) begin
        
            alu_task($random, $random, 6'b100000); // ADD
            alu_task($random, $random, 6'b100010); // SUB
            alu_task($random, $random, 6'b100100); // AND
            alu_task($random, $random, 6'b100101); // OR
            alu_task($random, $random, 6'b100110); // XOR
            alu_task($random, $random, 6'b100111); // NOR
            alu_task($random, $random, 6'b000011); // SRA
            alu_task($random, $random, 6'b000010); // SRL

        end

        $display("Casos: %0d  Errores: %0d", casos, errores);

        $finish; 
    end

endmodule
