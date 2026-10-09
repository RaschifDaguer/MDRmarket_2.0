import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Una foto elegida por el usuario, lista para mostrar y subir a la API.
/// Se guarda en bytes para que funcione igual en web y en celular.
class ArchivoElegido {
  const ArchivoElegido({required this.bytes, required this.nombre});

  final Uint8List bytes;
  final String nombre;
}

/// Abre la galería (o la cámara) y devuelve la foto achicada a 1600 px y
/// comprimida, para que suba rápido. Devuelve null si el usuario cancela.
Future<ArchivoElegido?> elegirFoto({bool camara = false}) async {
  final foto = await ImagePicker().pickImage(
    source: camara ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (foto == null) return null;
  return ArchivoElegido(bytes: await foto.readAsBytes(), nombre: foto.name);
}
