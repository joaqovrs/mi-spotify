import 'package:flutter/material.dart';

import 'ajustes_screen.dart';
import 'inicio_screen.dart';
import 'proximamente_screen.dart';
import 'widgets/mini_reproductor.dart';

/// Contenedor principal con la barra de navegación inferior.
///
/// Usa [IndexedStack] en vez de reconstruir cada pestaña: así el scroll y el
/// estado de cada sección se conservan al ir y volver.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _indice = 0;

  static const _pantallas = <Widget>[
    InicioScreen(),
    ProximamenteScreen(
      titulo: 'Buscar',
      icono: Icons.search_rounded,
      detalle: 'Buscador de canciones, álbumes y artistas.',
    ),
    ProximamenteScreen(
      titulo: 'Tu biblioteca',
      icono: Icons.favorite_rounded,
      detalle: 'Favoritos, playlists y artistas seguidos.',
    ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined),
            selectedIcon: Icon(Icons.music_note_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Biblioteca',
          ),
          NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Ajustes',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
