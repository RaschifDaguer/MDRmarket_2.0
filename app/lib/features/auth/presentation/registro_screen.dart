import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
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

  /// Sube en 1 cada vez que hay un error: hace temblar el formulario.
  int _temblores = 0;

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
    if (!_form.currentState!.validate()) {
      setState(() => _temblores++);
      return;
    }

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
        _temblores++;
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String? _requerido(String? v, String mensaje) => (v == null || v.trim().isEmpty) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    final animar = AppMovimiento.activo(context);
    const espacio = SizedBox(height: 14);

    return Scaffold(
      body: FondoMarca(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _cabecera(context),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppEspacios.m + 4, AppEspacios.l, AppEspacios.m + 4, AppEspacios.xl),
                    child: Temblor(
                      disparo: _temblores,
                      child: Tarjeta3D(
                        inclinacionMax: 2,
                        reaccionarAlDedo: false,
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Aparecer(orden: 1, child: _seccionDatos(espacio)),
                              const SizedBox(height: AppEspacios.l + 4),
                              Aparecer(orden: 2, child: _seccionCarnet(espacio)),
                              const SizedBox(height: AppEspacios.l + 4),
                              Aparecer(orden: 3, child: _seccionCuenta(espacio)),
                              // El aviso de error se abre suavemente en vez de aparecer de golpe.
                              AnimatedSize(
                                duration: animar ? AppMovimiento.normal : Duration.zero,
                                curve: AppMovimiento.curva,
                                child: _errorGeneral == null
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(top: AppEspacios.m),
                                        child: AvisoError(_errorGeneral!),
                                      ),
                              ),
                              const SizedBox(height: AppEspacios.l + 4),
                              Aparecer(
                                orden: 4,
                                child: BotonPrincipal(
                                  texto: 'Crear cuenta',
                                  cargando: _enviando,
                                  onPressed: _registrar,
                                ),
                              ),
                              const SizedBox(height: AppEspacios.s),
                              Aparecer(
                                orden: 5,
                                child: TextButton(
                                  onPressed: _enviando ? null : () => context.go('/login'),
                                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                                ),
                              ),
                            ],
                          ),
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

  /// Cabecera baja: botón para volver al login, logo pequeño y título.
  Widget _cabecera(BuildContext context) {
    return CabeceraFlotante(
      altura: 170,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppEspacios.s),
                child: BackButton(color: Colors.white, onPressed: () => context.go('/login')),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Aparecer(child: LogoMarca(tamano: 52, sobreColor: true)),
                  const SizedBox(height: AppEspacios.m - 4),
                  Aparecer(
                    orden: 1,
                    child: Text(
                      'Crear cuenta',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDatos(Widget espacio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Tus datos', Icons.person_outline),
        TextFormField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          forceErrorText: _erroresApi['nombre'],
          validator: (v) => _requerido(v, 'Escribe tu nombre'),
        ),
        espacio,
        TextFormField(
          controller: _apellido,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Apellido',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          forceErrorText: _erroresApi['apellido'],
          validator: (v) => _requerido(v, 'Escribe tu apellido'),
        ),
        espacio,
        TextFormField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Celular (opcional)',
            prefixIcon: Icon(Icons.phone_iphone),
          ),
          forceErrorText: _erroresApi['telefono'],
        ),
      ],
    );
  }

  Widget _seccionCarnet(Widget espacio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Carnet de identidad', Icons.credit_card),
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
          borderRadius: BorderRadius.circular(AppRadios.campo),
          decoration: const InputDecoration(
            labelText: 'Expedido en',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          items: [
            for (final d in _departamentos.entries)
              DropdownMenuItem(value: d.key, child: Text(d.value)),
          ],
          onChanged: (v) => setState(() => _ciExpedido = v),
        ),
      ],
    );
  }

  Widget _seccionCuenta(Widget espacio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Cuenta', Icons.lock_outline),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email_outlined),
          ),
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
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              tooltip: _verPassword ? 'Ocultar' : 'Mostrar',
              icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _verPassword = !_verPassword),
            ),
          ),
          forceErrorText: _erroresApi['password'],
          validator: (v) =>
              ReglasPassword.cumple(v ?? '') ? null : 'La contraseña no cumple los requisitos',
        ),
        const SizedBox(height: AppEspacios.m - 4),
        RequisitosPassword(password: _password.text),
        espacio,
        TextFormField(
          controller: _passwordRepetir,
          obscureText: !_verPassword,
          decoration: const InputDecoration(
            labelText: 'Repetir contraseña',
            prefixIcon: Icon(Icons.key_outlined),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Vuelve a escribir la contraseña';
            return v == _password.text ? null : 'Las contraseñas no coinciden';
          },
        ),
      ],
    );
  }
}

/// Título de sección con un ícono en un cuadradito de color.
class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, this.icono);

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspacios.m - 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 18, color: c.onSecondaryContainer),
          ),
          const SizedBox(width: AppEspacios.s + 2),
          Flexible(child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
    );
  }
}
