# Trabajo Práctico N°1 — ALU

**Materia:** Arquitectura de Computadoras
**Alumnas:** María Candela Benavides y María Pilar Sabena 

---

## 1. Objetivo

Implementar en FPGA una Unidad Aritmético-Lógica (ALU) parametrizable en el ancho del
bus de datos. El diseño se valida mediante un testbench autoverificable con generación de estímulos
aleatorios, y se simula con las herramientas de Vivado, incluyendo un análisis de
tiempos (timing analysis) de la implementación.

## 2. Operaciones soportadas

La ALU implementa 8 operaciones, identificadas con un código de 6 bits (formato tipo
`funct` de MIPS):

| Operación | Código  | Descripción                                  |
|-----------|---------|-----------------------------------------------|
| ADD       | 100000  | Suma de `a` y `b`                              |
| SUB       | 100010  | Resta `a - b`                                  |
| AND       | 100100  | AND bit a bit                                  |
| OR        | 100101  | OR bit a bit                                   |
| XOR       | 100110  | XOR bit a bit                                  |
| SRA       | 000011  | Corrimiento aritmético a derecha de `b`        |
| SRL       | 000010  | Corrimiento lógico a derecha de `b`            |
| NOR       | 100111  | NOR bit a bit                                  |

Para las operaciones de corrimiento (SRA/SRL) la
cantidad de corrimiento y qué operando es el que efectivamente se desplaza. En este
diseño, **`b`** es el valor que se corre y **`a`** es quien indica cuánto correrlo

## 3. Diseño del módulo `alu`

Archivo: [alu.v](alu.v)

```verilog
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
```

### 3.1 Parametrización

El ancho del bus de datos se define con el parámetro `DATA_WIDTH` (por defecto 32
bits). Todas las señales internas (operandos, resultado, cantidad de corrimiento)
escalan automáticamente en función de este parámetro, lo que permite instanciar la
ALU con cualquier ancho de bus (por ejemplo, 8 bits en el `top_alu` para la placa
Basys3, o 32 bits para el uso en un datapath tipo MIPS en el trabajo final) sin
modificar el código fuente.

El ancho del campo de corrimiento (`SHAMT_WIDTH`) se calcula automáticamente con
`$clog2(DATA_WIDTH)`, de modo que también escala junto con `DATA_WIDTH`.

### 3.2 Lógica combinacional

Toda la ALU es puramente combinacional (bloque `always @(*)`), seleccionada por
`case (op)`:

- **ADD/SUB**: se implementan con un sumador extendido en un bit
  (`add_ext` / `sub_ext`) para poder derivar el `carry` de salida. La resta se
  calcula como complemento a dos (`a + ~b + 1`).
- **AND / OR / XOR / NOR**: operaciones lógicas bit a bit directas.
- **SRL**: corrimiento lógico de `b` a la derecha, cantidad dada por `shamt`.
- **SRA**: corrimiento aritmético de `b` a la derecha (`$signed(b) >>> shamt`),
  preservando el signo.

### 3.3 Flags de salida

- **`zero`**: `1` si `result == 0`. Se calcula con un `assign` continuo a partir de
  `result`, por lo que es válido para cualquier operación.
- **`carry`**: acarreo de salida del sumador/restador extendido. Para `SUB`
  representa "no hubo préstamo" (`a >= b` sin signo). Para el resto de las
  operaciones se fuerza a `0`, ya que no aplica.
- **`overflow`**: overflow aritmético con signo, calculado con la condición
  clásica de overflow de complemento a dos (los signos de los operandos
  correspondientes coinciden entre sí y difieren del signo del resultado). Se
  calcula solo para `ADD` y `SUB`; en el resto de las operaciones se fuerza a `0`.

## 4. Verificación con Testbench

Archivo: [alu_tb.v](alu_tb.v)

El testbench es autoverificable (self-checking): no requiere inspección manual de
las formas de onda para determinar si el diseño es correcto, ya que compara
automáticamente la salida del DUT contra un modelo de referencia y reporta un
conteo de errores al final de la simulación.

### 4.1 Modelo de referencia

La función `expected_result` recalcula en "software" (comportamental, sin usar el
DUT) el resultado esperado para cada operación, replicando la misma tabla de
códigos de operación. Esto permite comparar automáticamente `result` y `zero` del
DUT contra los valores esperados en cada estímulo aplicado (tarea `run_test`).

### 4.2 Estrategia de estímulos

El testbench combina tres niveles de cobertura:

1. **Casos dirigidos (10 casos)**: cubren esquinas conocidas y relevantes:
   - `0 + 0 = 0` → verifica el flag `zero`.
   - `0x7FFFFFFF + 1` → overflow positivo en ADD.
   - `0x80000000 - (-1)` → overflow negativo en SUB.
   - `0xFFFFFFFF + 1` → wrap sin overflow (signos distintos, no debería marcar overflow).
   - XOR de un valor consigo mismo → resultado `0`, verifica `zero`.
   - NOR de todos unos → resultado `0`.
   - SRA y SRL con MSB en 1 → distingue corrimiento aritmético de lógico.
   - AND/OR con patrones alternados (`0xF0F0F0F0` / `0x0F0F0F0F`).

2. **Barrido de las 8 operaciones con datos pseudoaleatorios**: garantiza que cada
   una de las 8 operaciones se ejerza al menos una vez con operandos aleatorios.

3. **Batería masiva de estímulos aleatorios**: `NUM_RANDOM_TESTS = 500` iteraciones
   adicionales, donde `a`, `b` y la operación se generan aleatoriamente
   (`$random`, ancho completo de 32 bits mediante concatenación de dos llamadas a
   `$random`, y selección de operación aleatoria por índice `% NUM_OPS`).

