import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/biblioteca.dart';
import '../../state/descargas_providers.dart';
import '../../state/favoritos_providers.dart';
import '../acciones_descarga.dart';
import 'portada.dart';

/// Tarjeta vertical de album para los carruseles y la grilla.
class TarjetaAlbum extends StatelessWidget {
  const TarjetaAlbum({
    required this.album,
    required this.lado,
    this.onTap,
    super.key,
  });

  final Album album;
  final double lado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: lado,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Portada(coverArt: album.coverArt, lado: lado),
            const SizedBox(height: 10),
            Text(
              album.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              album.artista,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de cancion: portada chica, titulo, artista y duracion.
///
/// Con [sonando] en true se pinta de naranja y cambia la duracion por un
/// icono de ecualizador, para que se vea de un golpe cual de la lista esta
/// reproduciendose.
class FilaCancion extends ConsumerWidget {
  const FilaCancion({
    required this.cancion,
    this.onTap,
    this.onAgregarACola,
    this.onAlternarFavorito,
    this.onGuardarEnPlaylist,
    this.onQuitarDePlaylist,
    this.sonando = false,
    super.key,
  });

  final Cancion cancion;
  final VoidCallback? onTap;

  /// Si se pasa, aparece el menu "..." con la opcion de encolar.
  final VoidCallback? onAgregarACola;

  /// Si se pasa, el menu "..." incluye marcar o desmarcar favorito.
  final VoidCallback? onAlternarFavorito;

  /// Si se pasa, el menu "..." abre la hoja para guardar en una playlist.
  final VoidCallback? onGuardarEnPlaylist;

  /// Solo lo pasa la pantalla de una playlist, que es donde tiene sentido.
  final VoidCallback? onQuitarDePlaylist;

  final bool sonando;

  bool get _tieneMenu =>
      onAgregarACola != null ||
      onAlternarFavorito != null ||
      onGuardarEnPlaylist != null ||
      onQuitarDePlaylist != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;

    // A diferencia de las demas acciones, descargar no depende de la pantalla
    // en la que este la fila: es siempre "guarda esta cancion". Por eso se
    // resuelve aqui adentro en vez de pedirle un callback a cada pantalla.
    final descarga = ref.watch(archivosDescargadosProvider)[cancion.id];
    final enCamino = ref.watch(idsEnDescargaProvider).contains(cancion.id);

    // El naranja de marca no tiene contraste suficiente sobre blanco, asi que
    // en tema claro se usa la variante oscurecida.
    final acento = tema.brightness == Brightness.dark
        ? AppColors.naranja
        : AppColors.naranjaTexto;

    final fila = InkWell(
      onTap: onTap,
      child: Container(
        color: sonando ? acento.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Portada(coverArt: cancion.coverArt, lado: 52, radio: 12),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cancion.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleMedium?.copyWith(
                      color: sonando ? acento : null,
                      fontWeight: sonando ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cancion.artista,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (enCamino)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: textos.bodySmall?.color,
                ),
              )
            else if (descarga != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.download_done_rounded,
                  size: 16,
                  color: acento,
                ),
              ),
            // Ancho fijo y pegado a la derecha. Poppins no es monoespaciada,
            // asi que "0:19" mide menos que "4:02" y, sin esto, el icono de
            // descargado que va antes queda unos pixeles corrido en cada fila.
            // Alcanza para "1:02:33", que es el formato mas largo que se arma.
            SizedBox(
              width: 52,
              child: Align(
                alignment: Alignment.centerRight,
                child: sonando
                    ? Icon(Icons.graphic_eq_rounded, size: 20, color: acento)
                    : Text(cancion.duracionFormateada, style: textos.bodySmall),
              ),
            ),
            if (_tieneMenu)
              PopupMenuButton<void>(
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: 'Más opciones',
                // El menu se cierra antes de correr el `onTap`, asi que las
                // acciones usan el contexto de la fila y no el del menu, que
                // para entonces ya no existe.
                itemBuilder: (_) {
                  final esFavorito = ref
                      .read(idsFavoritosProvider)
                      .contains(cancion.id);

                  return [
                    if (onAlternarFavorito != null)
                      PopupMenuItem<void>(
                        onTap: onAlternarFavorito,
                        child: Row(
                          children: [
                            Icon(
                              esFavorito
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color: esFavorito ? AppColors.naranja : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              esFavorito
                                  ? 'Quitar de favoritos'
                                  : 'Agregar a favoritos',
                            ),
                          ],
                        ),
                      ),
                    if (onAgregarACola != null)
                      PopupMenuItem<void>(
                        onTap: onAgregarACola,
                        child: const Row(
                          children: [
                            Icon(Icons.queue_music_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Reproducir a continuación'),
                          ],
                        ),
                      ),
                    if (onGuardarEnPlaylist != null)
                      PopupMenuItem<void>(
                        onTap: onGuardarEnPlaylist,
                        child: const Row(
                          children: [
                            Icon(Icons.playlist_add_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Guardar en playlist'),
                          ],
                        ),
                      ),
                    if (onQuitarDePlaylist != null)
                      PopupMenuItem<void>(
                        onTap: onQuitarDePlaylist,
                        child: const Row(
                          children: [
                            Icon(Icons.playlist_remove_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Quitar de la playlist'),
                          ],
                        ),
                      ),
                    if (descarga != null)
                      PopupMenuItem<void>(
                        onTap: () => quitarDescarga(context, ref, descarga),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Borrar del teléfono'),
                          ],
                        ),
                      )
                    else if (!enCamino)
                      PopupMenuItem<void>(
                        onTap: () => descargar(context, ref, [cancion]),
                        child: const Row(
                          children: [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Descargar'),
                          ],
                        ),
                      ),
                  ];
                },
              ),
          ],
        ),
      ),
    );

    if (onAgregarACola == null) return fila;

    return Dismissible(
      // Por instancia y no por id: en una playlist la misma cancion puede
      // estar repetida y dos Dismissible hermanos no pueden compartir clave.
      key: ObjectKey(cancion),
      direction: DismissDirection.startToEnd,
      // Nunca se descarta de verdad: el gesto es un atajo para encolar, asi
      // que se ejecuta la accion y la fila vuelve sola a su lugar.
      confirmDismiss: (_) async {
        onAgregarACola!();
        return false;
      },
      dismissThresholds: const {DismissDirection.startToEnd: 0.28},
      background: Container(
        color: acento.withValues(alpha: 0.16),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, color: acento),
            const SizedBox(width: 10),
            Text(
              'A continuación',
              style: textos.labelLarge?.copyWith(color: acento),
            ),
          ],
        ),
      ),
      child: fila,
    );
  }
}

/// Fila de playlist. La portada la arma el servidor con los temas que tiene
/// adentro, asi que una playlist vacia cae en el marcador generico.
class FilaPlaylist extends StatelessWidget {
  const FilaPlaylist({required this.playlist, this.onTap, super.key});

  final Playlist playlist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Portada(coverArt: playlist.coverArt, lado: 52, radio: 12),
      title: Text(
        playlist.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textos.titleMedium,
      ),
      subtitle: Text(playlist.resumen, style: textos.bodySmall),
      onTap: onTap,
    );
  }
}

/// Fila de artista, con la portada redonda.
class FilaArtista extends StatelessWidget {
  const FilaArtista({required this.artista, this.onTap, super.key});

  final Artista artista;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final albumes = artista.cantidadAlbumes;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Portada(coverArt: artista.coverArt, lado: 56, circular: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artista.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.titleMedium,
                  ),
                  if (albumes != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      albumes == 1 ? '1 álbum' : '$albumes álbumes',
                      style: textos.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
