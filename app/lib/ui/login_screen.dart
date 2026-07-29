import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/subsonic_client.dart';
import '../core/theme.dart';
import '../state/sesion_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlRemotaCtrl = TextEditingController();
  final _urlLocalCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _urlRemotaCtrl.dispose();
    _urlLocalCtrl.dispose();
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
            urlRemota: _urlRemotaCtrl.text,
            urlLocal: _urlLocalCtrl.text,
            usuario: _usuarioCtrl.text,
            password: _passwordCtrl.text,
          );
      // Si sale bien no hay que navegar: el gate en main.dart reacciona al
      // cambio de estado y reemplaza esta pantalla.
    } on SubsonicException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocurrió un error inesperado al conectar.');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
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
                    const _Logo(),
                    const SizedBox(height: 28),
                    Text('mi spotify', style: textos.displaySmall),
                    const SizedBox(height: 6),
                    Text(
                      'Conectate a tu servidor de música.',
                      style: textos.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _urlRemotaCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Servidor (Tailscale)',
                        hintText: '100.91.22.33:4533',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá la dirección del servidor'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _urlLocalCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'En tu red de casa (opcional)',
                        hintText: '192.168.1.194:4533',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Si la completás, en casa se conecta por acá — más rápido '
                      'y sin depender de Tailscale.',
                      style: textos.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usuarioCtrl,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Usuario'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresá tu usuario'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_verPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
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
                          ? 'Ingresá tu contraseña'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      _MensajeError(_error!),
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
                    const SizedBox(height: 18),
                    Text(
                      'Fuera de casa necesitás Tailscale activo en el teléfono.',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall,
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      width: 76,
      decoration: BoxDecoration(
        color: AppColors.naranja,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colores.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colores.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colores.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