En total se ejecutan **510 pruebas** por corrida de simulación.

### 4.3 Reporte de resultados

Cada estímulo se reporta por consola (`$display`) indicando si fue `OK` o `FALLO`,
junto con los operandos, el código de operación y los valores obtenido/esperado.
Al finalizar, se imprime un resumen:

```
TOTAL DE PRUEBAS : <tests>
ERRORES          : <errors>
RESULTADO: TODAS LAS PRUEBAS PASARON (PASS)   [o FAIL con la cantidad de errores]
```

Si se detecta al menos un error, la simulación termina con `$fatal`, lo cual la
marca como fallida de forma explícita (útil para integrarlo en un flujo de
regresión automatizado).

## 5. Simulación en Vivado

> _Completar esta sección con los resultados obtenidos al correr la simulación en
> tu entorno de Vivado. A continuación se detalla el procedimiento seguido._

### 5.1 Procedimiento

1. Crear un proyecto de simulación en Vivado (o usar el modo *Project Mode* /
   *RTL Analysis*) agregando [alu.v](alu.v) como *Design Source* y
   [alu_tb.v](alu_tb.v) como *Simulation Source*.
2. Establecer `alu_tb` como módulo top de simulación.
3. Ejecutar **Run Simulation → Run Behavioral Simulation**.
4. Revisar la consola de Tcl/Simulation: debe mostrarse el listado de las 510
   pruebas con el resultado `OK` en cada una, y el resumen final
   `RESULTADO: TODAS LAS PRUEBAS PASARON (PASS)`.
5. Inspeccionar las formas de onda (waveform) para al menos un caso de cada
   operación, verificando visualmente la relación entre `a`, `b`, `op`, `result`,
   `zero`, `carry` y `overflow`.

### 5.2 Resultados obtenidos

_(Pegar aquí:)_
- Captura de la consola de Vivado con el resumen final del testbench.
- Captura de las formas de onda (waveform) mostrando algunos casos representativos
  (por ejemplo, uno de ADD con overflow, uno de SUB, uno de SRA/SRL).
- Cantidad total de pruebas ejecutadas y errores detectados.

## 6. Análisis de tiempos (Timing Analysis)

> _Completar esta sección con el reporte de timing generado por Vivado luego de la
> síntesis e implementación del diseño (`top_alu`) para la placa Basys3._

### 6.1 Procedimiento

1. Sintetizar el diseño (**Run Synthesis**) usando [top_alu.v](top_alu.v) como
   módulo top y las restricciones de [alu_basys3.xdc](alu_basys3.xdc) (que define
   el reloj de 100 MHz de la Basys3 y la asignación de pines de botones,
   switches y LEDs).
2. Ejecutar la implementación (**Run Implementation**).
3. Abrir el **Report Timing Summary** (o ejecutar
   `report_timing_summary` en la consola Tcl) para obtener:
   - **WNS (Worst Negative Slack)** en el análisis *setup*.
   - **WHS (Worst Hold Slack)** en el análisis *hold*.
   - Frecuencia máxima estimada de operación (Fmax).
4. Dado que la ALU es puramente combinacional (la única lógica secuencial del
   diseño está en los registros de carga de `top_alu`, `reg_a`/`reg_b`), se espera
   que el camino crítico (*critical path*) atraviese la ALU completa: desde la
   salida de `reg_a`/`reg_b` (o desde las entradas de switches) hasta `led_result`.

### 6.2 Resultados obtenidos

_(Pegar aquí:)_
- WNS / WHS del reporte de timing.
- Fmax estimada y comparación contra los 100 MHz del reloj de la Basys3 definidos
  en el `.xdc`.
- Path crítico reportado (de qué señal a qué señal, y qué operación involucra).

## 7. Implementación en FPGA (Basys3)

Archivos: [top_alu.v](top_alu.v), [alu_basys3.xdc](alu_basys3.xdc)

Para la validación física en la placa Basys3 se instancia la ALU con
`DATA_WIDTH = 8`, envuelta en un módulo `top_alu` que resuelve la carga de
operandos mediante los switches y botones físicos de la placa (ya que no hay
suficientes switches para cargar `a` y `b` de forma simultánea):

- **`sw_data[7:0]`**: bus de datos compartido (switches SW0–SW7).
- **`sw_op[5:0]`**: código de operación (switches SW8–SW13).
- **`btn_load_a` / `btn_load_b`**: al detectar flanco ascendente, cargan el valor
  actual de `sw_data` en el registro `reg_a` o `reg_b` respectivamente. La
  detección de flanco (comparación contra `btn_a_prev`/`btn_b_prev` en el
  `always @(posedge clk)`) evita cargar el registro repetidamente mientras el
  botón permanece presionado.
- **`led_result[7:0]`**: resultado de la ALU.
- **`led_carry`, `led_overflow`, `led_zero`**: flags de salida.

El archivo de restricciones `alu_basys3.xdc` define:
- El reloj del sistema a 100 MHz (`create_clock ... -period 10.00`).
- El mapeo de pines de switches, botones y LEDs a los `PACKAGE_PIN` físicos de la
  Basys3.
- El estándar eléctrico `LVCMOS33` para todos los puertos.

## 8. Conclusiones

_(Completar con las conclusiones propias: si los resultados de simulación y timing
cumplieron lo esperado, dificultades encontradas, posibles mejoras — por ejemplo,
agregar más operaciones o registrar la salida para aumentar Fmax — y cómo se
proyecta la reutilización de esta ALU parametrizable en el trabajo final.)_
