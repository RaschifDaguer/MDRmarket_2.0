import 'package:flutter/material.dart';

/// "−  2  +" para elegir cuántas unidades.
class SelectorCantidad extends StatelessWidget {
  const SelectorCantidad({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.minimo = 1,
    this.maximo = 99,
    this.compacto = false,
  });

  final int valor;
  final ValueChanged<int> alCambiar;
  final int minimo;
  final int maximo;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tamano = compacto ? 32.0 : 44.0;
    final estiloBoton = IconButton.styleFrom(
      minimumSize: Size.square(tamano),
      maximumSize: Size.square(tamano),
      padding: EdgeInsets.zero,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: c.outlineVariant),
        borderRadius: BorderRadius.circular(compacto ? 10 : 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('cantidad-menos'),
            tooltip: valor <= minimo && minimo == 0 ? 'Quitar' : 'Uno menos',
            style: estiloBoton,
            iconSize: compacto ? 18 : 22,
            onPressed: valor > minimo ? () => alCambiar(valor - 1) : null,
            icon: Icon(valor == 1 && minimo == 0 ? Icons.delete_outline : Icons.remove),
          ),
          SizedBox(
            width: compacto ? 28 : 36,
            child: Text(
              '$valor',
              key: const Key('cantidad-valor'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const Key('cantidad-mas'),
            tooltip: 'Uno más',
            style: estiloBoton,
            iconSize: compacto ? 18 : 22,
            onPressed: valor < maximo ? () => alCambiar(valor + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
