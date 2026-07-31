/// Direcciones fijas del servidor.
///
/// Antes se pedian en el login, pero el servidor es siempre el mismo: hacer
/// que cada persona tipee una IP y un puerto solo servia para equivocarse. Al
/// tenerlas aca, cambiar el acceso remoto es cambiar una linea y recompilar,
/// en vez de pedirle a cada uno que edite su login.
class Servidor {
  const Servidor._();

  /// La que funciona desde cualquier lado: dominio DDNS + puerto abierto.
  static const String urlRemota = 'http://mimusic.duckdns.org:34533';

  /// La de la red de casa. Es mas rapida y no sale a internet, por eso se
  /// prueba primero. Si no responde (estas afuera), se cae a la remota sola.
  static const String urlLocal = 'http://192.168.1.194:4533';

  /// Orden de preferencia con el que el cliente sondea.
  static const List<String> urls = [urlLocal, urlRemota];

  /// Servicio que crea usuarios en Navidrome. Va aparte porque Navidrome no
  /// tiene registro publico: crear un usuario exige credenciales de admin, y
  /// esas no pueden vivir dentro del APK. Ver infra/registro/.
  static const String urlRegistro = 'http://mimusic.duckdns.org:34534';
}
