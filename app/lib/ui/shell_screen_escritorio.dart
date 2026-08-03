import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/reproductor_providers.dart';
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
  final _historial = _HistorialAdelante();

  /// Boton 4/5 del mouse (los "de los costados"): atras y adelante, igual
  /// que en el navegador. Un `Listener` no le saca el click a nadie (a
  /// diferencia de un `GestureDetector`), asi que envolver toda la pantalla
  /// no interfiere con tocar nada de lo que hay abajo.
  void _clickMouse(PointerDownEvent evento) {
    if (evento.buttons & kBackMouseButton != 0) {
      _navegadorContenido.currentState?.maybePop();
    } else if (evento.buttons & kForwardMouseButton != 0) {
      _historial.avanzar(_navegadorContenido.currentState!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final panelAbierto = ref.watch(panelReproduciendoAbiertoProvider);
    final superficie = Theme.of(context).colorScheme.surfaceContainerHighest;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            alternarReproduccion(ref),
      },
      child: Focus(
        autofocus: true,
        child: Listener(
          onPointerDown: _clickMouse,
          child: Scaffold(
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
                            // Cada pantalla de adentro (Inicio, Album, etc.)
                            // trae su propio Scaffold, y el fondo de un
                            // Scaffold tapa cualquier color que se ponga
                            // alrededor. Para que todo el contenido se vea
                            // como una sola tarjeta pareja con la barra
                            // lateral (y no solo se note en Album/Playlist,
                            // que traen su propio degrade), se pisa el fondo
                            // por defecto de los Scaffold de este subarbol
                            // nada mas.
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(scaffoldBackgroundColor: superficie),
                              child: Navigator(
                                key: _navegadorContenido,
                                observers: [_historial],
                                onGenerateRoute: (settings) =>
                                    MaterialPageRoute(
                                      settings: settings,
                                      builder: (_) =>
                                          const _ContenidoPrincipal(),
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
          ),
        ),
      ),
    );
  }
}

/// Historial de "adelante" para el boton 5 del mouse.
///
/// `Navigator` de Flutter solo trae pila de "atras" (`pop`); no existe un
/// equivalente a "adelante" del navegador. Se arma a mano: cada pantalla
/// sacada (`didPop`) guarda su `builder` — la misma funcion que ya la
/// construyo la primera vez, disponible como campo publico de
/// `MaterialPageRoute` — para poder reconstruirla en una ruta **nueva** el
/// dia que se pida "adelante". No se reusa el `Route` que se saco: una vez
/// que sale de escena pierde el estado que necesita para reinsertarse tal
/// cual, asi que arrancar una copia nueva con el mismo builder es lo que
/// imita mejor la pagina que uno tenia antes de ir para atras.
///
/// Navegar a algo nuevo mientras hay pantallas "adelante" pendientes las
/// descarta — es lo mismo que hace cualquier navegador: click en un link
/// nuevo despues de ir para atras borra el "adelante" que quedaba.
class _HistorialAdelante extends NavigatorObserver {
  final List<WidgetBuilder> _adelante = [];
  bool _reproduciendoAvance = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_reproduciendoAvance) _adelante.clear();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute) _adelante.add(route.builder);
  }

  void avanzar(NavigatorState navegador) {
    if (_adelante.isEmpty) return;
    final builder = _adelante.removeLast();

    _reproduciendoAvance = true;
    navegador
        .push(MaterialPageRoute(builder: builder))
        .whenComplete(() => _reproduciendoAvance = false);
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
