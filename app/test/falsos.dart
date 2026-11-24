// Datos y repositorios falsos para probar las pantallas sin internet.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/archivos/archivo_elegido.dart';
import 'package:mdrmarket/core/formato/formato.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/network/pagina.dart';
import 'package:mdrmarket/core/storage/preferencias.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/auth_controller.dart';
import 'package:mdrmarket/features/carrito/domain/carrito.dart';
import 'package:mdrmarket/features/catalogo/data/catalogo_repository.dart';
import 'package:mdrmarket/features/catalogo/domain/categoria.dart';
import 'package:mdrmarket/features/catalogo/domain/producto.dart';
import 'package:mdrmarket/features/catalogo/domain/resena.dart';
import 'package:mdrmarket/features/catalogo/domain/tienda.dart';
import 'package:mdrmarket/features/terminos/data/terminos_repository.dart';
import 'package:mdrmarket/features/comerciante/data/mi_negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/data/negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/domain/documento_subido.dart';
import 'package:mdrmarket/features/comerciante/domain/finanzas.dart';
import 'package:mdrmarket/features/comerciante/domain/horario.dart';
import 'package:mdrmarket/features/comerciante/domain/mi_producto.dart';
import 'package:mdrmarket/features/comerciante/domain/negocio.dart';
import 'package:mdrmarket/features/comerciante/presentation/widgets/fotos_producto.dart';
import 'package:mdrmarket/features/notificaciones/data/notificaciones_repository.dart';
import 'package:mdrmarket/features/notificaciones/domain/notificacion.dart';
import 'package:mdrmarket/features/pedidos/data/pedidos_repository.dart';
import 'package:mdrmarket/features/pedidos/domain/direccion.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/pedidos/domain/seguimiento.dart';
import 'package:mdrmarket/features/pedidos/presentation/widgets/seguimiento_pedido.dart';
import 'package:mdrmarket/features/perfil/data/perfil_repository.dart';
import 'package:mdrmarket/features/perfil/domain/faltante.dart';
import 'package:mdrmarket/features/repartidor/data/envio_ubicacion.dart';
import 'package:mdrmarket/features/repartidor/data/repartidor_repository.dart';
import 'package:mdrmarket/features/repartidor/domain/ganancias.dart';
import 'package:mdrmarket/features/repartidor/domain/pedido_disponible.dart';
import 'package:mdrmarket/features/repartidor/domain/repartidor.dart';
import 'package:mdrmarket/features/repartidor/domain/tipo_vehiculo.dart';

class SesionFalsa extends AuthController {
  SesionFalsa(this._usuario);

  final Usuario _usuario;

  @override
  Future<Usuario?> build() async => _usuario;
}

const cliente = Usuario(
  id: 1,
  nombre: 'Marta',
  apellido: 'Suárez',
  email: 'marta@correo.com',
  ciNumero: '7654321',
  telefono: '70012345',
  vistas: [Vista.cliente],
  vistaGuardada: 'cliente',
);

const comerciante = Usuario(
  id: 1,
  nombre: 'Marta',
  apellido: 'Suárez',
  email: 'marta@correo.com',
  ciNumero: '7654321',
  vistas: [Vista.cliente, Vista.comerciante],
  vistaGuardada: 'comerciante',
);

// Sin emojis en los nombres: en las pruebas no hay fuente de emojis.
const categoriasDePrueba = [
  Categoria(
    id: 1,
    nombre: 'Alimentos y Bebidas',
    subcategorias: [Categoria(id: 101, nombre: 'Restaurantes')],
  ),
  Categoria(
    id: 2,
    nombre: 'Salud y Belleza',
    subcategorias: [Categoria(id: 201, nombre: 'Farmacia', permiso: 'farmacia')],
  ),
];

const polleria = NegocioResumen(id: 5, nombre: 'Pollos Marta', rating: 4.5);
const farmacia = NegocioResumen(id: 6, nombre: 'Farmacia Central');

const pollo = Producto(
  id: 10,
  nombre: 'Pollo a la broaster',
  precio: 35,
  precioFinal: 28,
  enOferta: true,
  descuentoPct: 20,
  stock: 8,
  rating: 4.6,
  totalResenas: 12,
  categoria: 'Restaurantes',
  negocio: polleria,
);
const papas = Producto(id: 11, nombre: 'Papas fritas', precio: 12, precioFinal: 12, negocio: polleria);
const jarabe = Producto(id: 20, nombre: 'Jarabe para la tos', precio: 25, precioFinal: 25, negocio: farmacia);

