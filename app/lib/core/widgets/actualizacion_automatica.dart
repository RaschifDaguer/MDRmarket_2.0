import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Mantiene una pantalla al día sin recargarla: llama a [alActualizar] cada
/// [cada] mientras la pantalla está a la vista y la app abierta.
///
/// - Se pausa si la pantalla queda tapada por otra o en una pestaña que no se
///   ve (TickerMode apagado) y si la app pasa a segundo plano.
/// - Al volver a la app, actualiza enseguida.
///
/// Es una consulta cada pocos segundos (no WebSockets): liviano para el
/// servidor de 1 CPU y suficiente para ver pedidos y aprobaciones casi al instante.
class ActualizacionAutomatica extends StatefulWidget {
  const ActualizacionAutomatica({
    super.key,
    required this.alActualizar,
    required this.child,
    this.cada = const Duration(seconds: 8),
  });

  /// Qué volver a pedir (ej. `ref.invalidate(misPedidosProvider)`).
  final VoidCallback alActualizar;
  final Duration cada;
  final Widget child;

  @override
  State<ActualizacionAutomatica> createState() => _ActualizacionAutomaticaState();
}

class _ActualizacionAutomaticaState extends State<ActualizacionAutomatica> with WidgetsBindingObserver {
  Timer? _reloj;
  ValueListenable<TickerModeData>? _visible;
  bool _enPrimerPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arrancar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.getValuesNotifier(context);
  }

  void _arrancar() {
    _reloj?.cancel();
    _reloj = Timer.periodic(widget.cada, (_) {
      if (mounted && _enPrimerPlano && (_visible?.value.enabled ?? true)) widget.alActualizar();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final antes = _enPrimerPlano;
    _enPrimerPlano = estado == AppLifecycleState.resumed;
    // Volvió a la app (o a la pestaña del navegador): al día enseguida.
    if (_enPrimerPlano && !antes && mounted) {
      widget.alActualizar();
      _arrancar();
    }
  }

  @override
  void didUpdateWidget(covariant ActualizacionAutomatica anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.cada != widget.cada) _arrancar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
