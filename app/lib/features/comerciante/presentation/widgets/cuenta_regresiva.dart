import 'dart:async';

import 'package:flutter/material.dart';

/// "Acepta en 0:42": cuánto le queda a la tienda para aceptar un pedido nuevo
/// (después se rechaza solo). Se actualiza cada segundo; es solo texto, así
/// que no choca con "reducir movimiento".
class CuentaRegresiva extends StatefulWidget {
  const CuentaRegresiva({super.key, required this.hasta, this.compacta = false});

  final DateTime hasta;

  /// En la tarjeta de la lista: una línea chica.
  final bool compacta;

  /// "0:42" (o "2:05").
  static String texto(Duration falta) {
    final s = falta.inSeconds.clamp(0, 359999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  State<CuentaRegresiva> createState() => _CuentaRegresivaState();
}

class _CuentaRegresivaState extends State<CuentaRegresiva> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.hasta.isAfter(DateTime.now())) _reloj?.cancel();
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final falta = widget.hasta.difference(DateTime.now());
    final vencido = falta <= Duration.zero;
    // Los últimos 15 segundos, en rojo.
    final urgente = falta.inSeconds < 15;
    final color = urgente ? c.error : c.onSurface;
    final texto = vencido
        ? 'Se acabó el tiempo: se rechazará solo'
        : 'Acepta en ${CuentaRegresiva.texto(falta)}${widget.compacta ? '' : ' o se rechaza solo'}';

    return Semantics(
      liveRegion: !widget.compacta,
      child: Row(
        key: const Key('cuenta-regresiva'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: widget.compacta ? 16 : 22, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: (widget.compacta ? textos.bodySmall : textos.titleSmall)?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
