import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/sesion_providers.dart';
import '../state/tema_providers.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final modo = ref.watch(temaProvider);
    final sesion = ref.watch(sesionProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 16),
            Text('Ajustes', style: textos.displaySmall),
            const SizedBox(height: 28),

            Text('Apariencia', style: textos.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Oscuro'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Sistema'),
                ),
              ],
              selected: {modo},
              showSelectedIcon: false,
              onSelectionChanged: (seleccion) =>
                  ref.read(temaProvider.notifier).cambiar(seleccion.first),
            ),

            const SizedBox(height: 34),
            Text('Servidor', style: textos.titleLarge),
            const SizedBox(height: 12),
            if (sesion is SesionAbierta) ...[
              _FilaDato(
                etiqueta: 'Conectado a',
                valor: sesion.cliente.baseUrlActiva,
              ),
              if (sesion.cliente.urls.length > 1)
                _FilaDato(
                  etiqueta: 'Alternativa',
                  valor: sesion.cliente.urls
                      .where((u) => u != sesion.cliente.baseUrlActiva)
                      .join(', '),
                ),
              _FilaDato(etiqueta: 'Usuario', valor: sesion.cliente.usuario),
            ],

            const SizedBox(height: 34),
            OutlinedButton.icon(
              onPressed: () => _confirmarCierre(context, ref),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCierre(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Se van a borrar las credenciales guardadas en este teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmado ?? false) {
      await ref.read(sesionProvider.notifier).cerrarSesion();
    }
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(etiqueta, style: textos.bodySmall),
          ),
          Expanded(
            child: Text(valor, style: textos.titleMedium),
          ),
        ],
      ),
    );
  }
}
