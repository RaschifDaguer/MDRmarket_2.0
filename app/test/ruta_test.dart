import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdrmarket/core/maps/coordenada.dart';
import 'package:mdrmarket/core/maps/mapas_repository.dart';
import 'package:mdrmarket/core/maps/ruta.dart';
import 'package:mdrmarket/core/maps/ruta_viva.dart';

import 'falsos.dart';

/// La ruta por las calles: dónde va uno sobre ella, cuánto falta, la próxima
/// indicación, y cuándo se recalcula.
void main() {
  // Repartidor → tienda → casa (con un codo en cada tramo, como una calle).
  const yo = Coordenada(-17.78, -63.19);
  const tienda = Coordenada(-17.7745, -63.1935);
  const casa = Coordenada(-17.79, -63.18);
  final ruta = rutaEnL([yo, tienda, casa]);

  group('Ruta', () {
    test('desde el inicio: falta todo y la próxima indicación es el primer giro', () {
      final a = ruta.avance(yo);
      expect(a.recorridoM, closeTo(0, 0.5));
      expect(a.fueraM, closeTo(0, 0.5));
      expect(ruta.tramoDe(a), 0);
      expect(ruta.metrosFaltan(a), closeTo(ruta.distanciaTotalLinea, 0.5));
      expect(ruta.proximoPaso(a)!.instruccion, 'Gira a la derecha hacia Av. Busch');
      // El codo está a ~371 m (0,0035° de longitud).
      expect(ruta.metrosHastaPaso(a, ruta.proximoPaso(a)!), closeTo(371, 3));
    });

    test('a mitad del primer tramo: lo recorrido se descuenta y la línea se recorta', () {
      final mitad = Coordenada(-17.78, (-63.19 + -63.1935) / 2);
      final a = ruta.avance(mitad);
      expect(a.recorridoM, closeTo(185, 3));
      expect(ruta.restante(a).first.longitud, closeTo(mitad.longitud, 1e-9));
      // El primer punto ya pasó: la línea empieza donde va (el punto proyectado).
      expect(ruta.restante(a), hasLength(ruta.puntos.length));
      expect(ruta.restante(a)[1], ruta.puntos[1]);
      // Hasta la tienda: ~186 m que faltan del primer tramo + ~612 m del segundo.
      expect(ruta.metrosFaltan(a, tramo: 0), closeTo(186 + 612, 6));
      expect(ruta.segundosFaltan(a, tramo: 0), closeTo((186 + 612) / 1000 / 25 * 3600, 2));
    });

    test('pasada la tienda va en el segundo tramo y la próxima es la llegada a la casa', () {
      final despues = Coordenada(-17.7745, -63.1850); // entre la tienda y el codo hacia la casa
      final a = ruta.avance(despues);
      expect(ruta.tramoDe(a), 1);
      expect(ruta.proximoPaso(a)!.instruccion, 'Gira a la derecha hacia Av. Busch');
      expect(ruta.proximoPaso(a)!.tramo, 1);
    });

    test('lejos de la línea: fueraM dice cuánto se salió', () {
      final a = ruta.avance(const Coordenada(-17.783, -63.19)); // ~330 m al sur del inicio
      expect(a.fueraM, closeTo(332, 5));
    });

    test('la línea recta (sin servicio de rutas) usa 25 km/h y no dice que sea por las calles', () {
      final recta = Ruta.recta([yo, casa]);
      expect(recta.porCalles, isFalse);
      expect(recta.duracionS, closeTo(recta.distanciaM / 1000 / 25 * 3600, 0.1));
      expect(recta.pasos, isEmpty);
    });

    test('lee la respuesta de la API', () {
      final r = Ruta.fromJson({
        'distancia_m': 1200,
        'duracion_s': 173,
        'puntos': [
          [-17.78, -63.19],
          [-17.78, -63.191],
          [-17.79, -63.18],
        ],
        'pasos': [
          {'instruccion': 'Gira a la izquierda hacia Av. Busch', 'tipo': 'turn', 'modificador': 'left', 'latitud': -17.78, 'longitud': -63.191, 'indice': 1, 'tramo': 0},
        ],
        'tramos': [
          {'indice_fin': 2},
        ],
      });
      expect(r.puntos, hasLength(3));
      expect(r.porCalles, isTrue);
      expect(r.pasos.single.modificador, 'left');
      expect(r.finDeTramos, [2]);
      expect(r.duracionS, 173);
    });
  });

  test('el vehículo para la ruta', () {
    expect(vehiculoParaRuta('bicicleta'), 'bicicleta');
    expect(vehiculoParaRuta('Bicicleta'), 'bicicleta');
    expect(vehiculoParaRuta('camioneta'), 'auto');
    expect(vehiculoParaRuta('moto'), 'moto');
    expect(vehiculoParaRuta(null), 'moto');
  });

  group('RutaViva', () {
    test('pide la ruta, la sigue y la recalcula solo si se sale (2 veces seguidas)', () {
      fakeAsync((async) {
        final pedidas = <List<Coordenada>>[];
        final viva = RutaViva(pedir: (p) async {
          pedidas.add(p);
          return rutaEnL(p);
        });
        viva.actualizar(origen: yo, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        expect(pedidas.single, [yo, tienda, casa]);
        expect(viva.ruta, isNotNull);

        // Avanza por la ruta: no se pide otra.
        viva.actualizar(origen: const Coordenada(-17.78, -63.191), paradas: const [tienda, casa]);
        async.elapse(const Duration(seconds: 20));
        expect(pedidas, hasLength(1));
        expect(viva.avance!.recorridoM, greaterThan(100));

        // Se sale una vez (un salto del GPS): todavía no. Dos seguidas: sí, desde donde está.
        const fuera = Coordenada(-17.785, -63.19);
        viva.actualizar(origen: fuera, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        expect(pedidas, hasLength(1));
        viva.actualizar(origen: fuera, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        expect(pedidas, hasLength(2));
        expect(pedidas.last.first, fuera);
        viva.dispose();
      });
    });

    test('al cambiar las paradas (ya lo recogió) pide otra enseguida', () {
      fakeAsync((async) {
        final pedidas = <List<Coordenada>>[];
        final viva = RutaViva(pedir: (p) async {
          pedidas.add(p);
          return rutaEnL(p);
        });
        viva.actualizar(origen: yo, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        viva.actualizar(origen: tienda, paradas: const [casa]);
        async.flushMicrotasks();
        expect(pedidas.last, [tienda, casa]);
        expect(viva.ruta!.finDeTramos, hasLength(1));
        viva.dispose();
      });
    });

    test('sin servicio de rutas: línea recta y lo reintenta después', () {
      fakeAsync((async) {
        var intentos = 0;
        final viva = RutaViva(pedir: (p) async {
          intentos++;
          throw Exception('sin servicio');
        });
        viva.actualizar(origen: yo, paradas: const [casa]);
        async.flushMicrotasks();
        expect(viva.ruta!.porCalles, isFalse);
        expect(viva.lineaRestante, hasLength(2));
        // Sigue fuera de la "ruta" recta: no reintenta hasta pasada la espera.
        const lejos = Coordenada(-17.70, -63.30);
        viva.actualizar(origen: lejos, paradas: const [casa]);
        viva.actualizar(origen: lejos, paradas: const [casa]);
        async.flushMicrotasks();
        expect(intentos, 1);
        async.elapse(const Duration(seconds: 25));
        viva.actualizar(origen: lejos, paradas: const [casa]);
        viva.actualizar(origen: lejos, paradas: const [casa]);
        async.flushMicrotasks();
        expect(intentos, 2);
        viva.dispose();
      });
    });

    test('si se calculó sin saber dónde estaba, pide otra en cuanto llega el GPS', () {
      fakeAsync((async) {
        final pedidas = <List<Coordenada>>[];
        final viva = RutaViva(pedir: (p) async {
          pedidas.add(p);
          return rutaEnL(p);
        });
        viva.actualizar(origen: null, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        expect(pedidas.single, [tienda, casa]);
        viva.actualizar(origen: yo, paradas: const [tienda, casa]);
        async.flushMicrotasks();
        expect(pedidas.last, [yo, tienda, casa]);
        viva.dispose();
      });
    });
  });
}
