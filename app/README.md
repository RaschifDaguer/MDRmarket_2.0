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

## Estructura

```
lib/
  core/        configuración, conexión con la API, tema, rutas
  features/    una carpeta por funcionalidad (auth, inicio, …)
    <feature>/data          llamadas a la API
    <feature>/domain        modelos
    <feature>/presentation  pantallas y estado (Riverpod)
```

Identificador de la app: `bo.mdrmarket.app`. Color de marca:
`lib/core/theme/app_theme.dart`.

## Pruebas

```
flutter test                                                      # formulario de registro
flutter test --dart-define=API_URL=http://127.0.0.1:8001/api      # + recorrido real contra la API
```
