import 'package:flutter/material.dart';

import '../theme/app_espacios.dart';

/// Confirmación en dos pasos para algo con responsabilidad legal (comprar
/// alcohol o tabaco, publicar un medicamento):
/// 1. una pregunta de sí o no ("¿Es usted mayor de edad?");
/// 2. si dice que sí, un resumen de lo que acepta y una declaración que tiene
///    que marcar antes de confirmar.
///
/// Devuelve `true` solo si contestó que sí y aceptó la declaración. Si dice
/// que no, le muestra [siDiceNo] y devuelve `false`.
Future<bool> confirmarEnDosPasos(
  BuildContext context, {
  required IconData icono,
  required String pregunta,
  required String explicacion,
  required String textoSi,
  required String textoNo,
  required String siDiceNo,
  required String tituloDeclaracion,
  required String resumen,
  required String declaracion,
  required String textoConfirmar,
}) async {
  final boton = FilledButton.styleFrom(minimumSize: const Size(0, 44));

  // Paso 1: la pregunta.
  final dijoSi = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      icon: Icon(icono),
      title: Text(pregunta),
      content: Text(explicacion),
      actions: [
        TextButton(key: const Key('paso1-no'), onPressed: () => Navigator.pop(contexto, false), child: Text(textoNo)),
        FilledButton(
          key: const Key('paso1-si'),
          style: boton,
          onPressed: () => Navigator.pop(contexto, true),
          child: Text(textoSi),
        ),
      ],
    ),
  );
  if (!context.mounted || dijoSi == null) return false;
  if (!dijoSi) {
    await showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        icon: Icon(icono),
        content: Text(siDiceNo),
        actions: [TextButton(onPressed: () => Navigator.pop(contexto), child: const Text('Entendido'))],
      ),
    );
    return false;
  }

  // Paso 2: lo que acepta, con una casilla que tiene que marcar.
  final acepto = await showDialog<bool>(
    context: context,
    builder: (contexto) {
      var marcada = false;
      return StatefulBuilder(
        builder: (contexto, cambiar) => AlertDialog(
          icon: const Icon(Icons.gavel_outlined),
          title: Text(tituloDeclaracion),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(resumen),
                const SizedBox(height: AppEspacios.m),
                CheckboxListTile(
                  key: const Key('paso2-casilla'),
                  value: marcada,
                  onChanged: (v) => cambiar(() => marcada = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(declaracion, style: Theme.of(contexto).textTheme.bodySmall),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
            FilledButton(
              key: const Key('paso2-confirmar'),
              style: boton,
              onPressed: marcada ? () => Navigator.pop(contexto, true) : null,
              child: Text(textoConfirmar),
            ),
          ],
        ),
      );
    },
  );
  return acepto ?? false;
}
