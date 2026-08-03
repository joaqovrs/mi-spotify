import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show pid;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32/win32.dart';

import '../core/config.dart';
import '../core/subsonic_client.dart';
import '../state/reproductor_providers.dart';
import '../state/sesion_providers.dart';

/// Presencia enriquecida en Discord ("Escuchando Mi Music — Cancion, Artista").
///
/// Discord de escritorio abre un named pipe local (`\\.\pipe\discord-ipc-N`)
/// que cualquier proceso de la maquina puede conectar sin permisos
/// especiales — es asi como cualquier juego o app le avisa a Discord que
/// mostrar. No hay paquete de Flutter para esto en Windows, pero el
/// protocolo es simple (cabecera de 8 bytes + JSON) y ya tenemos `win32` en
/// el proyecto por la captura de audio del widget flotante, asi que se
/// implementa directo con esas mismas bindings, sin dependencias nuevas.
///
/// **Todo el pipe vive en un Isolate aparte.** `ReadFile` sobre un named pipe
/// sincrono bloquea el hilo que lo llama hasta que hay datos — si Discord se
/// cuelga o el pipe se corta a mitad de una lectura, ese bloqueo se comeria
/// el hilo de UI entero. El isolate solo se comunica con el resto de la app
/// por mensajes (nunca un `HANDLE` cruzando isolates), asi que un pipe
/// colgado como mucho traba ESE isolate, nunca la app.
class DiscordRpc {
  SendPort? _puerto;
  final ReceivePort _recepcion = ReceivePort();

  /// Arranca el isolate que sostiene la conexion. No hace falta esperar a que
  /// conecte: si Discord no esta corriendo todavia, el isolate reintenta
  /// solo cada tanto y aplica el ultimo estado pedido en cuanto conecta.
  Future<void> iniciar() async {
    await Isolate.spawn(_hiloDiscord, _recepcion.sendPort);
    _puerto = await _recepcion.first as SendPort;
  }

  /// Cancion sonando o en pausa: la muestra como "Escuchando".
  void actualizarActividad({
    required String titulo,
    required String? artista,
    required String? imagenUrl,
    required bool reproduciendo,
    required int inicioEpochMs,
  }) {
    _puerto?.send({
      'accion': 'actualizar',
      'titulo': titulo,
      'artista': artista,
      'imagenUrl': imagenUrl,
      'reproduciendo': reproduciendo,
      'inicioEpochMs': inicioEpochMs,
    });
  }

  /// Sin sesion o sin nada cargado: saca el "Escuchando" del perfil.
  void limpiarActividad() {
    _puerto?.send({'accion': 'limpiar'});
  }

  void detener() {
    _puerto?.send({'accion': 'detener'});
    _recepcion.close();
  }
}

/// Engancha la actividad de Discord a la cancion y al estado de reproduccion.
/// Se llama una sola vez, desde `main()`, antes de `runApp` — igual que
/// `configurarPuenteWidgetFlotante`.
void configurarDiscordRpc(ProviderContainer contenedor) {
  final discord = DiscordRpc();
  unawaited(discord.iniciar());

  void actualizar() {
    final cancion = contenedor.read(cancionActualProvider).value;
    if (cancion == null) {
      discord.limpiarActividad();
      return;
    }

    final estado = contenedor.read(estadoReproduccionProvider).value;
    final reproduciendo = estado?.playing ?? false;
    final posicion = estado?.position ?? Duration.zero;

    discord.actualizarActividad(
      titulo: cancion.title,
      artista: cancion.artist,
      imagenUrl: _imagenParaDiscord(contenedor, cancion),
      reproduciendo: reproduciendo,
      inicioEpochMs:
          DateTime.now().millisecondsSinceEpoch - posicion.inMilliseconds,
    );
  }

  contenedor.listen(cancionActualProvider, (_, _) => actualizar());
  contenedor.listen(estadoReproduccionProvider, (_, _) => actualizar());
}

