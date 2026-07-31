import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../state/sesion_providers.dart';
import 'registro_screen.dart';
import 'widgets/marca.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await ref
          .read(sesionProvider.notifier)
          .iniciarSesion(
            usuario: _usuarioCtrl.text,
            password: _passwordCtrl.text,
          );
      // Si sale bien no hay que navegar: el gate en main.dart reacciona al
      // cambio de estado y reemplaza esta pantalla.
    } on SubsonicException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocurrio un error inesperado al conectar.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _irARegistro() async {
    final usuarioCreado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegistroScreen()),
    );

    // Vuelve con el usuario recien creado: se deja puesto para que solo tenga
    // que escribir la contrasena. Si cancelo, no se toca nada.
    if (usuarioCreado != null && mounted) {
      setState(() {
        _usuarioCtrl.text = usuarioCreado;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LogoMarca(),
                    const SizedBox(height: 28),
                    Text('Mi Music', style: textos.displaySmall),
                    const SizedBox(height: 6),
                    Text(
                      'Entra con tu cuenta para escuchar tu musica.',
                      style: textos.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usuarioCtrl,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe tu usuario'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _entrar(),
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
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Escribe tu contrasena'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      MensajeError(_error!),
                    ],
                    const SizedBox(height: 26),
                    FilledButton(
                      onPressed: _cargando ? null : _entrar,
                      child: _cargando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _cargando ? null : _irARegistro,
                      child: const Text('No tengo cuenta, quiero crear una'),
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
}
