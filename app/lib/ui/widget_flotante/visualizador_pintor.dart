import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Barras del espectro del widget flotante.
///
/// No es un analisis de audio real: `media_kit` no expone datos de espectro
/// en su API de Dart hoy, y captar el audio del sistema en vivo (WASAPI
/// loopback) es una pieza de ingenieria aparte que se decidio no encarar en
/// esta pasada (ver el plan). Con `reproduciendo == true`, cada barra anima
/// hacia un objetivo aleatorio propio, resorteado cada tanto, con la misma
/// curva de ataque-rapido/caida-lenta que trae el diseño original de
/// referencia (`widget.js`). Con `reproduciendo == false` usa exactamente la
/// formula de reposo de ese mismo diseño — una linea base que respira.
class VisualizadorEspectro extends StatefulWidget {
  const VisualizadorEspectro({required this.reproduciendo, super.key});

  final bool reproduciendo;

  @override
  State<VisualizadorEspectro> createState() => _VisualizadorEspectroState();
}

class _VisualizadorEspectroState extends State<VisualizadorEspectro>
    with SingleTickerProviderStateMixin {
  static const _anchoBarra = 3.0;
  static const _huecoBarra = 2.0;
  static const _radioBarra = 1.5;
  static const _alturaMinima = 2.0;
  static const _color = Color(0xFF63BFB5);
  static const _caida = 0.055;

  late final Ticker _ticker;
  final _random = Random();

  List<double> _niveles = [];
  List<double> _objetivos = [];
  List<double> _proximoSorteo = [];
  double _reposo = 0;
  double _ultimoTiempo = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration transcurrido) {
    final ahora = transcurrido.inMicroseconds / 1e6;
    final dt = ahora - _ultimoTiempo;
    _ultimoTiempo = ahora;
    if (dt <= 0 || dt > 1) return;

    setState(() {
      if (!widget.reproduciendo) {
        _reposo += 0.012;
        return;
      }
      for (var i = 0; i < _niveles.length; i++) {
        _proximoSorteo[i] -= dt;
        if (_proximoSorteo[i] <= 0) {
          _objetivos[i] = 0.15 + _random.nextDouble() * 0.85;
          _proximoSorteo[i] = 0.15 + _random.nextDouble() * 0.25;
        }
        final objetivo = _objetivos[i];
        final actual = _niveles[i];
        _niveles[i] = objetivo > actual
            ? objetivo
            : max(objetivo, actual - _caida);
      }
    });
  }

  void _ajustarCantidad(int cantidad) {
    if (cantidad == _niveles.length) return;
    _niveles = List.filled(cantidad, 0);
    _objetivos = List.filled(cantidad, 0);
    _proximoSorteo = List.filled(cantidad, 0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final paso = _anchoBarra + _huecoBarra;
        final cantidad = max(8, ((ancho + _huecoBarra) / paso).floor());
        _ajustarCantidad(cantidad);

        final valores = List<double>.generate(cantidad, (i) {
          if (widget.reproduciendo) return _niveles[i];
          return 0.05 + 0.035 * sin(_reposo + i * 0.35);
        });

        return CustomPaint(
          size: Size(ancho, constraints.maxHeight),
          painter: _PintorEspectro(
            valores: valores,
            anchoBarra: _anchoBarra,
            huecoBarra: _huecoBarra,
            radioBarra: _radioBarra,
            alturaMinima: _alturaMinima,
            color: _color,
          ),
        );
      },
    );
  }
}

class _PintorEspectro extends CustomPainter {
  _PintorEspectro({
    required this.valores,
    required this.anchoBarra,
    required this.huecoBarra,
    required this.radioBarra,
    required this.alturaMinima,
    required this.color,
  });

  final List<double> valores;
  final double anchoBarra;
  final double huecoBarra;
  final double radioBarra;
  final double alturaMinima;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paso = anchoBarra + huecoBarra;

    for (var i = 0; i < valores.length; i++) {
      final v = valores[i].clamp(0.0, 1.0);
      final alto = max(alturaMinima, v * size.height);
      final x = i * paso;
      final y = size.height - alto;
      final opacidad = 0.38 + 0.60 * v;

      final pintura = Paint()..color = color.withValues(alpha: opacidad);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, anchoBarra, alto),
          Radius.circular(radioBarra),
        ),
        pintura,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorEspectro oldDelegate) => true;
}
