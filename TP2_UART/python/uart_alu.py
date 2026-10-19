#!/usr/bin/env python3
"""
Cliente UART para el TP: manda A, B y OP a la Basys3 y muestra el resultado.

Instalar:   pip install pyserial
Uso:
    python uart_alu.py                  # busca la placa sola (modo interactivo)
    python uart_alu.py --port COM11     # o indicando el puerto
    python uart_alu.py --test 200       # prueba automática con N operaciones

Qué hace si algo falla:
  - Si la placa no responde (se perdió un byte), espera a que la FPGA
    se resincronice sola (timeout de 0,5 s) y reintenta la operación.
  - Si se corta el USB, espera a que la placa vuelva a aparecer y se
    reconecta sola (aunque cambie el número de COM).
"""
import argparse
import random
import time
import serial
import serial.tools.list_ports

BAUDRATE = 9600            # tiene que coincidir con BRATE del top.v
FPGA_TIMEOUT_S = 0.5       # tiene que coincidir con TIMEOUT_MS del top.v
BASYS3_VID_PID = (0x0403, 0x6010)   # chip FTDI de la Basys3

# Mismos códigos que en el TP1
OPS = {
    "ADD": 0b100000,
    "SUB": 0b100010,
    "AND": 0b100100,
    "OR":  0b100101,
    "XOR": 0b100110,
    "SRA": 0b000011,
    "SRL": 0b000010,
    "NOR": 0b100111,
}


# ---------------------------------------------------------------------------
# Modelo de referencia (lo que DEBERÍA dar la placa)
# ---------------------------------------------------------------------------
def con_signo(x):
    return x - 256 if x & 0x80 else x


def alu_modelo(a, b, op):
    """Resultado de 8 bits."""
    if op == "ADD": r = a + b
    elif op == "SUB": r = a - b
    elif op == "AND": r = a & b
    elif op == "OR":  r = a | b
    elif op == "XOR": r = a ^ b
    elif op == "NOR": r = ~(a | b)
    elif op == "SRL": r = b >> (a & 0x7)            # B desplazado A (como la ALU del TP1)
    elif op == "SRA": r = con_signo(b) >> (a & 0x7)
    return r & 0xFF


def flags_modelo(a, b, op, r):
    """Flags (C, V, Z) que deberían verse en los LEDs 13, 14 y 15."""
    c = v = 0
    if op == "ADD":
        c = int(a + b > 0xFF)
        v = int((a & 0x80) == (b & 0x80) and (r & 0x80) != (a & 0x80))
    elif op == "SUB":
        c = int(a < b)                                   # borrow
        v = int((a & 0x80) != (b & 0x80) and (r & 0x80) != (a & 0x80))
    z = int(r == 0)
    return c, v, z


# ---------------------------------------------------------------------------
# Conexión con la placa
# ---------------------------------------------------------------------------
def buscar_placa():
    """Devuelve el COM de la Basys3, o None si no está conectada."""
    for p in serial.tools.list_ports.comports():
        if (p.vid, p.pid) == BASYS3_VID_PID:
            return p.device
    return None


def abrir(port_fijo=None, esperar=False):
    """Abre el puerto. Si esperar=True, espera hasta que aparezca la placa
    (buscándola por VID/PID, porque al reconectar el COM puede cambiar)."""
    avisado = False
    while True:
        if esperar:
            port = buscar_placa() or port_fijo
        else:
            port = port_fijo or buscar_placa()
        if port:
            try:
                ser = serial.Serial(port, BAUDRATE, bytesize=8, parity="N",
                                    stopbits=1, timeout=1, write_timeout=1)
                ser.reset_input_buffer()
                return ser
            except serial.SerialException:
                pass
        if not esperar:
            raise SystemExit("No encontré la placa. ¿Está enchufada y encendida? "
                             "(podés indicar el puerto con --port COMx)")
        if not avisado:
            print("  Esperando que la placa vuelva a conectarse... (Ctrl+C para salir)")
            avisado = True
        time.sleep(0.5)


