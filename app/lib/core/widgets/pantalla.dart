import 'package:flutter/material.dart';

import 'fondo_marca.dart';

/// Pantalla secundaria (detalle de producto, carrito, formulario…): barra
/// superior con flecha para volver, fondo de la marca y el contenido con un
/// ancho máximo, para que en la PC no quede estirado.
class Pantalla extends StatelessWidget {
  const Pantalla({
    super.key,
    required this.titulo,
    required this.child,
    this.acciones = const [],
    this.abajo,
    this.anchoMaximo = 640,
  });

  final String titulo;
  final Widget child;
  final List<Widget> acciones;

  /// Barra fija abajo (ej. "Agregar al carrito").
  final Widget? abajo;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo), actions: acciones),
      body: FondoMarca(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: anchoMaximo),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: abajo == null
          ? null
          : SafeArea(
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: anchoMaximo),
                  child: abajo,
                ),
              ),
            ),
    );
  }
}
