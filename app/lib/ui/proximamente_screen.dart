import 'package:flutter/material.dart';

/// Marcador de posición para las secciones que llegan en etapas siguientes.
/// Se borra a medida que cada pantalla real la reemplaza.
class ProximamenteScreen extends StatelessWidget {
  const ProximamenteScreen({
    required this.titulo,
    required this.icono,
    required this.detalle,
    super.key,
  });

  final String titulo;
  final IconData icono;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final suave = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(titulo, style: textos.displaySmall),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 84,
                        width: 84,
                        decoration: BoxDecoration(
                          color: suave,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, size: 36, color: textos.bodySmall?.color),
                      ),
                      const SizedBox(height: 20),
                      Text('Próximamente', style: textos.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        detalle,
                        textAlign: TextAlign.center,
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