/// La URL de la caratula, o `null` si no se puede armar una que Discord
/// pueda alcanzar.
///
/// Discord tiene que poder bajarla el solo desde internet, con HTTPS —
/// asi que no sirve ni una ruta de archivo local (una cancion descargada) ni
/// la direccion local del servidor (`192.168.1.194`, sin certificado): quien
/// mire el perfil de Discord puede estar en otra red, o ser Discord mismo
/// bajando la imagen desde afuera. Por eso se arma siempre contra
/// [Servidor.urlRemota] y no contra `sesion.cliente.baseUrlActiva`, que en
/// casa apunta a la direccion local — sin esto, la caratula andaria en
/// Discord estando afuera de casa pero no estando adentro, un bug dificil de
/// notar porque "andaba hace un rato".
///
/// Se arma un [SubsonicClient] nuevo, angosto a esa unica direccion, en vez
/// de agregarle este caso especial al cliente real: no hace ninguna peticion
/// de red (`urlPortada` solo arma la URL), asi que crearlo no tiene costo.
/// Tampoco se usa `clienteProvider`, que tira una excepcion sin sesion
/// abierta — una cancion descargada puede sonar con la sesion cerrada.
String? _imagenParaDiscord(ProviderContainer contenedor, MediaItem cancion) {
  final idPortada = portadaDe(cancion);
  if (idPortada == null) return null;

  final sesion = contenedor.read(sesionProvider);
  if (sesion is! SesionAbierta) return null;

  final clienteRemoto = SubsonicClient(
    urls: [Servidor.urlRemota],
    usuario: sesion.cliente.usuario,
    password: sesion.cliente.password,
  );
  return clienteRemoto.urlPortada(idPortada, tamano: 300).toString();
}

// --------------------------------------------------------------- El isolate

const _opcodeHandshake = 0;
const _opcodeFrame = 1;

Future<void> _hiloDiscord(SendPort alPrincipal) async {
  final recepcion = ReceivePort();
  alPrincipal.send(recepcion.sendPort);

  HANDLE? handle;
  Map<String, dynamic>? ultimoPedido;
  var detenido = false;

  Future<bool> conectar() async {
    for (var i = 0; i < 10; i++) {
      final ruta = '\\\\.\\pipe\\discord-ipc-$i';
      final rutaNativa = ruta.toNativeUtf16();
      final resultado = CreateFile(
        PCWSTR(rutaNativa),
        GENERIC_READ | GENERIC_WRITE,
        const FILE_SHARE_MODE(0),
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        null,
      );
      free(rutaNativa);
      if (resultado.value != INVALID_HANDLE_VALUE) {
        handle = resultado.value;
        break;
      }
    }
    if (handle == null) return false;

    final ok = _escribirFrame(
      handle!,
      _opcodeHandshake,
      jsonEncode({'v': 1, 'client_id': Discord.clientId}),
    );
    if (!ok) {
      _cerrar(handle);
      handle = null;
      return false;
    }

    // Discord contesta con un evento READY antes de aceptar comandos. Si no
    // llega nada coherente, se descarta la conexion — mejor reintentar desde
    // cero que quedarse con un pipe en un estado raro.
    final respuesta = _leerFrame(handle!);
    if (respuesta == null) {
      _cerrar(handle);
      handle = null;
      return false;
    }
    return true;
  }

  void enviarActividad(Map<String, dynamic>? pedido) {
    if (handle == null) return;

    final Map<String, dynamic>? actividad;
    if (pedido == null) {
      actividad = null;
    } else {
      actividad = {
        'type': 2, // Listening
        'details': pedido['titulo'],
        if (pedido['artista'] != null) 'state': pedido['artista'],
        'assets': {
          if (pedido['imagenUrl'] != null) 'large_image': pedido['imagenUrl'],
          'large_text': 'Mi Music',
        },
        // Sin timestamp en pausa: que el reloj de Discord no seguir corriendo
        // con la cancion detenida.
        if (pedido['reproduciendo'] == true)
          'timestamps': {
            'start': pedido['inicioEpochMs'],
          },
      };
    }

    final ok = _escribirFrame(
      handle!,
      _opcodeFrame,
      jsonEncode({
        'cmd': 'SET_ACTIVITY',
        'args': {'pid': pid, 'activity': actividad},
        'nonce': DateTime.now().microsecondsSinceEpoch.toString(),
      }),
    );
    if (!ok) {
      _cerrar(handle);
      handle = null;
    }
  }

  recepcion.listen((mensaje) {
    if (mensaje is! Map) return;
    switch (mensaje['accion']) {
      case 'actualizar':
        ultimoPedido = Map<String, dynamic>.from(mensaje);
        enviarActividad(ultimoPedido);
      case 'limpiar':
        ultimoPedido = null;
        enviarActividad(null);
      case 'detener':
        detenido = true;
        _cerrar(handle);
        handle = null;
        recepcion.close();
    }
  });

  // Discord puede no estar corriendo todavia, o reiniciarse (actualizacion,
  // cierre de sesion). Reintentar cada tanto es mas simple y mas robusto que
  // tratar de detectar esos casos por separado, y el costo es minimo: un
  // intento de conexion que falla es practicamente instantaneo.
  while (!detenido) {
    if (handle == null) {
      final conectado = await conectar();
      // Si ya habia algo pedido antes de que Discord estuviera arriba (o de
      // que se reconectara), se lo manda apenas conecta.
      if (conectado) enviarActividad(ultimoPedido);
    }
    await Future<void>.delayed(const Duration(seconds: 15));
  }
}