class Placa:
    def __init__(self, port=None):
        self.port_fijo = port
        self.ser = abrir(port)
        print(f"Conectada en {self.ser.port} a {BAUDRATE} baud (8N1)\n")

    def reconectar(self):
        try:
            self.ser.close()
        except Exception:
            pass
        print("  Se cortó la conexión USB con la placa.")
        self.ser = abrir(self.port_fijo, esperar=True)
        print(f"  Reconectada en {self.ser.port}. Si el LED DONE se apagó, "
              f"volvé a programar la placa desde Vivado.")

    def _una_vez(self, a, b, op):
        self.ser.reset_input_buffer()                       # descarto basura vieja
        self.ser.write(bytes([a & 0xFF, b & 0xFF, OPS[op]]))
        self.ser.flush()
        resp = self.ser.read(1)                             # espera hasta 1 s
        return resp[0] if resp else None

    def operar(self, a, b, op):
        """Manda A, B, OP y devuelve el resultado. Reintenta si algo falla."""
        for intento in range(3):
            try:
                r = self._una_vez(a, b, op)
            except Exception:              # puerto desaparecido (USB cortado)
                self.reconectar()
                continue
            if r is not None:
                return r
            # No respondió: la FPGA quedó desfasada. Espero su timeout y reintento.
            print("  (sin respuesta, reintentando...)")
            time.sleep(FPGA_TIMEOUT_S + 0.2)
        raise TimeoutError("La placa no responde. Apretá btnC y probá de nuevo.")

    def cerrar(self):
        try:
            self.ser.close()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Modos de uso
# ---------------------------------------------------------------------------
def mostrar(a, b, op, r):
    a8, b8 = a & 0xFF, b & 0xFF
    esp = alu_modelo(a8, b8, op)
    c, v, z = flags_modelo(a8, b8, op, esp)
    estado = "OK" if r == esp else f"ERROR (esperado 0x{esp:02X})"
    print(f"  resultado = 0x{r:02X} = {r} (con signo: {con_signo(r)})   {estado}")
    print(f"  LEDs: Z(15)={z}  V(14)={v}  C(13)={c}   resultado(7..0)={r:08b}")


def modo_interactivo(placa):
    print("Operaciones:", ", ".join(OPS))
    print("Formato: A B OP   (ej: 10 -3 ADD; shifts: cantidad valor, ej: 1 0xF8 SRA). 'q' para salir.\n")
    while True:
        try:
            linea = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if linea.lower() in ("q", "quit", "exit"):
            break
        try:
            a_txt, b_txt, op = linea.split()
            a, b, op = int(a_txt, 0), int(b_txt, 0), op.upper()
            if op not in OPS:
                print("  Operación desconocida"); continue
        except ValueError:
            print("  Formato inválido"); continue

        try:
            r = placa.operar(a, b, op)
        except TimeoutError as e:
            print(f"  {e}")
            continue
        mostrar(a, b, op, r)


def modo_test(placa, n):
    errores = 0
    for i in range(n):
        a, b = random.randint(0, 255), random.randint(0, 255)
        op = random.choice(list(OPS))
        if op in ("SRA", "SRL"):
            a %= 8                      # A = cantidad de posiciones
        r = placa.operar(a, b, op)
        esp = alu_modelo(a, b, op)
        if r != esp:
            errores += 1
            print(f"ERROR {i}: {a:02X} {op} {b:02X} -> {r:02X} (esperado {esp:02X})")
    print(f"\n{n - errores}/{n} operaciones correctas")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--port", default=None, help="ej: COM11 (si no se indica, la busca sola)")
    p.add_argument("--test", type=int, default=0, help="cantidad de pruebas automáticas")
    args = p.parse_args()

    placa = Placa(args.port)
    try:
        if args.test:
            modo_test(placa, args.test)
        else:
            modo_interactivo(placa)
    except KeyboardInterrupt:
        pass
    finally:
        placa.cerrar()
