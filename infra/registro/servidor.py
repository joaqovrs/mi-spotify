"""Servicio de registro de usuarios para Navidrome.

Navidrome no tiene registro publico: crear un usuario exige credenciales de
administrador. Meterlas en el APK seria regalarlas, porque un APK se abre con
cualquier herramienta. Entonces viven aca, del lado del servidor, y lo unico
que se expone a internet es "creame un usuario comun con este codigo de
invitacion".

Que hace este servicio y que no:

  - Solo crea usuarios con isAdmin=False. No hay forma de pedir un admin.
  - No lista, no borra, no modifica usuarios. Un solo verbo.
  - Exige un codigo de invitacion compartido, para que no se registre
    cualquiera que descubra el puerto.

Sin dependencias externas a proposito: solo biblioteca estandar de Python, asi
la imagen es python:3-alpine pelada y no hay que construir nada ni mantener un
requirements.txt.
"""

from __future__ import annotations

import hmac
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NAVIDROME_URL = os.environ.get("NAVIDROME_URL", "http://navidrome:4533").rstrip("/")
ADMIN_USER = os.environ.get("ND_ADMIN_USER", "")
ADMIN_PASS = os.environ.get("ND_ADMIN_PASS", "")
INVITACION = os.environ.get("CODIGO_INVITACION", "")
PUERTO = int(os.environ.get("PUERTO", "8080"))

USUARIO_VALIDO = re.compile(r"^[a-zA-Z0-9._-]{3,32}$")
LARGO_MINIMO_PASSWORD = 6

# Freno al probador de codigos. Sin esto, el codigo de invitacion se saca a
# fuerza bruta: es un solo valor y el puerto esta abierto a internet.
INTENTOS_MAXIMOS = 5
VENTANA_SEGUNDOS = 600

_intentos: dict[str, deque[float]] = defaultdict(deque)


def _demasiados_intentos(ip: str) -> bool:
    ahora = time.time()
    marcas = _intentos[ip]
    while marcas and ahora - marcas[0] > VENTANA_SEGUNDOS:
        marcas.popleft()
    return len(marcas) >= INTENTOS_MAXIMOS


def _anotar_intento_fallido(ip: str) -> None:
    _intentos[ip].append(time.time())


def _pedir(url: str, cuerpo: dict, cabeceras: dict | None = None) -> tuple[int, dict]:
    """POST de JSON que devuelve (codigo, cuerpo). No lanza por 4xx/5xx."""
    datos = json.dumps(cuerpo).encode()
    peticion = urllib.request.Request(url, data=datos, method="POST")
    peticion.add_header("Content-Type", "application/json")
    for clave, valor in (cabeceras or {}).items():
        peticion.add_header(clave, valor)

    try:
        with urllib.request.urlopen(peticion, timeout=15) as respuesta:
            texto = respuesta.read().decode()
            return respuesta.status, (json.loads(texto) if texto else {})
    except urllib.error.HTTPError as e:
        texto = e.read().decode(errors="replace")
        try:
            return e.code, json.loads(texto) if texto else {}
        except json.JSONDecodeError:
            return e.code, {"mensaje": texto}


def _token_admin() -> str:
    """Inicia sesion como admin en Navidrome y devuelve el token."""
    codigo, cuerpo = _pedir(
        f"{NAVIDROME_URL}/auth/login",
        {"username": ADMIN_USER, "password": ADMIN_PASS},
    )
    if codigo != 200 or "token" not in cuerpo:
        raise RuntimeError(
            f"Navidrome rechazo las credenciales de admin (codigo {codigo}). "
            "Revisa ND_ADMIN_USER y ND_ADMIN_PASS."
        )
    return cuerpo["token"]


def _crear_usuario(usuario: str, password: str) -> tuple[int, dict]:
    token = _token_admin()
    return _pedir(
        f"{NAVIDROME_URL}/api/user",
        {
            "userName": usuario,
            "name": usuario,
            "password": password,
            # Clavado a mano y no tomado de la peticion: es la unica linea que
            # impide que este endpoint fabrique administradores.
            "isAdmin": False,
        },
        {"x-nd-authorization": f"Bearer {token}"},
    )