void _cerrar(HANDLE? handle) {
  if (handle != null) CloseHandle(handle);
}

/// Escribe un frame completo (cabecera de 8 bytes + JSON). Devuelve `false`
/// si el pipe se corto — la llamada de mas arriba lo toma como señal para
/// soltar el handle y reintentar conectar desde cero.
bool _escribirFrame(HANDLE handle, int opcode, String json) {
  final payload = utf8.encode(json);
  final total = 8 + payload.length;
  final buffer = calloc<Uint8>(total);
  try {
    final cabecera = ByteData(8)
      ..setUint32(0, opcode, Endian.little)
      ..setUint32(4, payload.length, Endian.little);
    final vista = buffer.asTypedList(total);
    vista.setRange(0, 8, cabecera.buffer.asUint8List());
    vista.setRange(8, total, payload);

    return _escribirExacto(handle, buffer, total);
  } finally {
    free(buffer);
  }
}

bool _escribirExacto(HANDLE handle, Pointer<Uint8> buffer, int total) {
  final escritos = calloc<Uint32>();
  try {
    var enviados = 0;
    while (enviados < total) {
      final resultado = WriteFile(
        handle,
        buffer + enviados,
        total - enviados,
        escritos,
        null,
      );
      if (!resultado.value || escritos.value == 0) return false;
      enviados += escritos.value;
    }
    return true;
  } finally {
    free(escritos);
  }
}

/// Lee un frame completo. `null` si el pipe se corto a mitad de lectura — un
/// pipe puede devolver menos bytes de los pedidos por llamada, asi que hay
/// que insistir hasta completar la cabecera y despues el cuerpo.
Map<String, dynamic>? _leerFrame(HANDLE handle) {
  final cabecera = _leerExacto(handle, 8);
  if (cabecera == null) return null;

  final datos = ByteData.sublistView(cabecera);
  final largo = datos.getUint32(4, Endian.little);
  if (largo == 0) return <String, dynamic>{};

  final cuerpo = _leerExacto(handle, largo);
  if (cuerpo == null) return null;

  final texto = utf8.decode(cuerpo);
  final decodificado = jsonDecode(texto);
  return decodificado is Map<String, dynamic> ? decodificado : <String, dynamic>{};
}

Uint8List? _leerExacto(HANDLE handle, int cantidad) {
  final buffer = calloc<Uint8>(cantidad);
  final leidos = calloc<Uint32>();
  try {
    var recibidos = 0;
    while (recibidos < cantidad) {
      final resultado = ReadFile(
        handle,
        buffer + recibidos,
        cantidad - recibidos,
        leidos,
        null,
      );
      if (!resultado.value || leidos.value == 0) return null;
      recibidos += leidos.value;
    }
    return Uint8List.fromList(buffer.asTypedList(cantidad));
  } finally {
    free(buffer);
    free(leidos);
  }
}
