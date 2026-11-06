import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/theme/app_movimiento.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/domain/usuario.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../perfil/data/perfil_repository.dart';
import '../data/repartidor_repository.dart';
import '../domain/repartidor.dart';
import '../domain/tipo_vehiculo.dart';

/// "Quiero ser repartidor": tipo de vehículo y sus datos (placa y RUAT solo si
/// el tipo los pide). Las fotos se suben después, desde la vista repartidor
/// ("Te falta subir…"). Si le rechazaron la solicitud, muestra el motivo y
/// permite volver a enviarla.
class RegistrarRepartidorScreen extends ConsumerStatefulWidget {
  const RegistrarRepartidorScreen({super.key});

  @override
  ConsumerState<RegistrarRepartidorScreen> createState() => _RegistrarRepartidorScreenState();
}

class _RegistrarRepartidorScreenState extends ConsumerState<RegistrarRepartidorScreen> {
  final _form = GlobalKey<FormState>();
  final _placa = TextEditingController();
  final _ruat = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _color = TextEditingController();
  final _anio = TextEditingController();
  final _apellido = TextEditingController();
  final _ciNumero = TextEditingController();

  TipoVehiculo? _tipo;

  /// Ya se hizo POST /repartidor en esta pantalla (si después falla el
  /// vehículo, al reintentar no se vuelve a pedir).
  bool _solicitado = false;

  bool _enviando = false;
  int _temblores = 0;
  Map<String, String> _errores = {};
  String? _errorGeneral;