/// Bebida alcohólica (+18): para probar el aviso y la confirmación de edad.
const cervezaDePrueba = Producto(
  id: 30,
  nombre: 'Cerveza Paceña 620 ml',
  precio: 15,
  precioFinal: 15,
  stock: 24,
  soloMayores: true,
  categoria: 'Cervezas',
  negocio: polleria,
);

/// Términos y condiciones de prueba (con secciones largas, como los reales).
const terminosDePrueba = Terminos(
  version: '2026-11-19',
  actualizado: '19 de noviembre de 2026',
  declaracion: 'Acepto los Términos y condiciones de MDR Market.',
  resumen:
      'MDR Market conecta a clientes con negocios y repartidores de Santa Cruz de la Sierra. Las bebidas '
      'alcohólicas y el tabaco solo se venden a mayores de 18 años.',
  secciones: [
    SeccionTerminos(
      titulo: '1. Qué es MDR Market',
      parrafos: [
        'MDR Market es una aplicación que conecta a personas que quieren comprar con negocios de Santa Cruz de la '
            'Sierra y con repartidores independientes que llevan los pedidos.',
      ],
    ),
    SeccionTerminos(
      titulo: '5. Bebidas alcohólicas y tabaco',
      parrafos: [
        'VENTA PROHIBIDA A MENORES DE 18 AÑOS. La venta de bebidas alcohólicas y de tabaco a menores de edad está '
            'prohibida (Ley N° 259 y Ley N° 1280).',
        'El repartidor te pedirá tu carnet de identidad al entregar.',
      ],
    ),
  ],
);

const negocioAprobado = Negocio(
  id: 5,
  nombre: 'Pollos Marta',
  estado: EstadoNegocio.aprobado,
  categoria: Categoria(id: 1, nombre: 'Alimentos y Bebidas'),
  direccion: 'Av. Busch 1234',
  latitud: -17.77,
  longitud: -63.19,
  ratingPromedio: 4.5,
  totalResenas: 3,
  pedidoMinimo: 20,
  tiempoPreparacionMin: 25,
  horarios: [Horario(diaSemana: 1, apertura: '08:00', cierre: '20:00')],
);

const negocioEnRevision = Negocio(
  id: 5,
  nombre: 'Tienda Marta',
  estado: EstadoNegocio.pendiente,
  categoria: Categoria(id: 1, nombre: 'Alimentos y Bebidas'),
  direccion: 'Av. Busch 1234, entre 2do y 3er anillo',
);

/// Las fotos del carnet y la selfie, como las pide la API a un comerciante nuevo.
const faltaIdentidad = [
  Faltante(codigo: 'documento.ci_anverso', texto: 'Foto: Carnet de identidad (anverso)', documento: 'ci_anverso'),
  Faltante(codigo: 'documento.ci_reverso', texto: 'Foto: Carnet de identidad (reverso)', documento: 'ci_reverso'),
  Faltante(codigo: 'documento.foto_rostro', texto: 'Foto del rostro (selfie)', documento: 'foto_rostro'),
];

const casa = Direccion(
  id: 1,
  etiqueta: 'Casa',
  direccion: 'Calle Libertad 123',
  ubicacion: Coordenada(-17.79, -63.18),
  predeterminada: true,
);

