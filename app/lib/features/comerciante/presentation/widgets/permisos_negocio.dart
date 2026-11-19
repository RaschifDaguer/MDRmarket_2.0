import 'package:flutter/material.dart';

import '../../../../core/theme/app_espacios.dart';
import '../../../../core/widgets/widgets.dart';

/// "Permisos especiales" al registrar o editar el negocio: si vende bebidas
/// alcohólicas (licorería) o es farmacia. Cada uno pide documentos extra, que
/// después aparecen en "Te falta subir".
class SeccionPermisos extends StatelessWidget {
  const SeccionPermisos({
    super.key,
    required this.vendeAlcohol,
    required this.esFarmacia,
    required this.alCambiarAlcohol,
    required this.alCambiarFarmacia,
    this.rubroEsLicoreria = false,
    this.errores = const {},
  });

  final bool vendeAlcohol;
  final bool esFarmacia;
  final ValueChanged<bool> alCambiarAlcohol;
  final ValueChanged<bool> alCambiarFarmacia;

  /// El rubro es "Bebidas alcohólicas": la casilla queda marcada y fija.
  final bool rubroEsLicoreria;

  /// Errores de la API por campo (vende_alcohol, es_farmacia).
  final Map<String, String> errores;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final pequeno = Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant);

    // Material propio: los interruptores van dentro de tarjetas con fondo.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TituloSeccion('Permisos especiales', Icons.verified_user_outlined),
          Text(
            'Solo si vendes bebidas alcohólicas o medicamentos. Te pediremos sus permisos y los revisaremos antes '
            'de mostrar esos productos.',
            style: pequeno,
          ),
          SwitchListTile(
            key: const Key('permiso-alcohol'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.liquor_outlined),
            title: const Text('Vendo bebidas alcohólicas'),
            subtitle: Text(
              rubroEsLicoreria
                  ? 'Tu rubro es Bebidas alcohólicas.'
                  : 'Licorerías, o tiendas que también venden cerveza, vino o licores.',
            ),
            value: vendeAlcohol || rubroEsLicoreria,
            onChanged: rubroEsLicoreria ? null : alCambiarAlcohol,
          ),
          if (errores['vende_alcohol'] case final error?) Text(error, style: TextStyle(color: c.error)),
          if (vendeAlcohol || rubroEsLicoreria)
            _Requisitos(const [
              'Autorización de expendio de bebidas alcohólicas (Alcaldía)',
              'Licencia de funcionamiento municipal: en "Actividad" o "Rubro" debe decir "Expendio de bebidas '
                  'alcohólicas" o "Licorería" (una de pulpería o micromercado no sirve)',
            ]),
          SwitchListTile(
            key: const Key('permiso-farmacia'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.local_pharmacy_outlined),
            title: const Text('Es una farmacia'),
            subtitle: const Text('Vende medicamentos.'),
            value: esFarmacia,
            onChanged: alCambiarFarmacia,
          ),
          if (errores['es_farmacia'] case final error?) Text(error, style: TextStyle(color: c.error)),
          if (esFarmacia)
            _Requisitos(const [
              'Resolución administrativa de apertura y funcionamiento (SEDES)',
              'Licencia de funcionamiento municipal con el rubro de farmacia',
            ]),
        ],
      ),
    );
  }
}

/// Lista de documentos que se pedirán (se suben después, en Documentos).
class _Requisitos extends StatelessWidget {
  const _Requisitos(this.documentos);

  final List<String> documentos;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspacios.s),
      padding: const EdgeInsets.all(AppEspacios.m - 4),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Te pediremos:', style: textos.labelLarge?.copyWith(color: c.onSecondaryContainer)),
          const SizedBox(height: AppEspacios.xs),
          for (final d in documentos)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: c.onSecondaryContainer)),
                  Expanded(
                    child: Text(d, style: textos.bodySmall?.copyWith(color: c.onSecondaryContainer)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
