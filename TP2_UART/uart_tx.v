module uart_tx #(
        parameter DBIT = 8,          // # bits de datos
                  SB_TICK = 16       // # ticks para el/los stop bit(s)
    )
    (
        input  wire clk, reset,
        input  wire tx_start, s_tick,
        input  wire [7:0] din,
        output reg  tx_done_tick,
        output wire tx
    );

    // ---- constantes derivadas, para no usar números "mágicos" ----
    localparam TICKS_PER_BIT     = 16;                   // oversampling: 16 ticks por bit
    localparam LAST_TICK_OF_BIT  = TICKS_PER_BIT - 1;     // = 15 -> se cumplió el bit completo
    localparam LAST_DATA_BIT_IDX = DBIT - 1;              // = 7 -> índice del último bit (0..7)
    localparam LAST_STOP_TICK    = SB_TICK - 1;           // último tick del/los stop bit(s)

    // symbolic state declaration
    localparam [1:0]
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11;

    // signal declaration (mismos nombres que en uart_rx, por consistencia)
    reg [1:0] state_reg, state_next;
    reg [3:0] tick_counter_reg, tick_counter_next;   // antes: s_reg, s_next
    reg [2:0] bit_counter_reg, bit_counter_next;     // antes: n_reg, n_next
    reg [7:0] shift_reg, shift_next;                 // antes: b_reg, b_next
    reg tx_line_reg, tx_line_next;                   // antes: tx_reg, tx_next (buffer anti-glitch)

    // FSMD: registros de estado y datos
    always @(posedge clk, posedge reset)
        if (reset)
            begin
                state_reg         <= IDLE;
                tick_counter_reg  <= 0;
                bit_counter_reg   <= 0;
                shift_reg         <= 0;
                tx_line_reg       <= 1'b1;      // línea en reposo = 1
            end
        else
            begin
                state_reg         <= state_next;
                tick_counter_reg  <= tick_counter_next;
                bit_counter_reg   <= bit_counter_next;
                shift_reg         <= shift_next;
                tx_line_reg       <= tx_line_next;
            end

    // FSMD: lógica de próximo estado y unidades funcionales
    always @*
    begin
        // valores por default: "no cambia nada"
        state_next        = state_reg;
        tx_done_tick       = 1'b0;
        tick_counter_next  = tick_counter_reg;
        bit_counter_next   = bit_counter_reg;
        shift_next         = shift_reg;
        tx_line_next       = tx_line_reg;

        case (state_reg)

            IDLE:
                begin
                    tx_line_next = 1'b1;               // mantiene la línea en reposo
                    if (tx_start)
                        begin
                            state_next        = START;
                            tick_counter_next = 0;
                            shift_next         = din;    // carga el byte a transmitir
                        end
                end

            START:
                begin
                    tx_line_next = 1'b0;                // saca el start bit (0)
                    if (s_tick)
                        if (tick_counter_reg == LAST_TICK_OF_BIT)
                            begin
                                state_next        = DATA;
                                tick_counter_next = 0;
                                bit_counter_next  = 0;
                            end
                        else
                            tick_counter_next = tick_counter_reg + 1;
                end

            DATA:
                begin
                    tx_line_next = shift_reg[0];        // saca el LSB actual del shift register
                    if (s_tick)
                        if (tick_counter_reg == LAST_TICK_OF_BIT)
                            begin
                                tick_counter_next = 0;
                                shift_next = shift_reg >> 1;   // corre para sacar el próximo bit

                                if (bit_counter_reg == LAST_DATA_BIT_IDX)
                                    state_next = STOP;          // ya se sacaron los 8 bits
                                else
                                    bit_counter_next = bit_counter_reg + 1;
                            end
                        else
                            tick_counter_next = tick_counter_reg + 1;
                end

            STOP:
                begin
                    tx_line_next = 1'b1;                // stop bit = 1
                    if (s_tick)
                        if (tick_counter_reg == LAST_STOP_TICK)
                            begin
                                state_next   = IDLE;
                                tx_done_tick = 1'b1;
                            end
                        else
                            tick_counter_next = tick_counter_reg + 1;
                end

        endcase
    end

    // output
    assign tx = tx_line_reg;

endmodule