/// Pedido de ejemplo en el estado que se pida (con [conRepartidor], lo lleva Diego en moto).
Pedido pedidoDeEjemplo({
  EstadoPedido estado = EstadoPedido.pendiente,
  bool paraNegocio = false,
  List<EstadoPedido>? acciones,
  bool conRepartidor = false,
  String metodoPago = 'efectivo',
  String estadoPago = 'pendiente',
  int? repartidorId,
  DateTime? aceptarAntes,
  int? repartidoresCerca,
  Set<int> alistados = const {},
}) {
  return Pedido(
    repartidorId: repartidorId,
    repartidorNombre: conRepartidor ? 'Diego Rodríguez' : null,
    repartidorVehiculo: conRepartidor ? 'Moto' : null,
    repartidorPlaca: conRepartidor ? '1234-ABC' : null,
    id: 42,
    estado: estado,
    negocioId: 5,
    negocioNombre: 'Pollos Marta',
    clienteNombre: paraNegocio ? 'Lucía Rojas' : null,
    clienteTelefono: paraNegocio ? '70011122' : null,
    direccionEntrega: 'Calle Libertad 123',
    referenciaEntrega: 'Portón negro',
    subtotal: 68,
    costoEnvio: 5,
    tarifaServicio: 0,
    total: 73,
    metodoPago: metodoPago,
    estadoPago: estadoPago,
    // El contenido del QR solo lo recibe el comprador.
    pagoQr: metodoPago == 'qr' && !paraNegocio ? 'https://mdrmarket.test/pago-qr/QR-${'a' * 32}' : null,
    codigoEntrega: paraNegocio ? null : '4821',
    distanciaKm: 2.4,
    aceptarAntes: aceptarAntes,
    repartidoresCerca: repartidoresCerca,
    items: [
      ItemPedido(
        id: 501,
        productoId: 10,
        nombre: 'Pollo a la broaster',
        precioUnitario: 28,
        cantidad: 2,
        subtotal: 56,
        alistado: alistados.contains(501),
      ),
      ItemPedido(
        id: 502,
        productoId: 11,
        nombre: 'Papas fritas',
        precioUnitario: 12,
        cantidad: 1,
        subtotal: 12,
        notas: 'Sin sal',
        alistado: alistados.contains(502),
      ),
    ],
    historial: [(estado: EstadoPedido.pendiente, fecha: DateTime(2026, 10, 9, 12, 30), motivo: null)],
    acciones: acciones ?? const [],
    creado: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

/// Envío de prueba de una tienda hasta la dirección del cliente.
const envioDePrueba = EnvioTienda(enCobertura: true, costoEnvio: 5, distanciaKm: 2.4, tiempoMin: 30, tiempoMax: 40);

class CatalogoFalso extends CatalogoRepository {
  CatalogoFalso() : super(Dio());

  final consultas = <FiltroCatalogo>[];

  @override
  Future<List<Categoria>> categorias() async => categoriasDePrueba;

  @override
  Future<Pagina<Producto>> productos(FiltroCatalogo filtro, {int pagina = 1}) async {
    consultas.add(filtro);
    final todos = [pollo, papas, jarabe];
    final lista = filtro.categoria == 2 ? [jarabe] : (filtro.soloOfertas ? [pollo] : todos);
    return Pagina(items: lista, pagina: 1, ultimaPagina: 1);
  }

  @override
  Future<ProductoDetalle> producto(int id) async => ProductoDetalle(
    producto: [pollo, papas, jarabe, cervezaDePrueba].firstWhere((p) => p.id == id),
    pedidoMinimo: 20,
    tiempoPreparacionMin: 25,
    resenas: [
      Resena(
        id: 1,
        tipo: 'producto',
        estrellas: 5,
        autor: 'Lucía R.',
        comentario: '¡Riquísimo!',
        fecha: DateTime(2026, 10, 1),
      ),
    ],
  );

  /// Ubicaciones con las que se pidieron las tiendas (null = sin ubicación).
  final ubicacionesTiendas = <Coordenada?>[];

  @override
  Future<Pagina<Tienda>> tiendas({
    int? categoria,
    String? texto,
    int pagina = 1,
    Coordenada? ubicacion,
    bool cerca = false,
  }) async {
    ubicacionesTiendas.add(ubicacion);
    return Pagina(
      items: [
        Tienda(
          id: 5,
          nombre: 'Pollos Marta',
          categoria: 'Alimentos y Bebidas',
          rating: 4.5,
          totalResenas: 3,
          envio: ubicacion == null ? null : envioDePrueba,
        ),
      ],
      pagina: 1,
      ultimaPagina: 1,
    );
  }

  @override
  Future<TiendaDetalle> tienda(int id, {Coordenada? ubicacion}) async => TiendaDetalle(
    tienda: Tienda(
      id: 5,
      nombre: 'Pollos Marta',
      pedidoMinimo: 20,
      tiempoPreparacionMin: 25,
      envio: ubicacion == null ? null : envioDePrueba,
    ),
    productos: const [pollo, papas],
  );
}

class PedidosFalso extends PedidosRepository {
  PedidosFalso({this.pedidoActual}) : super(Dio());

  Pedido? pedidoActual;
  ({Carrito carrito, DestinoPedido destino, String metodoPago, double? pagaCon, bool confirmaMayorEdad})? creado;
  int cancelados = 0;

  /// La API pide confirmar la edad (el carrito tiene algo +18 aunque la app no lo sepa).
  bool exigeMayorEdad = false;

  @override
  Future<List<Direccion>> direcciones() async => [casa];

  @override
  Future<Cotizacion> cotizar(int negocioId, Coordenada destino, List<int> productos) async =>
      const Cotizacion(costoEnvio: 5, tarifaServicio: 0, distanciaKm: 2.4, anillo: 3);

  @override
  Future<Pedido> crear(
    Carrito carrito,
    DestinoPedido destino, {
    required String metodoPago,
    String? notas,
    double? pagaCon,
    bool confirmaMayorEdad = false,
  }) async {
    // Como la API: un producto +18 que la app no sabía que lo era.
    if (exigeMayorEdad && !confirmaMayorEdad) {
      throw ApiException(
        'Tu pedido tiene productos para mayores de 18 años: confirma que eres mayor de edad.',
        statusCode: 422,
        errores: const {
          'confirma_mayor_edad': [
            'Tu pedido tiene productos para mayores de 18 años: confirma que eres mayor de edad.',
          ],
        },
      );
    }
    creado = (
      carrito: carrito,
      destino: destino,
      metodoPago: metodoPago,
      pagaCon: pagaCon,
      confirmaMayorEdad: confirmaMayorEdad,
    );
    return pedidoActual = pedidoDeEjemplo(acciones: const [EstadoPedido.cancelado], metodoPago: metodoPago);
  }

  /// Veces que se tocó "Simular pago" (cobro con QR de prueba).
  int pagosQr = 0;

  @override
  Future<Pedido> pagarQr(int id) async {
    pagosQr++;
    return pedidoActual = pedidoDeEjemplo(
      acciones: const [EstadoPedido.cancelado],
      metodoPago: 'qr',
      estadoPago: 'pagado',
    );
  }

  @override
  Future<Pagina<Pedido>> misPedidos({int pagina = 1}) async => Pagina(
    items: [
      pedidoDeEjemplo(),
      pedidoDeEjemplo(estado: EstadoPedido.entregado),
    ],
    pagina: 1,
    ultimaPagina: 1,
  );

  @override
  Future<Pedido> pedido(int id) async => pedidoActual ?? pedidoDeEjemplo();

  /// Respuestas del rastreo, una por consulta (la última se repite).
  List<Seguimiento> seguimientos = const [];
  int consultasSeguimiento = 0;

  @override
  Future<Seguimiento> seguimiento(int id) async =>
      seguimientos[math.min(consultasSeguimiento++, seguimientos.length - 1)];

  /// Calificaciones al repartidor que se enviaron.
  final calificacionesRepartidor = <({int repartidorId, int estrellas, List<String> etiquetas})>[];

  @override
  Future<void> calificarRepartidor({
    required int repartidorId,
    required int estrellas,
    List<String> etiquetas = const [],
    String? comentario,
  }) async => calificacionesRepartidor.add((repartidorId: repartidorId, estrellas: estrellas, etiquetas: etiquetas));

  @override
  Future<List<MotivoReporte>> motivosReporte(String sobre) async => sobre == 'negocio'
      ? const [
          (codigo: 'pedido_incompleto', nombre: 'Pedido incompleto o en mal estado'),
          (codigo: 'otro', nombre: 'Otro motivo'),
        ]
      : const [(codigo: 'maltrato', nombre: 'Maltrato, insultos o acoso'), (codigo: 'otro', nombre: 'Otro motivo')];

  /// Reportes enviados.
  final reportes = <({int pedidoId, String sobre, String motivo, String? descripcion})>[];

  @override
  Future<String> reportar(int pedidoId, {required String sobre, required String motivo, String? descripcion}) async {
    reportes.add((pedidoId: pedidoId, sobre: sobre, motivo: motivo, descripcion: descripcion));
    return 'Gracias por avisarnos. El equipo de MDR Market lo va a revisar.';
  }

  @override
  Future<Pedido> cancelar(int id, {String? motivo}) async {
    cancelados++;
    return pedidoActual = pedidoDeEjemplo(estado: EstadoPedido.cancelado);
  }
}

class NotificacionesFalso extends NotificacionesRepository {
  NotificacionesFalso([List<Notificacion>? avisos])
    : avisos =
          avisos ??
          [
            Notificacion(
              id: 1,
              tipo: 'pedido_en_camino',
              titulo: 'Tu pedido va en camino',
              pedidoId: 42,
              fecha: DateTime(2026, 11, 16, 14),
            ),
            Notificacion(
              id: 2,
              tipo: 'pedido_entregado',
              titulo: 'Pedido entregado. ¡Califícalo!',
              leida: true,
              fecha: DateTime(2026, 11, 15),
            ),
          ],
      super(Dio());

  List<Notificacion> avisos;
  final leidas = <int>[];

  @override
  Future<({List<Notificacion> items, int noLeidas})> lista() async =>
      (items: avisos, noLeidas: avisos.where((a) => !a.leida).length);

  @override
  Future<void> leer(int id) async {
    leidas.add(id);
    avisos = [for (final a in avisos) a.id == id ? a.leidaYa() : a];
  }

  @override
  Future<void> leerTodas() async => avisos = [for (final a in avisos) a.leidaYa()];
}

class MiNegocioFalso extends MiNegocioRepository {
  MiNegocioFalso() : super(Dio());

  final cambios = <EstadoPedido>[];

  /// Motivo enviado con cada cambio (rechazar lleva motivo).
  final motivos = <String?>[];

  /// El pedido que se abre (por defecto: listo y sin repartidor, "Buscando repartidor…").
  Pedido? pedidoMostrado;

  static const _montos = Montos(ventas: 350, gananciaBruta: 140, gastos: 40, gananciaNeta: 100, unidadesVendidas: 12);

  @override
  Future<ResumenNegocio> resumen(int negocioId) async => const ResumenNegocio(
    pedidosNuevos: 2,
    pedidosEnCurso: 1,
    hoy: _montos,
    mes: _montos,
    productosActivos: 8,
    productosSinStock: 1,
    productosAgotados: ['Papas fritas'],
    unidadesEnStock: 8,
    rating: 4.5,
    totalResenas: 3,
    ayer: Montos(ventas: 280),
    variacionVentasPct: 25,
    pedidosHoy: 9,
    pedidosEnCamino: 2,
    pocoStock: [(id: 13, nombre: 'Salsa picante', stock: 3)],
    productosPocoStock: 1,
  );

  /// Renovaciones de stock: (producto, unidades).
  final renovados = <(int, int)>[];

  @override
  Future<MiProducto> renovarStock(int negocioId, int productoId, int stock) async {
    renovados.add((productoId, stock));
    return MiProducto(id: productoId, nombre: 'Papas fritas', precio: 12, stock: stock, categoriaId: 101);
  }

  @override
  Future<List<MiProducto>> productos(int negocioId) async => const [
    MiProducto(
      id: 10,
      nombre: 'Pollo a la broaster',
      precio: 35,
      precioOferta: 28,
      enOferta: true,
      stock: 8,
      categoriaId: 101,
    ),
    MiProducto(id: 11, nombre: 'Papas fritas', precio: 12, stock: 0, categoriaId: 101),
    MiProducto(id: 12, nombre: 'Refresco 2 L', precio: 15, disponible: false, categoriaId: 101),
  ];

  /// Lo que se guardó: (datos, cuántas fotos nuevas).
  final guardados = <(DatosProducto, int)>[];
  final fotosBorradas = <int>[];

  @override
  Future<MiProducto> guardarProducto(
    int negocioId,
    DatosProducto datos, {
    int? productoId,
    List<ArchivoElegido> fotos = const [],
  }) async {
    guardados.add((datos, fotos.length));
    return MiProducto(id: productoId ?? 99, nombre: datos.nombre, precio: datos.precio);
  }

  @override
  Future<MiProducto> borrarFoto(int negocioId, int productoId, int imagenId) async {
    fotosBorradas.add(imagenId);
    return MiProducto(
      id: productoId,
      nombre: 'Pollo a la broaster',
      precio: 35,
      imagenes: const [FotoProducto(id: 2, url: 'https://mdrmarket.test/b.png', portada: true)],
    );
  }

  /// Pedidos que muestra la lista (por defecto, uno listo sin repartidor).
  List<Pedido>? lista;

  /// Productos marcados como alistados: (línea, alistado).
  final marcados = <(int, bool)>[];

  @override
  Future<Pedido> marcarAlistado(int negocioId, int pedidoId, int itemId, bool alistado) async {
    marcados.add((itemId, alistado));
    final hechos = {for (final (id, si) in marcados) id: si};
    pedidoMostrado = pedidoDeEjemplo(
      paraNegocio: true,
      estado: EstadoPedido.preparando,
      acciones: const [EstadoPedido.listo],
      alistados: {
        for (final e in hechos.entries)
          if (e.value) e.key,
      },
    );
    return pedidoMostrado!;
  }

  @override
  Future<List<DocumentoSubido>> documentos() async => const [
    DocumentoSubido(id: 1, tipo: 'nit', nombre: 'NIT', estado: 'aprobado', negocioId: 5),
    DocumentoSubido(
      id: 2,
      tipo: 'licencia_funcionamiento',
      nombre: 'Licencia de funcionamiento',
      estado: 'rechazado',
      observacion: 'La foto está borrosa',
      negocioId: 5,
    ),
    DocumentoSubido(id: 3, tipo: 'ci_anverso', nombre: 'Carnet (frente)', estado: 'pendiente'),
  ];

  @override
  Future<Pagina<Pedido>> pedidos(int negocioId, String grupo, {int pagina = 1}) async =>
      Pagina(items: lista ?? [pedidoDeEjemplo(paraNegocio: true)], pagina: 1, ultimaPagina: 1);

  // El local llega hasta "listo": recoger y entregar lo hace el repartidor.
  // Listo ya no tiene botones: aceptado, el local no lo puede cancelar.
  @override
  Future<Pedido> pedido(int negocioId, int pedidoId) async =>
      pedidoMostrado ??
      (cambios.isNotEmpty
          ? pedidoDeEjemplo(paraNegocio: true, estado: cambios.last, acciones: _siguientes(cambios.last))
          : pedidoDeEjemplo(paraNegocio: true, estado: EstadoPedido.listo));

  static List<EstadoPedido> _siguientes(EstadoPedido e) => switch (e) {
    EstadoPedido.confirmado => const [EstadoPedido.preparando],
    EstadoPedido.preparando => const [EstadoPedido.listo],
    _ => const [],
  };

  @override
  Future<Pedido> cambiarEstado(
    int negocioId,
    int pedidoId,
    EstadoPedido estado, {
    String? motivo,
    String? codigo,
  }) async {
    cambios.add(estado);
    motivos.add(motivo);
    pedidoMostrado = null;
    return pedidoDeEjemplo(paraNegocio: true, estado: estado, acciones: _siguientes(estado));
  }

  @override
  Future<Reporte> reporte(int negocioId, DateTime desde, DateTime hasta, String agrupar) async {
    // Los 3 últimos días del rango (así caen en "Esta semana" del resumen).
    String dia(int antes) => Formato.fechaApi(hasta.subtract(Duration(days: antes)));
    return Reporte(
      totales: _montos,
      agrupar: 'dia',
      periodos: [
        (periodo: dia(2), montos: const Montos(ventas: 100, gananciaBruta: 40)),
        (periodo: dia(1), montos: const Montos(ventas: 150, gananciaBruta: 60)),
        (periodo: dia(0), montos: const Montos(ventas: 100, gananciaBruta: 40)),
      ],
    );
  }

  @override
  Future<List<ReporteProducto>> reporteProductos(int negocioId, DateTime desde, DateTime hasta) async => const [
    ReporteProducto(
      productoId: 10,
      producto: 'Pollo a la broaster',
      unidadesVendidas: 10,
      ventas: 280,
      ganancia: 120,
      gastoEnCompras: 0,
      margenPct: 42.9,
    ),
    ReporteProducto(
      productoId: 11,
      producto: 'Papas fritas',
      unidadesVendidas: 25,
      ventas: 300,
      ganancia: 90,
      gastoEnCompras: 0,
      margenPct: 30,
    ),
  ];
}

const repartidorEnRevision = Usuario(
  id: 1,
  nombre: 'Diego',
  apellido: 'Rodríguez',
  email: 'diego@correo.com',
  ciNumero: '1234567',
  vistas: [Vista.cliente, Vista.repartidor],
  vistaGuardada: 'repartidor',
  estadoRepartidor: 'pendiente',
);

/// Los 5 tipos de vehículo, como los manda `GET /api/tipos-vehiculo`.
const tiposDePrueba = [
  TipoVehiculo(
    id: 1,
    codigo: 'moto',
    nombre: 'Moto',
    categoria: 'Liviano',
    descripcion: 'Motos y bicicletas: paquetes chicos y comida',
  ),
  TipoVehiculo(
    id: 2,
    codigo: 'bicicleta',
    nombre: 'Bicicleta',
    requierePlaca: false,
    requiereRuat: false,
    requiereLicencia: false,
    categoria: 'Liviano',
  ),
  TipoVehiculo(id: 3, codigo: 'auto', nombre: 'Auto', categoria: 'Mediano'),
  TipoVehiculo(id: 4, codigo: 'camioneta', nombre: 'Camioneta', categoria: 'Mediano'),
  TipoVehiculo(id: 5, codigo: 'camion', nombre: 'Camión', categoria: 'Grande'),
];

/// Lo que la API pide a un repartidor nuevo en moto (vehículo 4).
const faltaMoto = [
  ...faltaIdentidad,
  Faltante(codigo: 'documento.licencia_conducir', texto: 'Foto: Licencia de conducir', documento: 'licencia_conducir'),
  Faltante(
    codigo: 'documento.foto_vehiculo:vehiculo4',
    texto: 'Foto del vehículo',
    documento: 'foto_vehiculo',
    vehiculoId: 4,
  ),
  Faltante(codigo: 'documento.foto_placa:vehiculo4', texto: 'Foto de la placa', documento: 'foto_placa', vehiculoId: 4),
  Faltante(codigo: 'documento.ruat:vehiculo4', texto: 'Foto: RUAT del vehículo', documento: 'ruat', vehiculoId: 4),
];

class RepartidorFalso extends RepartidorRepository {
  RepartidorFalso({this.perfil, this.errorVehiculo}) : super(Dio());

  PerfilRepartidor? perfil;

  /// Si se pone, registrar el vehículo falla con este error (ej. placa repetida).
  final ApiException? errorVehiculo;
  int solicitudes = 0;
  final vehiculos = <DatosVehiculo>[];

  @override
  Future<List<TipoVehiculo>> tiposVehiculo() async => tiposDePrueba;

  @override
  Future<PerfilRepartidor?> miPerfil() async => perfil;

  @override
  Future<PerfilRepartidor> solicitar() async {
    solicitudes++;
    return perfil = const PerfilRepartidor(estado: 'pendiente');
  }

  @override
  Future<Vehiculo> registrarVehiculo(DatosVehiculo datos) async {
    if (errorVehiculo != null) throw errorVehiculo!;
    vehiculos.add(datos);
    return const Vehiculo(id: 4, tipoCodigo: 'moto', tipoNombre: 'Moto');
  }

  // ---------- Vista repartidor (módulo 8) ----------

  List<PedidoDisponible> listaDisponibles = const [];
  Pedido? actual;
  Entregas misEntregas = const Entregas(pedidos: []);

  /// Si se pone, aceptar falla con este error (ej. otro lo aceptó primero).
  ApiException? errorAceptar;
  final pinesProbados = <String>[];

  @override
  Future<bool> ponerDisponible(bool disponible, {Coordenada? ubicacion}) async {
    perfil = PerfilRepartidor(estado: perfil?.estado ?? 'aprobado', disponible: disponible);
    return disponible;
  }

  @override
  Future<List<PedidoDisponible>> disponibles() async => listaDisponibles;

  @override
  Future<Pedido?> pedidoActual() async => actual;

  @override
  Future<Pedido> aceptar(int pedidoId) async {
    if (errorAceptar != null) throw errorAceptar!;
    return actual = pedidoDeEjemplo(estado: EstadoPedido.listo, paraNegocio: true);
  }

  @override
  Future<Pedido> cambiarEstado(int pedidoId, EstadoPedido estado, {String? codigo}) async {
    if (codigo != null) {
      pinesProbados.add(codigo);
      if (codigo != '4821') {
        throw ApiException(
          'Datos inválidos',
          statusCode: 422,
          errores: {
            'codigo': ['El PIN no coincide. Pídeselo de nuevo al cliente.'],
          },
        );
      }
    }
    return actual = pedidoDeEjemplo(estado: estado, paraNegocio: true);
  }

  @override
  Future<Entregas> entregas() async => misEntregas;

  /// Lo que gana (hoy Bs 12 con 2 entregas; la semana, con el sábado como mejor día).
  Ganancias misGanancias = gananciasDePrueba;

  /// Metas que eligió (null = la quitó).
  final metas = <double?>[];

  @override
  Future<Ganancias> ganancias() async => misGanancias;

  @override
  Future<Ganancias> cambiarMeta(double? meta) async {
    metas.add(meta);
    return misGanancias = Ganancias(
      ganadoHoy: misGanancias.ganadoHoy,
      entregasHoy: misGanancias.entregasHoy,
      metaDiaria: meta,
      porDia: misGanancias.porDia,
    );
  }

  /// Posiciones que mandó (rastreo).
  final ubicacionesEnviadas = <Coordenada>[];

  @override
  Future<void> enviarUbicacion(Coordenada punto) async => ubicacionesEnviadas.add(punto);
}

/// Ganancias de prueba: hoy Bs 12 (2 entregas), meta Bs 150; la semana Bs 61 con el sábado como mejor día.
final gananciasDePrueba = Ganancias(
  entregasHoy: 2,
  ganadoHoy: 12,
  entregasSemana: 9,
  ganadoSemana: 61,
  metaDiaria: 150,
  progresoMetaPct: 8,
  calificacion: 4.9,
  totalResenas: 20,
  totalEntregas: 47,
  mejorDia: DateTime(2026, 11, 14),
  porDia: [
    for (final (i, ganado) in [5.0, 0.0, 8.0, 12.0, 10.0, 26.0, 0.0].indexed)
      DiaGanancia(
        fecha: DateTime(2026, 11, 9 + i),
        dia: const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i],
        entregas: ganado > 0 ? 1 : 0,
        ganado: ganado,
      ),
  ],
);

const repartidorAprobado = Usuario(
  id: 3,
  nombre: 'Diego',
  apellido: 'Rodríguez',
  email: 'diego@correo.com',
  ciNumero: '1234567',
  vistas: [Vista.cliente, Vista.repartidor],
  vistaGuardada: 'repartidor',
  estadoRepartidor: 'aprobado',
);

/// Dos pedidos listos cerca, como los manda la API.
const disponiblesDePrueba = [
  PedidoDisponible(
    id: 42,
    negocioNombre: 'Pollos Marta',
    negocioDireccion: 'Av. Busch 1234',
    direccionEntrega: 'Calle Libertad 123',
    distanciaKm: 2.4,
    distanciaAlNegocioKm: 0.8,
    costoEnvio: 5,
    total: 73,
    tamano: 'Liviano',
  ),
  PedidoDisponible(
    id: 43,
    negocioNombre: 'Farmacia Central',
    direccionEntrega: 'Av. Beni 456',
    distanciaKm: 5.1,
    costoEnvio: 8,
    total: 40,
    metodoPago: 'qr',
    tamano: 'Liviano',
  ),
];

/// Todo lo que las pantallas piden a la API, reemplazado por datos falsos.
List overridesFalsos({
  required Usuario usuario,
  CatalogoFalso? catalogo,
  PedidosFalso? pedidos,
  MiNegocioFalso? miNegocio,
  RepartidorFalso? repartidor,
  List<Negocio> negocios = const [],
  List<Faltante> faltantes = const [],
  LecturaGps gps = const LecturaGps(Coordenada(-17.78, -63.18)),
  Widget Function(Seguimiento)? mapa,
  NotificacionesFalso? notificaciones,
  Preferencias? preferencias,
  List<DocumentoSubido> documentos = const [],
}) => [
  repartidorRepositoryProvider.overrideWithValue(repartidor ?? RepartidorFalso()),
  notificacionesRepositoryProvider.overrideWithValue(notificaciones ?? NotificacionesFalso()),
  // Preferencias (tema, búsquedas) en memoria: sin almacenamiento del teléfono.
  preferenciasProvider.overrideWithValue(preferencias ?? PreferenciasEnMemoria()),
  // Sin GPS en las pruebas.
  ubicacionActualProvider.overrideWithValue(() async => null),
  leerGpsProvider.overrideWithValue(() async => gps),
  // Sin clave de Google Maps (como en las pruebas); se puede pasar un mapa falso.
  mapaSeguimientoProvider.overrideWithValue(mapa),
  authControllerProvider.overrideWith(() => SesionFalsa(usuario)),
  catalogoRepositoryProvider.overrideWithValue(catalogo ?? CatalogoFalso()),
  pedidosRepositoryProvider.overrideWithValue(pedidos ?? PedidosFalso()),
  miNegocioRepositoryProvider.overrideWithValue(miNegocio ?? MiNegocioFalso()),
  misNegociosProvider.overrideWith((ref) async => negocios),
  faltantesProvider.overrideWith((ref, rol) async => faltantes),
  misDocumentosProvider.overrideWith((ref) async => documentos),
  terminosProvider.overrideWith((ref) async => terminosDePrueba),
  elegirFotoProvider.overrideWithValue(() async => fotoDePrueba),
];

/// Una imagen PNG de 1×1 para elegir "de la galería" en las pruebas.
final fotoDePrueba = ArchivoElegido(
  bytes: Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01, //
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41, //
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0xF0,
    0x1F,
    0x00,
    0x05,
    0x00,
    0x01,
    0xFF,
    0x89,
    0x99,
    0x3D,
    0x1D,
    0x00,
    0x00, //
    0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
  nombre: 'foto.png',
);

/// Abre [pantalla] en tamaño de celular con los datos falsos.
Future<void> abrirConFalsos(
  WidgetTester tester,
  Widget pantalla, {
  required List overrides,
  Size tamano = const Size(390, 844),
  ThemeData? tema,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: tema ?? AppTheme.claro,
        home: Scaffold(body: pantalla),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Desarma la pantalla al final de la prueba: así se cancelan los relojes de
/// las vistas que se actualizan solas (Timer.periodic).
Future<void> cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
