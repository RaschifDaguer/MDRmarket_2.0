# MDR Market 2.0

App de delivery para **Santa Cruz de la Sierra**, del centro al 10mo anillo,
con tres vistas en una sola cuenta:

- **Cliente:** compra productos de los negocios y sigue su pedido.
- **Repartidor:** lleva pedidos en moto, bicicleta, auto, camioneta o camión.
- **Comerciante:** publica productos, recibe pedidos y ve sus ganancias.

Cualquier usuario puede comprar. Si además se registra como repartidor o
comerciante, aparece el botón **"cambiar vista"**.

## Repositorios

| Repositorio | Contenido |
|---|---|
| **MDRmarket_2.0** (este) | Código: API Laravel (`api/`) y app Flutter (`app/`) |
| [MDRmarket_2.0_docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker) | Base de datos MySQL en Docker (script + Dockerfile) |

## Estructura

```
api/    API REST en Laravel 12 + Sanctum (login con tokens)
app/    App móvil y web en Flutter (Riverpod, GoRouter, Dio)
```

```
App Flutter  ──HTTP──▶  API Laravel  ──▶  MySQL (mdrmarket_new)
```

## Tecnologías

| Parte | Tecnología |
|---|---|
| App | Flutter 3.44 · Riverpod 3 · GoRouter · Dio · Material 3 |
| API | Laravel 12 · PHP 8.3 · Sanctum · mensajes en español |
| Base de datos | MySQL 8.4 · triggers, vistas y procedimientos para las reglas del negocio |
| Despliegue | Docker · Railway |

## Ejecutar en la PC (con Laragon)

1. **Base de datos:** importar `mdrmarketnewdatabase.sql` (del repo Docker) en
   phpMyAdmin. Crea la base `mdrmarket_new`.
2. **API:**
   ```
   cd api
   composer install
   copy .env.example .env
   php artisan key:generate
   php artisan serve --host=0.0.0.0 --port=8001
   ```
3. **App:**
   ```
   cd app
   flutter pub get
   flutter run -d chrome
   ```

Más detalles en [`api/README.md`](api/README.md) y [`app/README.md`](app/README.md).

## Avance

| Módulo | Estado |
|---|---|
| Base de datos (categorías, envío por km y anillos, reseñas, reportes, sanciones, ganancias) | ✅ |
| Registro e inicio de sesión (contraseña segura, escrita dos veces) | ✅ |
| Cambio de vista cliente / repartidor / comerciante | ✅ |
| Registro de repartidor y comerciante (documentos, vehículo, negocio) | ⏳ |
| Catálogo, carrito y pedidos | ⏳ |
| Seguimiento del repartidor en el mapa | ⏳ |
| Ganancias del comerciante, reseñas, reportes | ⏳ |
| Panel de administrador (Filament) | ⏳ |
