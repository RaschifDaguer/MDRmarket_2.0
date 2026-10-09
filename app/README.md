# MDR Market 2.0 — App (Flutter)

App de delivery con tres vistas: cliente, repartidor y comerciante.
Usa la API de [`../api`](../api).

## Ejecutar

1. Encender la API (ver [`api/README.md`](../api/README.md)):
   ```
   cd api
   php artisan serve --host=0.0.0.0 --port=8001
   ```
2. Ejecutar la app desde esta carpeta:
   ```
   flutter pub get
   flutter run -d chrome          # en el navegador
   flutter run                    # en el emulador Android
   ```
   Con un celular real en la misma red Wi-Fi, usar la IP de la PC:
   ```
   flutter run --dart-define=API_URL=http://192.168.1.50:8001/api
   ```

Por defecto la app busca la API en `http://localhost:8001/api` (Chrome) o
`http://10.0.2.2:8001/api` (emulador Android). Ver `lib/core/config/env.dart`.

### Con el mapa de Google (Chrome)

La clave de Google Maps **nunca** va en el código (el repo es público):

1. Copia `dart_defines.example.json` como `dart_defines.local.json` (está en
   `.gitignore`) y pega la clave en `GOOGLE_MAPS_KEY`.
2. En Google Cloud, la clave debe tener activada la **Maps JavaScript API**.
3. Ejecuta:
   ```
   flutter run -d chrome --dart-define-from-file=dart_defines.local.json
   ```

Sin clave la app funciona igual: en lugar del mapa muestra solo el botón
"Usar mi ubicación" (GPS).

## Estructura

```
lib/
  core/        configuración, conexión con la API, tema, rutas
  features/    una carpeta por funcionalidad (auth, inicio, …)
    <feature>/data          llamadas a la API
    <feature>/domain        modelos
    <feature>/presentation  pantallas y estado (Riverpod)
```

Identificador de la app: `bo.mdrmarket.app`. Colores de marca:
`lib/core/theme/app_colores.dart` (el tema completo está en `app_theme.dart`).

## Pruebas

```
flutter test                                                      # pantallas, registro y comerciante (datos falsos)
flutter test --dart-define=API_URL=http://127.0.0.1:8001/api      # + recorridos reales contra la API local
```
Las pruebas con `API_URL` crean usuarios y negocios de prueba: úsalas solo con
la base local.
