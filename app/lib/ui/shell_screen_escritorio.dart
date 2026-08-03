import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ajustes_screen.dart';
import 'biblioteca_screen.dart';
import 'buscar_screen.dart';
import 'inicio_screen.dart';
import 'widgets/barra_lateral_escritorio.dart';
import 'widgets/panel_reproduciendo_escritorio.dart';
import 'widgets/reproductor_bar_escritorio.dart';

/// Que pantalla del nivel superior se ve en el shell de escritorio.
///
/// Es un provider y no un campo de `State` porque el contenido vive dentro de
/// su propio [Navigator] (para que abrir un album/playlist no tape la barra
/// lateral): ese Navigator no vuelve a llamar a `onGenerateRoute` solo porque
/// el widget padre se reconstruyo, pero un provider si dispara la
/// reconstruccion exacta de quien lo mira.
final indiceEscritorioProvider = StateProvider<int>((ref) => 0);

/// Version de escritorio de [ShellScreen]: barra lateral (con las playlists,
/// no solo los 4 destinos) en vez de barra inferior, grillas mas generosas
/// (ver `esEscritorio` en `inicio_screen.dart`/`biblioteca_screen.dart`),
/// una barra de reproduccion con los controles de siempre a la vista, un
/// panel de cola que se puede abrir al costado, y un [Navigator] propio para
/// el contenido — asi entrar a un album o una playlist navega adentro de esa
/// columna nada mas, sin tapar el resto del shell.
class ShellScreenEscritorio extends ConsumerStatefulWidget {
  const ShellScreenEscritorio({super.key});

  @override
  ConsumerState<ShellScreenEscritorio> createState() =>
      _ShellScreenEscritorioState();
}

class _ShellScreenEscritorioState extends ConsumerState<ShellScreenEscritorio> {
  final _navegadorContenido = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final panelAbierto = ref.watch(panelReproduciendoAbiertoProvider);
    final superficie = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  BarraLateralEscritorio(
                    navegadorContenido: _navegadorContenido,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      // Cada pantalla de adentro (Inicio, Album, etc.) trae
                      // su propio Scaffold, y el fondo de un Scaffold tapa
                      // cualquier color que se ponga alrededor. Para que todo
                      // el contenido se vea como una sola tarjeta pareja con
                      // la barra lateral (y no solo se note en Album/Playlist,
                      // que traen su propio degrade), se pisa el fondo por
                      // defecto de los Scaffold de este subarbol nada mas.
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(scaffoldBackgroundColor: superficie),
                        child: Navigator(
                          key: _navegadorContenido,
                          onGenerateRoute: (settings) => MaterialPageRoute(
                            settings: settings,
                            builder: (_) => const _ContenidoPrincipal(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (panelAbierto) ...[
                    const SizedBox(width: 12),
                    const PanelReproduciendoEscritorio(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const ReproductorBarEscritorio(),
          ],
        ),
      ),
    );
  }
}

class _ContenidoPrincipal extends ConsumerWidget {
  const _ContenidoPrincipal();

  static const _pantallas = <Widget>[
    InicioScreen(),
    BuscarScreen(),
    BibliotecaScreen(),
    AjustesScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indice = ref.watch(indiceEscritorioProvider);
    return IndexedStack(index: indice, children: _pantallas);
  }
}
