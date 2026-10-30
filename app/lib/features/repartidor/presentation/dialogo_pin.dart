import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_espacios.dart';

/// Pide el PIN de 4 números que el cliente da al recibir. Devuelve el PIN o
/// null si cancela. Solo deja escribir números y "Entregar" se activa con 4.
Future<String?> pedirPin(BuildContext context, {String? error}) {
  return showDialog<String>(context: context, builder: (_) => _DialogoPin(error: error));
}

class _DialogoPin extends StatefulWidget {
  const _DialogoPin({this.error});

  /// Error de un intento anterior (ej. "El PIN no coincide…").
  final String? error;

  @override
  State<_DialogoPin> createState() => _DialogoPinState();
}

class _DialogoPinState extends State<_DialogoPin> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  bool get _completo => _pin.text.length == 4;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('PIN de entrega'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pídele al cliente su PIN de 4 números. Está en el detalle de su pedido.', style: textos.bodyMedium),
          const SizedBox(height: AppEspacios.m),
          TextField(
            key: const Key('campo-pin'),
            controller: _pin,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: textos.headlineMedium?.copyWith(letterSpacing: 12, fontWeight: FontWeight.w700),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            decoration: InputDecoration(hintText: '••••', errorText: widget.error, errorMaxLines: 2),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_completo) Navigator.pop(context, _pin.text);
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('confirmar-pin'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _completo ? () => Navigator.pop(context, _pin.text) : null,
          child: const Text('Entregar'),
        ),
      ],
    );
  }
}
