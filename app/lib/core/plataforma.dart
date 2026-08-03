import 'dart:io' show Platform;

/// Si corresponde mostrar el shell de escritorio (barra lateral) en vez del
/// de movil (barra inferior).
///
/// Cubre solo Windows a proposito: es el unico destino de escritorio que se
/// construyo y probo. Sumar Linux o macOS el dia que haga falta es agregar
/// un `||` aca, no reescribir nada.
bool get esEscritorio => Platform.isWindows;