class Manejador(BaseHTTPRequestHandler):
    server_version = "registro-mi-music/1.0"

    def _responder(self, codigo: int, cuerpo: dict) -> None:
        datos = json.dumps(cuerpo).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def _ip_cliente(self) -> str:
        return self.client_address[0]

    def do_GET(self) -> None:  # noqa: N802 (lo pide BaseHTTPRequestHandler)
        if self.path == "/salud":
            self._responder(200, {"ok": True})
        else:
            self._responder(404, {"error": "No existe."})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/registro":
            self._responder(404, {"error": "No existe."})
            return

        ip = self._ip_cliente()
        if _demasiados_intentos(ip):
            self._responder(
                429,
                {"error": "Demasiados intentos. Espera unos minutos."},
            )
            return

        try:
            largo = int(self.headers.get("Content-Length", "0"))
            peticion = json.loads(self.rfile.read(largo) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self._responder(400, {"error": "Peticion invalida."})
            return

        usuario = str(peticion.get("usuario", "")).strip()
        password = str(peticion.get("password", ""))
        invitacion = str(peticion.get("invitacion", "")).strip()

        # compare_digest y no ==: la comparacion normal corta en la primera
        # letra distinta, y eso filtra el codigo caracter por caracter.
        if not INVITACION or not hmac.compare_digest(invitacion, INVITACION):
            _anotar_intento_fallido(ip)
            self._responder(401, {"error": "El codigo de invitacion no es valido."})
            return

        if not USUARIO_VALIDO.match(usuario):
            self._responder(
                400,
                {
                    "error": "El usuario debe tener entre 3 y 32 caracteres, "
                    "y solo letras, numeros, punto, guion o guion bajo."
                },
            )
            return

        if len(password) < LARGO_MINIMO_PASSWORD:
            self._responder(
                400,
                {"error": f"La contrasena necesita al menos {LARGO_MINIMO_PASSWORD} caracteres."},
            )
            return

        try:
            codigo, cuerpo = _crear_usuario(usuario, password)
        except RuntimeError as e:
            print(f"[registro] {e}", file=sys.stderr, flush=True)
            self._responder(
                503,
                {"error": "El servidor no pudo crear la cuenta. Avisale al administrador."},
            )
            return
        except OSError as e:
            print(f"[registro] no se pudo hablar con Navidrome: {e}", file=sys.stderr, flush=True)
            self._responder(503, {"error": "El servidor de musica no responde."})
            return

        if codigo in (200, 201):
            print(f"[registro] usuario creado: {usuario}", flush=True)
            self._responder(201, {"ok": True})
            return

        if codigo in (400, 409):
            self._responder(409, {"error": "Ese usuario ya existe. Elegi otro."})
            return

        print(f"[registro] Navidrome respondio {codigo}: {cuerpo}", file=sys.stderr, flush=True)
        self._responder(502, {"error": "El servidor de musica rechazo la creacion."})

    def log_message(self, formato: str, *args) -> None:
        # El log por defecto escribe en stderr con formato de Apache. Se
        # reemplaza para que docker logs quede legible y sin la contrasena.
        print(f"[registro] {self.address_string()} {formato % args}", flush=True)


def main() -> None:
    faltantes = [
        nombre
        for nombre, valor in (
            ("ND_ADMIN_USER", ADMIN_USER),
            ("ND_ADMIN_PASS", ADMIN_PASS),
            ("CODIGO_INVITACION", INVITACION),
        )
        if not valor
    ]
    if faltantes:
        # Cortar al arrancar y no al primer registro: un servicio que levanta
        # bien y falla recien cuando alguien lo usa es peor que uno que no
        # levanta.
        print(
            f"[registro] faltan variables de entorno: {', '.join(faltantes)}",
            file=sys.stderr,
            flush=True,
        )
        raise SystemExit(1)

    servidor = ThreadingHTTPServer(("0.0.0.0", PUERTO), Manejador)
    print(f"[registro] escuchando en el puerto {PUERTO}", flush=True)
    servidor.serve_forever()


if __name__ == "__main__":
    main()
