// Datos y repositorios falsos para probar las pantallas sin internet.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/archivos/archivo_elegido.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/network/api_exception.dart';
import 'package:mdrmarket/core/network/pagina.dart';
import 'package:mdrmarket/core/theme/app_theme.dart';
import 'package:mdrmarket/features/auth/domain/usuario.dart';
import 'package:mdrmarket/features/auth/presentation/auth_controller.dart';
import 'package:mdrmarket/features/carrito/domain/carrito.dart';
import 'package:mdrmarket/features/catalogo/data/catalogo_repository.dart';
import 'package:mdrmarket/features/catalogo/domain/categoria.dart';
import 'package:mdrmarket/features/catalogo/domain/producto.dart';
import 'package:mdrmarket/features/catalogo/domain/resena.dart';
import 'package:mdrmarket/features/catalogo/domain/tienda.dart';
import 'package:mdrmarket/features/comerciante/data/mi_negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/data/negocio_repository.dart';
import 'package:mdrmarket/features/comerciante/domain/finanzas.dart';
import 'package:mdrmarket/features/comerciante/domain/horario.dart';
import 'package:mdrmarket/features/comerciante/domain/mi_producto.dart';
import 'package:mdrmarket/features/comerciante/domain/negocio.dart';
import 'package:mdrmarket/features/pedidos/data/pedidos_repository.dart';
import 'package:mdrmarket/features/pedidos/domain/direccion.dart';
import 'package:mdrmarket/features/pedidos/domain/pedido.dart';
import 'package:mdrmarket/features/perfil/data/perfil_repository.dart';
import 'package:mdrmarket/features/perfil/domain/faltante.dart';
import 'package:mdrmarket/features/repartidor/data/repartidor_repository.dart';
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
  Categoria(id: 1, nombre: 'Alimentos y Bebidas', subcategorias: [Categoria(id: 101, nombre: 'Restaurantes')]),
  Categoria(id: 2, nombre: 'Salud y Belleza', subcategorias: [Categoria(id: 201, nombre: 'Farmacia')]),
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
}) {
  return Pedido(
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
    metodoPago: 'efectivo',
    codigoEntrega: paraNegocio ? null : '4821',
    distanciaKm: 2.4,
    items: const [
      ItemPedido(productoId: 10, nombre: 'Pollo a la broaster', precioUnitario: 28, cantidad: 2, subtotal: 56),
      ItemPedido(productoId: 11, nombre: 'Papas fritas', precioUnitario: 12, cantidad: 1, subtotal: 12, notas: 'Sin sal'),
    ],
    historial: [(estado: EstadoPedido.pendiente, fecha: DateTime(2026, 10, 9, 12, 30), motivo: null)],
    acciones: acciones ?? const [],
    creado: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

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
        producto: [pollo, papas, jarabe].firstWhere((p) => p.id == id),
        pedidoMinimo: 20,
        tiempoPreparacionMin: 25,
        resenas: [Resena(id: 1, tipo: 'producto', estrellas: 5, autor: 'Lucía R.', comentario: '¡Riquísimo!', fecha: DateTime(2026, 10, 1))],
      );

  @override
  Future<Pagina<Tienda>> tiendas({int? categoria, String? texto, int pagina = 1}) async => const Pagina(
        items: [Tienda(id: 5, nombre: 'Pollos Marta', categoria: 'Alimentos y Bebidas', rating: 4.5, totalResenas: 3)],
        pagina: 1,
        ultimaPagina: 1,
      );

  @override
  Future<TiendaDetalle> tienda(int id) async => const TiendaDetalle(
        tienda: Tienda(id: 5, nombre: 'Pollos Marta', pedidoMinimo: 20, tiempoPreparacionMin: 25),
        productos: [pollo, papas],
      );
}

class PedidosFalso extends PedidosRepository {
  PedidosFalso({this.pedidoActual}) : super(Dio());

  Pedido? pedidoActual;
  ({Carrito carrito, DestinoPedido destino, String metodoPago})? creado;
  int cancelados = 0;

  @override
  Future<List<Direccion>> direcciones() async => [casa];

  @override
  Future<Cotizacion> cotizar(int negocioId, Coordenada destino, List<int> productos) async =>
      const Cotizacion(costoEnvio: 5, tarifaServicio: 0, distanciaKm: 2.4, anillo: 3);

  @override
  Future<Pedido> crear(Carrito carrito, DestinoPedido destino, {required String metodoPago, String? notas}) async {
    creado = (carrito: carrito, destino: destino, metodoPago: metodoPago);
    return pedidoActual = pedidoDeEjemplo(acciones: const [EstadoPedido.cancelado]);
  }

  @override
  Future<Pagina<Pedido>> misPedidos({int pagina = 1}) async => Pagina(
        items: [pedidoDeEjemplo(), pedidoDeEjemplo(estado: EstadoPedido.entregado)],
        pagina: 1,
        ultimaPagina: 1,
      );

  @override
  Future<Pedido> pedido(int id) async => pedidoActual ?? pedidoDeEjemplo();

  @override
  Future<Pedido> cancelar(int id, {String? motivo}) async {
    cancelados++;
    return pedidoActual = pedidoDeEjemplo(estado: EstadoPedido.cancelado);
  }
}

class MiNegocioFalso extends MiNegocioRepository {
  MiNegocioFalso() : super(Dio());

