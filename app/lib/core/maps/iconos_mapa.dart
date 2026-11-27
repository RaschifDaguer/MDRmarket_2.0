import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;

/// Íconos propios de los marcadores de Google Maps: un círculo de color con
/// borde blanco y el símbolo en blanco (la moto, la persona, la tienda), igual
/// que los del mapa de OpenStreetMap. Google pide una imagen: se dibuja una
/// vez por ícono y color, y se guarda.
class IconosMapa {
  IconosMapa._();

  /// Tamaño en pantalla (el dibujo se hace a la densidad del teléfono, nítido).
  static const tamano = 44.0;

  static final _hechos = <String, Future<g.BitmapDescriptor>>{};

  static Future<g.BitmapDescriptor> de(IconData icono, Color fondo, double densidad) {
    final clave = '${icono.codePoint}-${fondo.toARGB32()}-$densidad';
    return _hechos[clave] ??= _dibujar(icono, fondo, densidad).then(
      (png) => g.BitmapDescriptor.bytes(png, width: tamano, height: tamano),
    );
  }

  /// PNG del ícono: sombra, círculo con borde blanco y el símbolo.
  static Future<Uint8List> dibujarPng(IconData icono, Color fondo, double densidad) => _dibujar(icono, fondo, densidad);

  static Future<Uint8List> _dibujar(IconData icono, Color fondo, double densidad) async {
    final lado = (tamano * densidad).round();
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    final centro = Offset(lado / 2, lado / 2);
    final radio = lado / 2 - 3 * densidad;

    lienzo.drawCircle(
      centro.translate(0, densidad),
      radio,
      Paint()
        ..color = Colors.black26
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * densidad),
    );
    lienzo.drawCircle(centro, radio, Paint()..color = Colors.white);
    lienzo.drawCircle(centro, radio - 2.5 * densidad, Paint()..color = fondo);

    final texto = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icono.codePoint),
        style: TextStyle(
          fontSize: 24 * densidad,
          fontFamily: icono.fontFamily,
          package: icono.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    texto.paint(lienzo, centro - Offset(texto.width / 2, texto.height / 2));

    final imagen = await grabadora.endRecording().toImage(lado, lado);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return datos!.buffer.asUint8List();
  }
}
