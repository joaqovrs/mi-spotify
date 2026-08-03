import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'tarjeta_widget_flotante.dart';

/// Raiz de la ventana del widget flotante: un motor de Flutter aparte del
/// principal (`desktop_multi_window` relanza el mismo ejecutable como otro
/// proceso, ver `main.dart`). Sin Riverpod ni el tema de la app — es una
/// pieza visual autonoma, fiel al diseño de Figma que la origino, no una
/// pantalla mas de Mi Music.
class WidgetFlotanteApp extends StatefulWidget {
  const WidgetFlotanteApp({required this.argumentos, super.key});

  /// JSON con `{'idPrincipal': <windowId de la ventana principal>}`.
  final String argumentos;

  @override
  State<WidgetFlotanteApp> createState() => _WidgetFlotanteAppState();
}

class _WidgetFlotanteAppState extends State<WidgetFlotanteApp> {
  late final String _idPrincipal;

  @override
  void initState() {
    super.initState();
    final datos = jsonDecode(widget.argumentos) as Map<String, dynamic>;
    _idPrincipal = datos['idPrincipal'] as String;
    _configurarVentana();
  }

  /// Sin bordes, siempre encima, y con fondo transparente — esto ultimo es lo
  /// que deja ver las esquinas redondas de la tarjeta como esquinas de
  /// verdad, en vez de un rectangulo opaco con las puntas recortadas.
  Future<void> _configurarVentana() async {
    await windowManager.ensureInitialized();
    const opciones = WindowOptions(
      size: Size(400, 132),
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      alwaysOnTop: true,
    );
    await windowManager.waitUntilReadyToShow(opciones, () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        type: MaterialType.transparency,
        child: TarjetaWidgetFlotante(idPrincipal: _idPrincipal),
      ),
    );
  }
}
