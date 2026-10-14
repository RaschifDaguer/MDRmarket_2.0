import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/archivos/archivo_elegido.dart';
import '../../../core/maps/coordenada.dart';
import '../../../core/maps/selector_ubicacion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_espacios.dart';
import '../../../core/widgets/widgets.dart';
import '../../catalogo/data/catalogo_repository.dart';
import '../data/mi_negocio_repository.dart';
import '../data/negocio_repository.dart';
import '../domain/negocio.dart';
import 'con_negocio.dart';

/// Editar el perfil del negocio: foto, nombre, rubro, ubicación, pedido
/// mínimo, tiempo de preparación y datos para facturas.
class PerfilNegocioScreen extends StatelessWidget {
  const PerfilNegocioScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      ConNegocio(titulo: 'Perfil del negocio', builder: (negocio) => _Perfil(negocio: negocio));
}

class _Perfil extends ConsumerStatefulWidget {
  const _Perfil({required this.negocio});

  final Negocio negocio;

  @override
  ConsumerState<_Perfil> createState() => _PerfilState();
}

class _PerfilState extends ConsumerState<_Perfil> {
  final _form = GlobalKey<FormState>();
  late final n = widget.negocio;
  late final _nombre = TextEditingController(text: n.nombre);
  late final _descripcion = TextEditingController(text: n.descripcion);
  late final _telefono = TextEditingController(text: n.telefono);
  late final _direccion = TextEditingController(text: n.direccion);
  late final _referencia = TextEditingController(text: n.referencia);
  late final _tiempo = TextEditingController(text: n.tiempoPreparacionMin?.toString() ?? '');
  late final _minimo = TextEditingController(text: n.pedidoMinimo > 0 ? n.pedidoMinimo.toStringAsFixed(0) : '');
  late final _nit = TextEditingController(text: n.nit);
  late final _razonSocial = TextEditingController(text: n.razonSocial);
  late int? _categoriaId = n.categoria?.id;
  late Coordenada? _ubicacion = n.latitud == null ? null : Coordenada(n.latitud!, n.longitud!);
  ArchivoElegido? _foto;
  bool _guardando = false;
  Map<String, String> _errores = {};
  String? _errorGeneral;

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _telefono, _direccion, _referencia, _tiempo, _minimo, _nit, _razonSocial]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _errores = {};
      _errorGeneral = null;
    });
    final ok = _form.currentState!.validate();
    if (_ubicacion == null) setState(() => _errores = {'ubicacion': 'Marca la ubicación del negocio.'});
    if (!ok || _ubicacion == null) return;

    setState(() => _guardando = true);
    try {
      await ref.read(miNegocioRepositoryProvider).actualizarPerfil(
            n.id,
            DatosPerfil(
              nombre: _nombre.text,
              categoriaId: _categoriaId!,
              direccion: _direccion.text,
              ubicacion: _ubicacion!,
              descripcion: _descripcion.text,
              telefono: _telefono.text,
              referencia: _referencia.text,
              nit: _nit.text,
              razonSocial: _razonSocial.text,
              tiempoPreparacionMin: int.tryParse(_tiempo.text.trim()),
              pedidoMinimo: double.tryParse(_minimo.text.trim().replaceAll(',', '.')),
            ),
            foto: _foto,
          );
      ref.invalidate(misNegociosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errores = {
          for (final campo in e.errores.keys)
            (campo == 'latitud' || campo == 'longitud' ? 'ubicacion' : campo): e.errorDe(campo)!,
        };
        if (_errores.isEmpty) _errorGeneral = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasProvider).value ?? const [];
    const espacio = SizedBox(height: 14);

    return Pantalla(
      titulo: 'Perfil del negocio',
      abajo: Padding(
        padding: const EdgeInsets.all(AppEspacios.m),
        child: BotonPrincipal(texto: 'Guardar cambios', icono: Icons.check, cargando: _guardando, onPressed: _guardar),
      ),
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppEspacios.m),
          children: [
            SelectorFoto(
              valor: _foto,
              urlActual: n.logoUrl,
              texto: 'Foto del negocio',
              error: _errores['foto'],
              alElegir: (f) => setState(() => _foto = f),
            ),
            const SizedBox(height: AppEspacios.l),
            const TituloSeccion('Tu negocio', Icons.storefront_outlined),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre del negocio'),
              forceErrorText: _errores['nombre'],
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe el nombre' : null,
            ),
            espacio,
            DropdownButtonFormField<int>(
              initialValue: categorias.any((c) => c.id == _categoriaId) ? _categoriaId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Rubro', errorText: _errores['categoria_id']),
              items: [for (final c in categorias) DropdownMenuItem(value: c.id, child: Text(c.etiqueta))],
              onChanged: (v) => setState(() => _categoriaId = v),
              validator: (v) => v == null ? 'Elige el rubro' : null,
            ),
            espacio,
            TextFormField(
              controller: _descripcion,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)', alignLabelWithHint: true),
              forceErrorText: _errores['descripcion'],
            ),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)', prefixIcon: Icon(Icons.phone_outlined)),
              forceErrorText: _errores['telefono'],
            ),
            const SizedBox(height: AppEspacios.l),
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
              decoration: const InputDecoration(labelText: 'Dirección', prefixIcon: Icon(Icons.signpost_outlined)),
              forceErrorText: _errores['direccion'],
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe la dirección' : null,
            ),
            espacio,
            TextFormField(
              controller: _referencia,
              decoration: const InputDecoration(labelText: 'Referencia (opcional)', prefixIcon: Icon(Icons.info_outline)),
            ),
            const SizedBox(height: AppEspacios.l),
            const TituloSeccion('Pedidos', Icons.receipt_long_outlined),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tiempo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tiempo de preparación', suffixText: 'min'),
                    forceErrorText: _errores['tiempo_preparacion_min'],
                  ),
                ),
                const SizedBox(width: AppEspacios.m - 4),
                Expanded(
                  child: TextFormField(
                    controller: _minimo,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Pedido mínimo', prefixText: 'Bs '),
                    forceErrorText: _errores['pedido_minimo'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspacios.l),
            const TituloSeccion('Datos para facturas', Icons.receipt_long_outlined, opcional: true),
            TextFormField(
              controller: _nit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'NIT'),
              forceErrorText: _errores['nit'],
            ),
            espacio,
            TextFormField(
              controller: _razonSocial,
              decoration: const InputDecoration(
                labelText: 'Nombre para facturas',
                helperText: 'Como figura en tu NIT. Ej.: Comercial Suárez S.R.L. o tu nombre completo.',
                helperMaxLines: 2,
              ),
              forceErrorText: _errores['razon_social'],
            ),
            if (_errorGeneral != null) ...[const SizedBox(height: AppEspacios.m), AvisoError(_errorGeneral!)],
            const SizedBox(height: AppEspacios.xl),
          ],
        ),
      ),
    );
  }
}
