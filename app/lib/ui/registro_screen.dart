import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/registro_client.dart';
import 'widgets/marca.dart';

/// Crea una cuenta nueva en el servidor.
///
/// Devuelve por el Navigator el usuario creado, para que el login lo deje
/// puesto. No inicia sesion sola: que la persona escriba su contrasena una vez
/// mas es barato y evita entrar con un tipeo que no queria.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repetirCtrl = TextEditingController();
  final _invitacionCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    _repetirCtrl.dispose();
    _invitacionCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref
          .read(registroClientProvider)
          .crearCuenta(
            usuario: _usuarioCtrl.text,
            password: _passwordCtrl.text,
            invitacion: _invitacionCtrl.text,
          );

      if (!mounted) return;
      Navigator.of(context).pop(_usuarioCtrl.text.trim());
    } on RegistroException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocurrio un error inesperado al registrarte.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: LogoMarca(tamano: 64)),
                    const SizedBox(height: 22),
                    Text(
                      'Necesitas un codigo de invitacion. Pideselo a quien te '
                      'paso la app.',
                      style: textos.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _usuarioCtrl,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        helperText: 'Sin espacios. Es con lo que vas a entrar.',
                      ),
                      validator: _validarUsuario,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Contrasena',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _verPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Usa al menos 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _repetirCtrl,
                      obscureText: !_verPassword,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Repetir contrasena',
                      ),
                      validator: (v) => (v != _passwordCtrl.text)
                          ? 'Las contrasenas no coinciden'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _invitacionCtrl,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _crear(),
                      decoration: const InputDecoration(
                        labelText: 'Codigo de invitacion',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe el codigo de invitacion'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      MensajeError(_error!),
                    ],
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _cargando ? null : _crear,
                      child: _cargando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El servicio valida lo mismo, pero avisar antes de mandar evita un viaje
  /// de ida y vuelta para decir algo que ya se sabia.
  String? _validarUsuario(String? valor) {
    final usuario = valor?.trim() ?? '';
    if (usuario.isEmpty) return 'Escribe un usuario';
    if (usuario.length < 3) return 'Usa al menos 3 caracteres';
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(usuario)) {
      return 'Solo letras, numeros, punto, guion y guion bajo';
    }
    return null;
  }
}

final registroClientProvider = Provider<RegistroClient>(
  (ref) => RegistroClient(),
);
