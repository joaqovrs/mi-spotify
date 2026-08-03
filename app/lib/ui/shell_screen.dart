import 'package:flutter/material.dart';

import 'ajustes_screen.dart';
import 'biblioteca_screen.dart';
import 'buscar_screen.dart';
import 'inicio_screen.dart';
import 'navegacion_destinos.dart';
import 'widgets/mini_reproductor.dart';

/// Contenedor principal con la barra de navegacion inferior.
///
/// Usa [IndexedStack] en vez de reconstruir cada pestaña: asi el scroll y el
/// estado de cada seccion se conservan al ir y volver.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  static const _pantallas = <Widget>[
    InicioScreen(),
    BuscarScreen(),
    BibliotecaScreen(),
    AjustesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indice, children: _pantallas),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniReproductor(),
          NavigationBar(
            selectedIndex: _indice,
            onDestinationSelected: (i) => setState(() => _indice = i),
            destinations: [
              for (final d in destinosNav)
                NavigationDestination(
                  icon: Icon(d.icono),
                  selectedIcon: Icon(d.iconoSeleccionado),
                  label: d.etiqueta,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
