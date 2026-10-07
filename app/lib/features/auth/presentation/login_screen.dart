import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _verPassword = false;
  bool _enviando = false;
  String? _error;

  /// Sube en 1 cada vez que hay un error: hace temblar el formulario.
  int _temblores = 0;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) {
      setState(() => _temblores++);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      // Si sale bien, el router lleva solo a la pantalla de inicio.
      await ref.read(authControllerProvider.notifier).login(_email.text.trim(), _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _temblores++;
        });
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final animar = AppMovimiento.activo(context);

    return Scaffold(
      body: FondoMarca(
        child: SingleChildScrollView(
          child: Column(
            children: [
              CabeceraFlotante(
                altura: 300,
                child: Padding(
                  // Deja lugar abajo para la tarjeta que se monta encima.
                  padding: const EdgeInsets.only(bottom: AppEspacios.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Aparecer(child: LogoMarca(tamano: 76, sobreColor: true)),
                      const SizedBox(height: AppEspacios.m - 2),
                      Aparecer(
                        orden: 1,
                        child: Text('MDR Market',
                            style: textos.headlineMedium?.copyWith(color: Colors.white)),
                      ),
                      const SizedBox(height: AppEspacios.xs),
                      Aparecer(
                        orden: 2,
                        child: Text('Inicia sesión para continuar',
                            style: textos.bodyLarge
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                      ),
                    ],
                  ),
                ),
              ),
              // La tarjeta sube 56 px para quedar montada sobre la cabecera.
              Transform.translate(
                offset: const Offset(0, -56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppEspacios.m + 4),
                      child: Temblor(
                        disparo: _temblores,
                        child: Tarjeta3D(
                          inclinacionMax: 3,
                          reaccionarAlDedo: false,
                          child: _formulario(animar),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulario(bool animar) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Aparecer(
            orden: 3,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu correo' : null,
            ),
          ),
          const SizedBox(height: AppEspacios.m),
          Aparecer(
            orden: 4,
            child: TextFormField(
              controller: _password,
              obscureText: !_verPassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _entrar(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
                  icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _verPassword = !_verPassword),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
            ),
          ),
          // El aviso de error se abre suavemente en vez de aparecer de golpe.
          AnimatedSize(
            duration: animar ? AppMovimiento.normal : Duration.zero,
            curve: AppMovimiento.curva,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppEspacios.m),
                    child: AvisoError(_error!),
                  ),
          ),
          const SizedBox(height: AppEspacios.l),
          Aparecer(
            orden: 5,
            child: BotonPrincipal(
              texto: 'Iniciar sesión',
              cargando: _enviando,
              onPressed: _entrar,
            ),
          ),
          const SizedBox(height: AppEspacios.s + 4),
          Aparecer(
            orden: 6,
            child: TextButton(
              onPressed: _enviando ? null : () => context.go('/registro'),
              child: const Text('¿No tienes cuenta? Regístrate'),
            ),
          ),
        ],
      ),
    );
  }
}
