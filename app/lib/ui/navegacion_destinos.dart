import 'package:flutter/material.dart';

/// Los 4 destinos del nivel superior de navegacion, compartidos entre el
/// shell movil ([ShellScreen], barra inferior) y el de escritorio
/// ([ShellScreenEscritorio], barra lateral) para que no diverjan con el
/// tiempo.
class DestinoNav {
  const DestinoNav({
    required this.icono,
    required this.iconoSeleccionado,
    required this.etiqueta,
  });

  final IconData icono;
  final IconData iconoSeleccionado;
  final String etiqueta;
}

const destinosNav = <DestinoNav>[
  DestinoNav(
    icono: Icons.music_note_outlined,
    iconoSeleccionado: Icons.music_note_rounded,
    etiqueta: 'Inicio',
  ),
  DestinoNav(
    icono: Icons.search_outlined,
    iconoSeleccionado: Icons.search_rounded,
    etiqueta: 'Buscar',
  ),
  // Un corazon aca decia "favoritos", y la pestaña es mas que eso: tambien
  // tiene playlists, albumes, artistas y descargas.
  DestinoNav(
    icono: Icons.library_music_outlined,
    iconoSeleccionado: Icons.library_music_rounded,
    etiqueta: 'Biblioteca',
  ),
  DestinoNav(
    icono: Icons.settings_outlined,
    iconoSeleccionado: Icons.settings_rounded,
    etiqueta: 'Ajustes',
  ),
];