  @override
  void dispose() {
    for (final c in [_placa, _ruat, _marca, _modelo, _color, _anio, _apellido, _ciNumero]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validar() {
    final errores = <String, String>{
      if (_tipo == null) 'tipo_vehiculo_id': 'Elige el tipo de vehículo.',
    };
    final formularioOk = _form.currentState!.validate();
    setState(() => _errores = errores);
    return formularioOk && errores.isEmpty;
  }

  /// Envía la solicitud. [perfil] es lo que ya tiene (null si es la primera vez).
  Future<void> _enviar(Usuario usuario, PerfilRepartidor? perfil) async {
    final conVehiculo = perfil?.vehiculo != null;
    setState(() => _errorGeneral = null);
    if (!conVehiculo && !_validar()) {
      setState(() => _temblores++);
      return;
    }

    final repartidor = ref.read(repartidorRepositoryProvider);
    final mensajero = ScaffoldMessenger.of(context);
    final faltaApellido = (usuario.apellido ?? '').trim().isEmpty;
    final faltaCi = (usuario.ciNumero ?? '').trim().isEmpty;
    setState(() => _enviando = true);

    try {
      // 1. Cuentas antiguas: completar apellido o CI.
      if (!conVehiculo && (faltaApellido || faltaCi)) {
        ref.read(authControllerProvider.notifier).actualizarUsuario(await ref.read(perfilRepositoryProvider).actualizar({
          if (faltaApellido) 'apellido': _apellido.text.trim(),
          if (faltaCi) 'ci_numero': _ciNumero.text.trim(),
        }));
      }

      // 2. El perfil de repartidor (o volver a enviar si lo rechazaron).
      if (!_solicitado && (perfil == null || perfil.rechazado)) {
        await repartidor.solicitar();
        _solicitado = true;
      }

      // 3. El vehículo (uno solo: si ya lo tiene, no se pide de nuevo).
      if (!conVehiculo) {
        await repartidor.registrarVehiculo(DatosVehiculo(
          tipoVehiculoId: _tipo!.id,
          placa: _tipo!.requierePlaca ? _placa.text : null,
          ruat: _tipo!.requiereRuat ? _ruat.text : null,
          marca: _marca.text,
          modelo: _modelo.text,
          color: _color.text,
          anio: int.tryParse(_anio.text.trim()),
        ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _temblores++;
        _errores = {for (final campo in e.errores.keys) campo: e.errorDe(campo)!};
        if (_errores.isEmpty) _errorGeneral = e.mensaje;
      });
      return;
    }

    // 4. Ya tiene la vista repartidor: se refresca la sesión y se abre esa vista.
    ref.invalidate(miRepartidorProvider);
    ref.invalidate(faltantesProvider('repartidor'));
    final sesion = ref.read(authControllerProvider.notifier);
    try {
      await sesion.refrescar();
      await sesion.cambiarVista(Vista.repartidor);
    } on ApiException {
      // Si falla, el usuario igual puede cambiar de vista con el selector.
    }

    if (!mounted) return;
    mensajero.showSnackBar(SnackBar(
      content: Text(perfil?.rechazado == true
          ? 'Listo: enviaste tu solicitud de nuevo. Sube lo que te falta.'
          : '¡Listo! Tu solicitud está en revisión. Ahora sube las fotos que te faltan.'),
      duration: const Duration(seconds: 5),
    ));
    context.go('/inicio');
  }

  String? _requerido(String? v, String mensaje) => (v == null || v.trim().isEmpty) ? mensaje : null;

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    final tipos = ref.watch(tiposVehiculoProvider);
    final perfil = ref.watch(miRepartidorProvider);
    final animar = AppMovimiento.activo(context);

    final cargando = tipos.isLoading || perfil.isLoading;
    final errorCarga = tipos.error ?? perfil.error;

    Widget contenido() {
      final miPerfil = perfil.value;
      final vehiculo = miPerfil?.vehiculo;
      // Ya registrado con su vehículo y en revisión (o aprobado): no hay nada que enviar.
      if (miPerfil != null && vehiculo != null && !miPerfil.rechazado) return _yaRegistrado();

      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (miPerfil != null && miPerfil.rechazado) ...[
              Aparecer(orden: 1, child: _seccionRechazo(miPerfil)),
              const SizedBox(height: AppEspacios.l + 4),
            ],
            if (vehiculo != null)
              Aparecer(orden: 2, child: _resumenVehiculo(vehiculo))
            else ...[
              Aparecer(orden: 2, child: _seccionTipo(tipos.value!)),
              ..._seccionDatos(),
              ..._seccionPersona(usuario!),
              const SizedBox(height: AppEspacios.l),
              Aparecer(orden: 5, child: _queSigue()),
            ],
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
                texto: miPerfil?.rechazado == true ? 'Volver a enviar' : 'Enviar solicitud',
                icono: Icons.delivery_dining_outlined,
                cargando: _enviando,
                onPressed: () => _enviar(usuario!, miPerfil),
              ),
            ),
          ],
        ),
      );
    }

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
                                : contenido(),
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
            ref.invalidate(tiposVehiculoProvider);
            ref.invalidate(miRepartidorProvider);
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
                // Sobre el verde de la marca (igual en los dos temas), como en las demás cabeceras.
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
                      'Quiero ser repartidor',
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

  /// Tarjetas grandes con ícono, una por tipo de vehículo.
  Widget _seccionTipo(List<TipoVehiculo> tipos) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final error = _errores['tipo_vehiculo_id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('¿En qué vas a repartir?', Icons.delivery_dining_outlined),
        LayoutBuilder(
          builder: (context, medidas) {
            const espacio = AppEspacios.s + 2;
            // 3 por fila en celular; las que sobran se centran.
            final ancho = (medidas.maxWidth - espacio * 2) / 3;
            return Wrap(
              spacing: espacio,
              runSpacing: espacio,
              alignment: WrapAlignment.center,
              children: [
                for (final tipo in tipos)
                  SizedBox(
                    width: ancho,
                    child: _TarjetaTipo(
                      tipo: tipo,
                      elegido: _tipo?.id == tipo.id,
                      alElegir: _enviando
                          ? null
                          : () => setState(() {
                                _tipo = tipo;
                                _errores = {..._errores}
                                  ..remove('tipo_vehiculo_id')
                                  ..remove('placa')
                                  ..remove('ruat');
                              }),
                    ),
                  ),
              ],
            );
          },
        ),
        if (error != null) ...[
          const SizedBox(height: AppEspacios.s),
          Text(error, style: textos.bodySmall?.copyWith(color: c.error)),
        ],
        if (_tipo?.descripcion != null) ...[
          const SizedBox(height: AppEspacios.s + 2),
          Text(
            '${_tipo!.categoria}: ${_tipo!.descripcion}',
            style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  /// Placa y RUAT (si el tipo los pide) y los datos opcionales del vehículo.
  List<Widget> _seccionDatos() {
    final tipo = _tipo;
    if (tipo == null) return const [];
    const espacio = SizedBox(height: 14);

    return [
      const SizedBox(height: AppEspacios.l + 4),
      Aparecer(
        orden: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TituloSeccion('Datos de tu ${tipo.nombre.toLowerCase()}', tipo.icono),
            if (tipo.requierePlaca) ...[
              TextFormField(
                key: const Key('campo-placa'),
                controller: _placa,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  hintText: 'Ej. 1234-ABC',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                forceErrorText: _errores['placa'],
                validator: (v) => _requerido(v, 'Escribe la placa del vehículo.'),
              ),
              espacio,
            ],
            if (tipo.requiereRuat) ...[
              TextFormField(
                key: const Key('campo-ruat'),
                controller: _ruat,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Número de RUAT',
                  helperText: 'Está en el documento de registro de tu vehículo.',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                forceErrorText: _errores['ruat'],
                validator: (v) => _requerido(v, 'Escribe el número de RUAT del vehículo.'),
              ),
              espacio,
            ],
            if (!tipo.requierePlaca && !tipo.requiereRuat) ...[
              Text(
                'Tu ${tipo.nombre.toLowerCase()} no necesita placa, RUAT ni licencia.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              espacio,
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _marca,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Marca (opcional)'),
                    forceErrorText: _errores['marca'],
                  ),
                ),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: TextFormField(
                    controller: _modelo,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Modelo (opcional)'),
                    forceErrorText: _errores['modelo'],
                  ),
                ),
              ],
            ),
            espacio,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _color,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Color (opcional)'),
                    forceErrorText: _errores['color'],
                  ),
                ),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: TextFormField(
                    controller: _anio,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Año (opcional)'),
                    forceErrorText: _errores['anio'],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final anio = int.tryParse(v.trim());
                      return anio == null || anio < 1950 || anio > DateTime.now().year + 1 ? 'Año no válido' : null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  /// Solo en cuentas antiguas sin apellido o CI.
  List<Widget> _seccionPersona(Usuario usuario) {
    final faltaApellido = (usuario.apellido ?? '').trim().isEmpty;
    final faltaCi = (usuario.ciNumero ?? '').trim().isEmpty;
    if (!faltaApellido && !faltaCi) return const [];
    const espacio = SizedBox(height: 14);

    return [
      const SizedBox(height: AppEspacios.l + 4),
      Aparecer(
        orden: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloSeccion('Tus datos', Icons.badge_outlined),
            if (faltaApellido) ...[
              TextFormField(
                controller: _apellido,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.badge_outlined)),
                forceErrorText: _errores['apellido'],
                validator: (v) => _requerido(v, 'Escribe tu apellido'),
              ),
              if (faltaCi) espacio,
            ],
            if (faltaCi)
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
          ],
        ),
      ),
    ];
  }

  /// Qué fotos se le van a pedir después, según el tipo elegido.
  Widget _queSigue() {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final tipo = _tipo;
    final fotos = [
      'tu carnet (los dos lados)',
      'una selfie',
      'tu vehículo',
      if (tipo == null || tipo.requierePlaca) 'la placa',
      if (tipo == null || tipo.requiereRuat) 'el RUAT',
      if (tipo == null || tipo.requiereLicencia) 'tu licencia de conducir',
    ];
    final lista = '${fotos.sublist(0, fotos.length - 1).join(', ')} y ${fotos.last}';

    return Container(
      padding: const EdgeInsets.all(AppEspacios.m - 2),
      decoration: BoxDecoration(
        color: c.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadios.campo),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.photo_camera_outlined, color: c.onSecondaryContainer),
          const SizedBox(width: AppEspacios.m - 4),
          Expanded(
            child: Text(
              'Después te pediremos fotos de $lista. Solo las ve el equipo de MDR Market.',
              style: textos.bodySmall?.copyWith(color: c.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Le rechazaron la solicitud: el motivo y qué hacer.
  Widget _seccionRechazo(PerfilRepartidor perfil) {
    final c = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Tu solicitud no fue aprobada', Icons.info_outline),
        AvisoError(perfil.motivoRechazo ?? 'El equipo de MDR Market no dejó un motivo.'),
        const SizedBox(height: AppEspacios.s + 2),
        Text(
          'Corrige lo que te indicamos y vuelve a enviar tu solicitud. Después podrás subir de nuevo '
          'las fotos que hayan sido rechazadas.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }

  /// El vehículo que ya registró (por ahora, uno solo: no se ofrece agregar otro).
  Widget _resumenVehiculo(Vehiculo v) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Tu vehículo', Icons.delivery_dining_outlined),
        Row(
          children: [
            Icon(TipoVehiculo.iconoDe(v.tipoCodigo), size: 36, color: c.primary),
            const SizedBox(width: AppEspacios.m - 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text([v.tipoNombre, ?v.placa].join(' · '), style: textos.titleMedium),
                  if (v.detalle.isNotEmpty)
                    Text(v.detalle, style: textos.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _yaRegistrado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EstadoVacio(
          icono: Icons.hourglass_top,
          titulo: 'Ya enviaste tu solicitud',
          texto: 'Revisa en tu vista de repartidor lo que te falta subir.',
        ),
        BotonPrincipal(
          texto: 'Ir a mi vista de repartidor',
          icono: Icons.delivery_dining_outlined,
          onPressed: () async {
            try {
              await ref.read(authControllerProvider.notifier).cambiarVista(Vista.repartidor);
            } on ApiException {
              // Puede cambiar de vista con el selector.
            }
            if (mounted) context.go('/inicio');
          },
        ),
      ],
    );
  }
}

/// Tarjeta grande y tocable con el ícono y el nombre de un tipo de vehículo.
class _TarjetaTipo extends StatelessWidget {
  const _TarjetaTipo({required this.tipo, required this.elegido, required this.alElegir});

  final TipoVehiculo tipo;
  final bool elegido;
  final VoidCallback? alElegir;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final animar = AppMovimiento.activo(context);
    final colorTexto = elegido ? c.onPrimaryContainer : c.onSurface;

    return Semantics(
      selected: elegido,
      button: true,
      child: ReaccionToque(
        child: AnimatedContainer(
          key: Key('tipo-${tipo.codigo}'),
          duration: animar ? AppMovimiento.rapido : Duration.zero,
          decoration: BoxDecoration(
            color: elegido ? c.primaryContainer : c.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadios.campo + 4),
            border: Border.all(color: elegido ? c.primary : c.outlineVariant, width: elegido ? 2 : 1),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadios.campo + 4),
              onTap: alElegir,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppEspacios.m, horizontal: AppEspacios.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tipo.icono, size: 36, color: elegido ? c.primary : c.onSurfaceVariant),
                    const SizedBox(height: AppEspacios.s),
                    Text(
                      tipo.nombre,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textos.titleSmall?.copyWith(color: colorTexto),
                    ),
                    if (tipo.categoria != null)
                      Text(
                        tipo.categoria!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textos.labelSmall?.copyWith(color: elegido ? c.onPrimaryContainer : c.onSurfaceVariant),
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
