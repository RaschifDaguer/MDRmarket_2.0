import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';
import 'widgets/requisitos_password.dart';

/// Departamentos donde se expide el carnet (códigos que acepta la API).
const _departamentos = {
  'SC': 'Santa Cruz',
  'LP': 'La Paz',
  'CB': 'Cochabamba',
  'OR': 'Oruro',
  'PT': 'Potosí',
  'CH': 'Chuquisaca',
  'TJ': 'Tarija',
  'BE': 'Beni',
  'PD': 'Pando',
};

/// Crear cuenta: correo, contraseña (dos veces), nombre, apellido y carnet.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _ciNumero = TextEditingController();
  final _ciComplemento = TextEditingController();
  final _password = TextEditingController();
  final _passwordRepetir = TextEditingController();
  String? _ciExpedido = 'SC';
  bool _verPassword = false;
  bool _enviando = false;

  /// Errores que devuelve la API por campo (ej. correo ya registrado).
  Map<String, String> _erroresApi = {};
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    // Redibuja la lista de requisitos mientras se escribe la contraseña.
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _email, _telefono, _ciNumero, _ciComplemento, _password, _passwordRepetir]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    setState(() {
      _erroresApi = {};
      _errorGeneral = null;
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await ref.read(authControllerProvider.notifier).registro(DatosRegistro(
            nombre: _nombre.text.trim(),
            apellido: _apellido.text.trim(),
            email: _email.text.trim(),
            telefono: _telefono.text.trim(),
            ciNumero: _ciNumero.text.trim(),
            ciComplemento: _ciComplemento.text.trim().toUpperCase(),
            ciExpedido: _ciExpedido,
            password: _password.text,
            passwordConfirmacion: _passwordRepetir.text,
          ));
      // Si sale bien, el router lleva solo a la pantalla de inicio.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroresApi = {
          for (final campo in e.errores.keys)
            if (e.errorDe(campo) != null) campo: e.errorDe(campo)!,
        };
        if (_erroresApi.isEmpty) _errorGeneral = e.mensaje;
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _requerido(String? v, String mensaje) => (v == null || v.trim().isEmpty) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    const espacio = SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Titulo('Tus datos'),
                    TextFormField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      forceErrorText: _erroresApi['nombre'],
                      validator: (v) => _requerido(v, 'Escribe tu nombre'),
                    ),
                    espacio,
                    TextFormField(
                      controller: _apellido,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                      forceErrorText: _erroresApi['apellido'],
                      validator: (v) => _requerido(v, 'Escribe tu apellido'),
                    ),
                    espacio,
                    TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Celular (opcional)'),
                      forceErrorText: _erroresApi['telefono'],
                    ),
                    const SizedBox(height: 24),
                    _Titulo('Carnet de identidad'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _ciNumero,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Número de CI'),
                            forceErrorText: _erroresApi['ci_numero'],
                            validator: (v) {
                              if (_requerido(v, '') != null) return 'Escribe tu CI';
                              return RegExp(r'^\d{4,12}$').hasMatch(v!.trim()) ? null : 'Solo números';
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _ciComplemento,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 5,
                            decoration: const InputDecoration(labelText: 'Compl.', counterText: ''),
                            forceErrorText: _erroresApi['ci_complemento'],
                          ),
                        ),
                      ],
                    ),
                    espacio,
                    DropdownButtonFormField<String>(
                      initialValue: _ciExpedido,
                      decoration: const InputDecoration(labelText: 'Expedido en'),
                      items: [
                        for (final d in _departamentos.entries)
                          DropdownMenuItem(value: d.key, child: Text(d.value)),
                      ],
                      onChanged: (v) => setState(() => _ciExpedido = v),
                    ),
                    const SizedBox(height: 24),
                    _Titulo('Cuenta'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo electrónico'),
                      forceErrorText: _erroresApi['email'],
                      validator: (v) {
                        if (_requerido(v, '') != null) return 'Escribe tu correo';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim())
                            ? null
                            : 'Correo no válido';
                      },
                    ),
                    espacio,
                    TextFormField(
                      controller: _password,
                      obscureText: !_verPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        suffixIcon: IconButton(
                          tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
                          icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      forceErrorText: _erroresApi['password'],
                      validator: (v) => ReglasPassword.cumple(v ?? '')
                          ? null
                          : 'La contraseña no cumple los requisitos',
                    ),
                    const SizedBox(height: 8),
                    RequisitosPassword(password: _password.text),
                    espacio,
                    TextFormField(
                      controller: _passwordRepetir,
                      obscureText: !_verPassword,
                      decoration: const InputDecoration(labelText: 'Repetir contraseña'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vuelve a escribir la contraseña';
                        return v == _password.text ? null : 'Las contraseñas no coinciden';
                      },
                    ),
                    if (_errorGeneral != null) ...[
                      const SizedBox(height: 16),
                      Text(_errorGeneral!, style: TextStyle(color: colores.error)),
                    ],
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _enviando ? null : _registrar,
                      child: _enviando
                          ? const SizedBox.square(
                              dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _enviando ? null : () => context.go('/login'),
                      child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
      );
}
