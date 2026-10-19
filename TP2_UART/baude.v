module baudio_generator #(
    parameter   CLK_FREQ = 100_000_000, // 100 MHz clk
    parameter   BRATE = 9600,
    parameter   OVERSAMPLING = 16
) (
    input       clk,
    input       enable,
    input       reset,
    output      tick_uart
);

    localparam BAUD_TICK_COUNT =  CLK_FREQ / (BRATE * OVERSAMPLING); // cada cuantos ciclos de clk estoy en el centro del bit para generar el tick

    reg [$clog2(BAUD_TICK_COUNT)-1:0] clk_counter; //contador para generar el tick de baud del tamaño de BAUD_TICK_COUNT. Es descendente

    always @(posedge clk ) begin
        if (reset) 
            clk_counter <= BAUD_TICK_COUNT - 1  ; //si se reseta el contador vuelve al original
        else if (enable)
            if (clk_counter == 0) 
                clk_counter <= BAUD_TICK_COUNT - 1 ; //si llegamos a cero reseteamos el contador
            else 
                clk_counter <= clk_counter - 1;    //sino vamos decrementando 
    end

    assign tick_uart = (clk_counter == 0);

endmodule

