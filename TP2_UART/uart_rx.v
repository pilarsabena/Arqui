module uart_rx #(
        parameter DBIT = 8,          // # bits de datos
                  SB_TICK = 16       // # ticks para el/los stop bit(s)
    )
    (
        input  wire clk, reset,
        input  wire rx, s_tick,
        output reg  rx_done_tick,
        output wire [7:0] dout
    );

    // ---- constantes derivadas, para no usar números "mágicos" ----
    localparam TICKS_PER_BIT     = 16;                   // oversampling: 16 ticks por bit
    localparam START_BIT_MID     = (TICKS_PER_BIT/2) - 1; // = 7 -> mitad del start bit
    localparam LAST_TICK_OF_BIT  = TICKS_PER_BIT - 1;     // = 15 -> mitad de cada bit de dato
    localparam LAST_DATA_BIT_IDX = DBIT - 1;              // = 7 -> índice del último bit (0..7)
    localparam LAST_STOP_TICK    = SB_TICK - 1;           // último tick del/los stop bit(s)

    // symbolic state declaration
    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    // signal declaration (nombres más descriptivos)
    reg [1:0] state_reg, state_next;
    reg [3:0] tick_counter_reg, tick_counter_next;   // antes: s_reg, s_next
    reg [2:0] bit_counter_reg, bit_counter_next;     // antes: n_reg, n_next
    reg [7:0] shift_reg, shift_next;                 // antes: b_reg, b_next

    // FSMD: registros de estado y datos
    always @(posedge clk, posedge reset)
        if (reset)
            begin
                state_reg         <= IDLE;
                tick_counter_reg  <= 0;
                bit_counter_reg   <= 0;
                shift_reg         <= 0;
            end
        else
            begin
                state_reg         <= state_next;
                tick_counter_reg  <= tick_counter_next;
                bit_counter_reg   <= bit_counter_next;
                shift_reg         <= shift_next;
            end

    // FSMD: lógica de próximo estado
    always @*
    begin
        // valores por default: "no cambia nada"
        state_next        = state_reg;
        rx_done_tick       = 1'b0;
        tick_counter_next  = tick_counter_reg;
        bit_counter_next   = bit_counter_reg;
        shift_next         = shift_reg;

        case (state_reg)

            IDLE:
                // espera a que la línea baje a 0: ahí arranca el start bit
                if (~rx)
                    begin
                        state_next        = START;
                        tick_counter_next = 0;
                    end

            START:
                // cuenta ticks hasta llegar a la mitad del start bit
                if (s_tick)
                    if (tick_counter_reg == START_BIT_MID)
                        begin
                            state_next        = DATA;
                            tick_counter_next = 0;
                            bit_counter_next  = 0;
                        end
                    else
                        tick_counter_next = tick_counter_reg + 1;

            DATA:
                // cada 16 ticks (1 bit completo), captura un bit nuevo
                if (s_tick)
                    if (tick_counter_reg == LAST_TICK_OF_BIT)
                        begin
                            tick_counter_next = 0;
                            shift_next = {rx, shift_reg[7:1]};  // mete el bit nuevo por la izq.

                            if (bit_counter_reg == LAST_DATA_BIT_IDX)
                                state_next = STOP;       // ya se leyeron los 8 bits
                            else
                                bit_counter_next = bit_counter_reg + 1;
                        end
                    else
                        tick_counter_next = tick_counter_reg + 1;

            STOP:
                // espera los ticks del stop bit y avisa que el dato está listo
                if (s_tick)
                    if (tick_counter_reg == LAST_STOP_TICK)
                        begin
                            state_next   = IDLE;
                            rx_done_tick = 1'b1;
                        end
                    else
                        tick_counter_next = tick_counter_reg + 1;

        endcase
    end

    // output
    assign dout = shift_reg;

endmodule