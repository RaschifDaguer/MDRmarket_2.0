import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/maps/selector_ubicacion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../../catalogo/domain/categoria.dart';
import '../../perfil/data/perfil_repository.dart';
import '../data/negocio_repository.dart';

/// Registrar mi negocio: nombre, rubro, ubicación en el mapa, foto y (si
/// faltan) las fotos del carnet. NIT y razón social son opcionales.
/// Al terminar, el usuario ya tiene la vista comerciante (negocio "en revisión").
class RegistrarNegocioScreen extends ConsumerStatefulWidget {
  const RegistrarNegocioScreen({super.key});

  @override
  ConsumerState<RegistrarNegocioScreen> createState() => _RegistrarNegocioScreenState();
}

class _RegistrarNegocioScreenState extends ConsumerState<RegistrarNegocioScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _referencia = TextEditingController();
  final _nit = TextEditingController();
  final _razonSocial = TextEditingController();
  final _apellido = TextEditingController();
  final _ciNumero = TextEditingController();

  int? _categoriaId;
  Coordenada? _ubicacion;
  ArchivoElegido? _foto;
  ArchivoElegido? _ciFrente;
  ArchivoElegido? _ciReverso;

  bool _enviando = false;
  int _temblores = 0;
  Map<String, String> _errores = {};
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _telefono.text = ref.read(authControllerProvider).value?.telefono ?? '';
  }

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _telefono, _direccion, _referencia, _nit, _razonSocial, _apellido, _ciNumero]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Qué datos personales y fotos del carnet faltan (según la API).
  ({bool apellido, bool ci, bool frente, bool reverso}) _pendientes(Usuario usuario) {
    final faltantes = ref.read(faltantesProvider('comerciante')).value ?? const [];
    bool falta(String doc) => faltantes.any((f) => f.documento == doc);
    return (
      apellido: (usuario.apellido ?? '').trim().isEmpty,
      ci: (usuario.ciNumero ?? '').trim().isEmpty,
      frente: falta('ci_anverso'),
      reverso: falta('ci_reverso'),
    );
  }

  bool _validar(Usuario usuario) {
    final p = _pendientes(usuario);
    final errores = <String, String>{
      if (_ubicacion == null) 'ubicacion': 'Marca la ubicación del negocio en el mapa o con el GPS.',
      if (_foto == null) 'foto': 'Agrega una foto del negocio.',
      if (p.frente && _ciFrente == null) 'ci_frente': 'Agrega la foto del frente de tu carnet.',
      if (p.reverso && _ciReverso == null) 'ci_reverso': 'Agrega la foto del reverso de tu carnet.',
    };
    final formularioOk = _form.currentState!.validate();
    setState(() => _errores = errores);
    return formularioOk && errores.isEmpty;
  }

  Future<void> _registrar() async {
    final usuario = ref.read(authControllerProvider).value;
    if (usuario == null) return;

    setState(() => _errorGeneral = null);
    if (!_validar(usuario)) {
      setState(() => _temblores++);
      return;
    }

    final p = _pendientes(usuario);
    final perfil = ref.read(perfilRepositoryProvider);
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);

    try {
      // 1. Cuentas antiguas: completar apellido o CI.
      if (p.apellido || p.ci) {
        ref.read(authControllerProvider.notifier).actualizarUsuario(await perfil.actualizar({
          if (p.apellido) 'apellido': _apellido.text.trim(),
          if (p.ci) 'ci_numero': _ciNumero.text.trim(),
        }));
      }

      // 2. El negocio.
      await ref.read(negocioRepositoryProvider).crear(
            DatosNegocio(
              nombre: _nombre.text,
              categoriaId: _categoriaId!,
              direccion: _direccion.text,
              ubicacion: _ubicacion!,
              descripcion: _descripcion.text,
              telefono: _telefono.text,
              referencia: _referencia.text,
              nit: _nit.text,
              razonSocial: _razonSocial.text,
            ),
            _foto!,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _temblores++;
        _errores = {
          for (final campo in e.errores.keys)
            // latitud/longitud se muestran debajo del mapa.
            (campo == 'latitud' || campo == 'longitud' ? 'ubicacion' : campo): e.errorDe(campo)!,
        };
        if (_errores.isEmpty) _errorGeneral = e.mensaje;
      });
      return;
    }

    // 3. Fotos del carnet. El negocio ya quedó creado: si esto falla, se puede
    //    subir después desde la vista comerciante.
    String? avisoCarnet;
    try {
      if (_ciFrente != null) await perfil.subirDocumento('ci_anverso', _ciFrente!);
      if (_ciReverso != null) await perfil.subirDocumento('ci_reverso', _ciReverso!);
    } on ApiException catch (e) {
      avisoCarnet = 'Tu negocio se registró, pero no se pudo subir el carnet (${e.mensaje}). '
          'Súbelo desde tu vista de comerciante.';
    }

    // 4. Ya es comerciante: se refresca la sesión y se abre esa vista.
    ref.invalidate(misNegociosProvider);
    ref.invalidate(faltantesProvider('comerciante'));
    final sesion = ref.read(authControllerProvider.notifier);
    try {
      await sesion.refrescar();
      await sesion.cambiarVista(Vista.comerciante);
    } on ApiException {
      // Si falla, el usuario igual puede cambiar de vista con el selector.
    }

    if (!mounted) return;
    mensajero.showSnackBar(SnackBar(
      content: Text(avisoCarnet ?? '¡Listo! Tu negocio está registrado y en revisión.'),
      duration: const Duration(seconds: 5),
    ));
    context.go('/inicio');
  }

  String? _requerido(String? v, String mensaje) => (v == null || v.trim().isEmpty) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    final categorias = ref.watch(categoriasProvider);
    final faltantes = ref.watch(faltantesProvider('comerciante'));
    final animar = AppMovimiento.activo(context);

    final cargando = categorias.isLoading || faltantes.isLoading;
    final errorCarga = categorias.error ?? faltantes.error;

    return Scaffold(
      body: FondoMarca(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _cabecera(context),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppEspacios.m + 4, AppEspacios.l, AppEspacios.m + 4, AppEspacios.xl),
                    child: Temblor(
                      disparo: _temblores,
                      child: Tarjeta3D(
                        inclinacionMax: 1,
                        reaccionarAlDedo: false,
                        child: usuario == null || cargando
                            ? const Padding(
                                padding: EdgeInsets.all(AppEspacios.xl),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : errorCarga != null
                                ? _errorDeCarga(errorCarga)
                                : Form(
                                    key: _form,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Aparecer(orden: 1, child: _seccionNegocio(categorias.value!)),
                                        const SizedBox(height: AppEspacios.l + 4),
                                        Aparecer(orden: 2, child: _seccionUbicacion()),
                                        const SizedBox(height: AppEspacios.l + 4),
                                        Aparecer(orden: 3, child: _seccionFoto()),
                                        const SizedBox(height: AppEspacios.l + 4),
                                        Aparecer(orden: 4, child: _seccionFiscal()),
                                        ..._seccionCarnet(usuario),
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
                                          orden: 6,
                                          child: BotonPrincipal(
                                            texto: 'Registrar negocio',
                                            icono: Icons.storefront_outlined,
                                            cargando: _enviando,
                                            onPressed: _registrar,
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

  Widget _errorDeCarga(Object error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvisoError('$error'),
        const SizedBox(height: AppEspacios.m),
        OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(categoriasProvider);
            ref.invalidate(faltantesProvider('comerciante'));
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }

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
                child: BackButton(
                  color: Colors.white,
                  onPressed: _enviando ? null : () => context.go('/inicio'),
                ),
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
                      'Registrar mi negocio',
                      // titleLarge: en celular no choca con los íconos que flotan.
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
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

  Widget _seccionNegocio(List<Categoria> categorias) {
    const espacio = SizedBox(height: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Tu negocio', Icons.storefront_outlined),
        TextFormField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre del negocio', prefixIcon: Icon(Icons.store_outlined)),
          forceErrorText: _errores['nombre'],
          validator: (v) => _requerido(v, 'Escribe el nombre del negocio'),
        ),
        espacio,
        DropdownButtonFormField<int>(
          initialValue: _categoriaId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadios.campo),
          decoration: InputDecoration(
            labelText: 'Rubro',
            prefixIcon: const Icon(Icons.category_outlined),
            errorText: _errores['categoria_id'],
          ),
          items: [
            for (final c in categorias)
              DropdownMenuItem(value: c.id, child: Text(c.etiqueta, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _categoriaId = v),
          validator: (v) => v == null ? 'Elige el rubro de tu negocio' : null,
        ),
        espacio,
        TextFormField(
          controller: _descripcion,
          maxLines: 3,
          minLines: 2,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Descripción (opcional)',
            hintText: 'Qué vendes, horarios, lo que te hace especial…',
            prefixIcon: Icon(Icons.notes_outlined),
            alignLabelWithHint: true,
          ),
          forceErrorText: _errores['descripcion'],
        ),
        espacio,
        TextFormField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Teléfono (opcional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          forceErrorText: _errores['telefono'],
        ),
      ],
    );
  }

  Widget _seccionUbicacion() {
    const espacio = SizedBox(height: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Ubicación', Icons.place_outlined),
        SelectorUbicacion(
          valor: _ubicacion,
          error: _errores['ubicacion'],
          alCambiar: (punto) => setState(() {
            _ubicacion = punto;
            _errores = {..._errores}..remove('ubicacion');
          }),
        ),
        espacio,
        TextFormField(
          controller: _direccion,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Dirección',
            hintText: 'Ej. Av. Busch 1234, 3er anillo',
            prefixIcon: Icon(Icons.signpost_outlined),
          ),
          forceErrorText: _errores['direccion'],
          validator: (v) => _requerido(v, 'Escribe la dirección'),
        ),
        espacio,
        TextFormField(
          controller: _referencia,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Referencia (opcional)',
            hintText: 'Ej. Frente a la plaza, portón verde',
            prefixIcon: Icon(Icons.info_outline),
          ),
          forceErrorText: _errores['referencia'],
        ),
      ],
    );
  }

  Widget _seccionFoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Foto del negocio', Icons.photo_camera_outlined),
        SelectorFoto(
          valor: _foto,
          texto: 'La fachada o el logo de tu negocio',
          icono: Icons.add_photo_alternate_outlined,
          error: _errores['foto'],
          alElegir: (foto) => setState(() {
            _foto = foto;
            _errores = {..._errores}..remove('foto');
          }),
        ),
      ],
    );
  }

  Widget _seccionFiscal() {
    const espacio = SizedBox(height: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Datos fiscales', Icons.receipt_long_outlined, opcional: true),
        TextFormField(
          controller: _nit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'NIT',
            helperText: 'Si no tienes NIT, se usa tu carnet de identidad.',
            helperMaxLines: 2,
            prefixIcon: Icon(Icons.numbers),
          ),
          forceErrorText: _errores['nit'],
        ),
        espacio,
        TextFormField(
          controller: _razonSocial,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Razón social', prefixIcon: Icon(Icons.business_outlined)),
          forceErrorText: _errores['razon_social'],
        ),
      ],
    );
  }

  /// Solo aparece si falta algo del carnet (cuentas nuevas: las fotos).
  List<Widget> _seccionCarnet(Usuario usuario) {
    final p = _pendientes(usuario);
    if (!p.apellido && !p.ci && !p.frente && !p.reverso) return const [];
    const espacio = SizedBox(height: 14);

    return [
      const SizedBox(height: AppEspacios.l + 4),
      Aparecer(
        orden: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloSeccion('Tu carnet de identidad', Icons.credit_card),
            Text(
              'Lo pedimos una sola vez para verificar que el negocio es tuyo. Solo lo ve el equipo de MDR Market.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            espacio,
            if (p.apellido) ...[
              TextFormField(
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.badge_outlined)),
                forceErrorText: _errores['apellido'],
                validator: (v) => _requerido(v, 'Escribe tu apellido'),
              ),
              espacio,
            ],
            if (p.ci) ...[
              TextFormField(
                controller: _ciNumero,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de CI', prefixIcon: Icon(Icons.credit_card)),
                forceErrorText: _errores['ci_numero'],
                validator: (v) {
                  if (_requerido(v, '') != null) return 'Escribe tu CI';
                  return RegExp(r'^\d{4,12}$').hasMatch(v!.trim()) ? null : 'Solo números';
                },
              ),
              espacio,
            ],
            if (p.frente || p.reverso)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.frente)
                    Expanded(
                      child: SelectorFoto(
                        valor: _ciFrente,
                        texto: 'Frente',
                        icono: Icons.badge_outlined,
                        alto: 130,
                        error: _errores['ci_frente'],
                        alElegir: (f) => setState(() {
                          _ciFrente = f;
                          _errores = {..._errores}..remove('ci_frente');
                        }),
                      ),
                    ),
                  if (p.frente && p.reverso) const SizedBox(width: AppEspacios.m - 4),
                  if (p.reverso)
                    Expanded(
                      child: SelectorFoto(
                        valor: _ciReverso,
                        texto: 'Reverso',
                        icono: Icons.flip_outlined,
                        alto: 130,
                        error: _errores['ci_reverso'],
                        alElegir: (f) => setState(() {
                          _ciReverso = f;
                          _errores = {..._errores}..remove('ci_reverso');
                        }),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    ];
  }
}
