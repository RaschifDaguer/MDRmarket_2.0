import 'package:flutter/material.dart';

import '../theme/app_colores.dart';

/// Logo de MDR Market: la moto de reparto dentro de un cuadrado redondeado.
///
/// [sobreColor] = `true` cuando va encima de un fondo verde: el cuadrado se
/// pinta blanco y el ícono verde.
class LogoMarca extends StatelessWidget {
  const LogoMarca({super.key, this.tamano = 72, this.sobreColor = false});

  final double tamano;
  final bool sobreColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sobreColor
              ? const [AppColores.blanco, AppColores.fondoSuave]
              : const [AppColores.intermedio, AppColores.primario],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: tamano * 0.35,
            offset: Offset(0, tamano * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.delivery_dining,
        size: tamano * 0.58,
        color: sobreColor ? AppColores.primario : AppColores.blanco,
      ),
    );
  }
}
