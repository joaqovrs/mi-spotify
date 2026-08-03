import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'visualizador_pintor.dart';

/// Lo que manda la ventana principal cada vez que cambia la cancion o el
/// estado de reproduccion (ver `services/puente_widget_flotante.dart`).
class _DatosCancion {
  const _DatosCancion({this.titulo, this.artista, this.caratula, this.esArchivo = false});

  final String? titulo;
  final String? artista;

  /// URL http si la caratula viene del servidor, o una ruta de archivo si la
  /// cancion esta descargada (`esArchivo`). Esta ventana no sabe de Subsonic
  /// ni de descargas — la ventana principal ya lo resolvio.
  final String? caratula;
  final bool esArchivo;
}

/// La tarjeta de 400×132 fiel a `diseno/especificaciones.md`: caratula,
/// titulo/artista, los tres controles de transporte y el espectro animado.
class TarjetaWidgetFlotante extends StatefulWidget {
  const TarjetaWidgetFlotante({required this.idPrincipal, super.key});

  /// Id de la ventana principal, para mandarle de vuelta los comandos de
  /// transporte.
  final String idPrincipal;

  @override
  State<TarjetaWidgetFlotante> createState() => _TarjetaWidgetFlotanteState();
}

class _TarjetaWidgetFlotanteState extends State<TarjetaWidgetFlotante> {
  _DatosCancion? _cancion;
  bool _reproduciendo = false;

  @override
  void initState() {
    super.initState();
    _escuchar();
  }

  Future<void> _escuchar() async {
    final propia = await WindowController.fromCurrentEngine();
    await propia.setWindowMethodHandler((call) async {
      if (call.method != 'actualizar') return;

      final datos = jsonDecode(call.arguments as String) as Map<String, dynamic>;
      final cancion = datos['cancion'] as Map<String, dynamic>?;
      if (!mounted) return;

      setState(() {
        _reproduciendo = datos['reproduciendo'] as bool? ?? false;
        _cancion = cancion == null
            ? null
            : _DatosCancion(
                titulo: cancion['titulo'] as String?,
                artista: cancion['artista'] as String?,
                caratula: cancion['caratula'] as String?,
                esArchivo: cancion['esArchivo'] as bool? ?? false,
              );
      });
    });
  }

  void _mandar(String accion) {
    WindowController.fromWindowId(widget.idPrincipal).invokeMethod(accion);
  }

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        width: 400,
        height: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131417),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Caratula(cancion: _cancion),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _Meta(cancion: _cancion)),
                        const SizedBox(width: 8),
                        _Controles(
                          reproduciendo: _reproduciendo,
                          onAnterior: () => _mandar('anterior'),
                          onReproducirPausa: () => _mandar('reproducir_pausa'),
                          onSiguiente: () => _mandar('siguiente'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: VisualizadorEspectro(reproduciendo: _reproduciendo),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Caratula extends StatelessWidget {
  const _Caratula({required this.cancion});

  final _DatosCancion? cancion;

  @override
  Widget build(BuildContext context) {
    final ruta = cancion?.caratula;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment(-0.6, -1),
          end: Alignment(0.6, 1),
          colors: [Color(0xFF2E6F72), Color(0xFF1A3A46), Color(0xFF0E1418)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: ruta == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: cancion!.esArchivo
                  ? Image.file(
                      File(ruta),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    )
                  : Image.network(
                      ruta,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.cancion});

  final _DatosCancion? cancion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cancion?.titulo ?? 'Sin reproducción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF2F3F5),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          cancion?.artista ?? 'Elige una pista para empezar',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7E848D),
            fontSize: 12,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.reproduciendo,
    required this.onAnterior,
    required this.onReproducirPausa,
    required this.onSiguiente,
  });

  final bool reproduciendo;
  final VoidCallback onAnterior;
  final VoidCallback onReproducirPausa;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BotonChico(icono: Icons.skip_previous_rounded, onPressed: onAnterior),
        const SizedBox(width: 6),
        _BotonPlay(reproduciendo: reproduciendo, onPressed: onReproducirPausa),
        const SizedBox(width: 6),
        _BotonChico(icono: Icons.skip_next_rounded, onPressed: onSiguiente),
      ],
    );
  }
}

class _BotonChico extends StatelessWidget {
  const _BotonChico({required this.icono, required this.onPressed});

  final IconData icono;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        color: const Color(0xFFA8AFB7),
        onPressed: onPressed,
        icon: Icon(icono),
      ),
    );
  }
}

class _BotonPlay extends StatelessWidget {
  const _BotonPlay({required this.reproduciendo, required this.onPressed});

  final bool reproduciendo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFEDEFF1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: const Color(0xFF131417),
        onPressed: onPressed,
        icon: Icon(reproduciendo ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }
}
