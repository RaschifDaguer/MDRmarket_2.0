import '../../../core/formato/formato.dart';

/// Montos de un período (de sp_reporte_negocio). Todo en bolivianos.
class Montos {
  const Montos({
    this.ventas = 0,
    this.costoDeLoVendido = 0,
    this.gananciaBruta = 0,
    this.compras = 0,
    this.gastos = 0,
    this.comisiones = 0,
    this.gananciaNeta = 0,
    this.flujoCaja = 0,
    this.unidadesVendidas = 0,
  });

  final double ventas;
  final double costoDeLoVendido;

  /// Ventas − lo que costó lo vendido.
  final double gananciaBruta;
  final double compras;
  final double gastos;
  final double comisiones;

  /// Ganancia bruta − gastos − comisiones.
  final double gananciaNeta;

  /// Lo que entró − todo lo que salió (incluye compras de mercadería).
  final double flujoCaja;
  final int unidadesVendidas;

  factory Montos.fromJson(Map<String, dynamic> json) => Montos(
        ventas: Formato.numero(json['ventas']),
        costoDeLoVendido: Formato.numero(json['costo_de_lo_vendido']),
        gananciaBruta: Formato.numero(json['ganancia_bruta']),
        compras: Formato.numero(json['compras']),
        gastos: Formato.numero(json['gastos']),
        comisiones: Formato.numero(json['comisiones']),
        gananciaNeta: Formato.numero(json['ganancia_neta']),
        flujoCaja: Formato.numero(json['flujo_caja']),
        unidadesVendidas: (json['unidades_vendidas'] as num?)?.toInt() ?? 0,
      );
}

/// Portada de la vista comerciante.
class ResumenNegocio {
  const ResumenNegocio({
    required this.pedidosNuevos,
    required this.pedidosEnCurso,
    required this.hoy,
    required this.mes,
    required this.productosActivos,
    required this.productosSinStock,
    this.rating,
    this.totalResenas = 0,
  });

  final int pedidosNuevos;
  final int pedidosEnCurso;
  final Montos hoy;
  final Montos mes;
  final int productosActivos;
  final int productosSinStock;
  final double? rating;
  final int totalResenas;

  factory ResumenNegocio.fromJson(Map<String, dynamic> json) => ResumenNegocio(
        pedidosNuevos: (json['pedidos_nuevos'] as num).toInt(),
        pedidosEnCurso: (json['pedidos_en_curso'] as num).toInt(),
        hoy: Montos.fromJson(json['hoy'] as Map<String, dynamic>),
        mes: Montos.fromJson(json['mes'] as Map<String, dynamic>),
        productosActivos: (json['productos_activos'] as num).toInt(),
        productosSinStock: (json['productos_sin_stock'] as num).toInt(),
        rating: (json['rating_promedio'] as num?)?.toDouble(),
        totalResenas: (json['total_resenas'] as num?)?.toInt() ?? 0,
      );
}

/// Ganancias de un rango de fechas, por período (día, semana, mes o año).
class Reporte {
  const Reporte({required this.totales, required this.periodos, required this.agrupar});

  final Montos totales;
  final List<({String periodo, Montos montos})> periodos;
  final String agrupar;

  factory Reporte.fromJson(Map<String, dynamic> json) => Reporte(
        totales: Montos.fromJson(json['totales'] as Map<String, dynamic>),
        agrupar: json['agrupar'] as String,
        periodos: [
          for (final p in json['periodos'] as List)
            (periodo: (p as Map)['periodo'] as String, montos: Montos.fromJson(p as Map<String, dynamic>)),
        ],
      );
}

/// Gasto y ganancia de un producto en un rango de fechas.
class ReporteProducto {
  const ReporteProducto({
    required this.productoId,
    required this.producto,
    required this.unidadesVendidas,
    required this.ventas,
    required this.ganancia,
    required this.gastoEnCompras,
    this.margenPct,
  });

  final int productoId;
  final String producto;
  final int unidadesVendidas;
  final double ventas;
  final double ganancia;
  final double gastoEnCompras;
  final double? margenPct;

  factory ReporteProducto.fromJson(Map<String, dynamic> json) => ReporteProducto(
        productoId: (json['producto_id'] as num).toInt(),
        producto: json['producto'] as String,
        unidadesVendidas: (json['unidades_vendidas'] as num).toInt(),
        ventas: Formato.numero(json['ventas']),
        ganancia: Formato.numero(json['ganancia']),
        gastoEnCompras: Formato.numero(json['gasto_en_compras']),
        margenPct: (json['margen_pct'] as num?)?.toDouble(),
      );
}

/// Una fila del libro de compras, gastos y ventas.
class Registro {
  const Registro({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.cantidad,
    this.producto,
    this.descripcion,
    this.proveedor,
    this.pedidoId,
    this.fecha,
  });

  final int id;

  /// compra · gasto · venta · comision
  final String tipo;
  final double monto;
  final int cantidad;
  final String? producto;
  final String? descripcion;
  final String? proveedor;
  final int? pedidoId;
  final DateTime? fecha;

  bool get esIngreso => tipo == 'venta';
  bool get sePuedeBorrar => tipo == 'compra' || tipo == 'gasto';

  String get titulo => switch (tipo) {
        'compra' => 'Compra: ${producto ?? 'producto'} × $cantidad',
        'venta' => 'Venta: ${producto ?? 'producto'} × $cantidad',
        'comision' => 'Comisión de la plataforma',
        _ => descripcion ?? 'Gasto',
      };

  factory Registro.fromJson(Map<String, dynamic> json) => Registro(
        id: json['id'] as int,
        tipo: json['tipo'] as String,
        monto: Formato.numero(json['monto']),
        cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
        producto: (json['producto'] as Map?)?['nombre'] as String?,
        descripcion: json['descripcion'] as String?,
        proveedor: json['proveedor'] as String?,
        pedidoId: (json['pedido_id'] as num?)?.toInt(),
        fecha: Formato.fechaDe(json['fecha']),
      );
}

/// Reseñas del negocio con el resumen de estrellas.
class Calificaciones {
  const Calificaciones({required this.porEstrellas, this.rating, this.total = 0});

  final double? rating;
  final int total;

  /// Cuántas reseñas del negocio hay con 1…5 estrellas.
  final Map<int, int> porEstrellas;
}