  final cambios = <EstadoPedido>[];

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
        rating: 4.5,
        totalResenas: 3,
      );

  @override
  Future<List<MiProducto>> productos(int negocioId) async => const [
        MiProducto(id: 10, nombre: 'Pollo a la broaster', precio: 35, precioOferta: 28, enOferta: true, stock: 8, categoriaId: 101),
        MiProducto(id: 11, nombre: 'Papas fritas', precio: 12, stock: 0, categoriaId: 101),
        MiProducto(id: 12, nombre: 'Refresco 2 L', precio: 15, disponible: false, categoriaId: 101),
      ];

  @override
  Future<MiProducto> guardarProducto(int negocioId, DatosProducto datos, {int? productoId, ArchivoElegido? foto}) async =>
      MiProducto(id: productoId ?? 99, nombre: datos.nombre, precio: datos.precio);

  @override
  Future<Pagina<Pedido>> pedidos(int negocioId, String grupo, {int pagina = 1}) async => Pagina(
        items: [pedidoDeEjemplo(paraNegocio: true)],
        pagina: 1,
        ultimaPagina: 1,
      );

  // El local llega hasta "listo": recoger y entregar lo hace el repartidor.
  @override
  Future<Pedido> pedido(int negocioId, int pedidoId) async =>
      pedidoMostrado ??
      pedidoDeEjemplo(
        paraNegocio: true,
        estado: cambios.isEmpty ? EstadoPedido.listo : cambios.last,
        acciones: cambios.isEmpty ? const [EstadoPedido.cancelado] : const [],
      );

  @override
  Future<Pedido> cambiarEstado(int negocioId, int pedidoId, EstadoPedido estado, {String? motivo, String? codigo}) async {
    cambios.add(estado);
    return pedidoDeEjemplo(paraNegocio: true, estado: estado);
  }

  @override
  Future<Reporte> reporte(int negocioId, DateTime desde, DateTime hasta, String agrupar) async => const Reporte(
        totales: _montos,
        agrupar: 'dia',
        periodos: [
          (periodo: '2026-10-07', montos: Montos(ventas: 100, gananciaBruta: 40)),
          (periodo: '2026-10-08', montos: Montos(ventas: 150, gananciaBruta: 60)),
          (periodo: '2026-10-09', montos: Montos(ventas: 100, gananciaBruta: 40)),
        ],
      );

  @override
  Future<List<ReporteProducto>> reporteProductos(int negocioId, DateTime desde, DateTime hasta) async => const [
        ReporteProducto(productoId: 10, producto: 'Pollo a la broaster', unidadesVendidas: 10, ventas: 280, ganancia: 120, gastoEnCompras: 0, margenPct: 42.9),
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
  TipoVehiculo(id: 1, codigo: 'moto', nombre: 'Moto', categoria: 'Liviano', descripcion: 'Motos y bicicletas: paquetes chicos y comida'),
  TipoVehiculo(id: 2, codigo: 'bicicleta', nombre: 'Bicicleta', requierePlaca: false, requiereRuat: false, requiereLicencia: false, categoria: 'Liviano'),
  TipoVehiculo(id: 3, codigo: 'auto', nombre: 'Auto', categoria: 'Mediano'),
  TipoVehiculo(id: 4, codigo: 'camioneta', nombre: 'Camioneta', categoria: 'Mediano'),
  TipoVehiculo(id: 5, codigo: 'camion', nombre: 'Camión', categoria: 'Grande'),
];

/// Lo que la API pide a un repartidor nuevo en moto (vehículo 4).
const faltaMoto = [
  ...faltaIdentidad,
  Faltante(codigo: 'documento.licencia_conducir', texto: 'Foto: Licencia de conducir', documento: 'licencia_conducir'),
  Faltante(codigo: 'documento.foto_vehiculo:vehiculo4', texto: 'Foto del vehículo', documento: 'foto_vehiculo', vehiculoId: 4),
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
        throw ApiException('Datos inválidos', statusCode: 422, errores: {
          'codigo': ['El PIN no coincide. Pídeselo de nuevo al cliente.'],
        });
      }
    }
    return actual = pedidoDeEjemplo(estado: estado, paraNegocio: true);
  }

  @override
  Future<Entregas> entregas() async => misEntregas;
}

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
}) =>
    [
      repartidorRepositoryProvider.overrideWithValue(repartidor ?? RepartidorFalso()),
      // Sin GPS en las pruebas.
      ubicacionActualProvider.overrideWithValue(() async => null),
      authControllerProvider.overrideWith(() => SesionFalsa(usuario)),
      catalogoRepositoryProvider.overrideWithValue(catalogo ?? CatalogoFalso()),
      pedidosRepositoryProvider.overrideWithValue(pedidos ?? PedidosFalso()),
      miNegocioRepositoryProvider.overrideWithValue(miNegocio ?? MiNegocioFalso()),
      misNegociosProvider.overrideWith((ref) async => negocios),
      faltantesProvider.overrideWith((ref, rol) async => faltantes),
    ];

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
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides.cast(),
    child: MaterialApp(theme: tema ?? AppTheme.claro, home: Scaffold(body: pantalla)),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Desarma la pantalla al final de la prueba: así se cancelan los relojes de
/// las vistas que se actualizan solas (Timer.periodic).
Future<void> cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
