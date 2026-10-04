# API para el frontend

Qué manda y qué recibe la app en cada pantalla. Sirve para maquetar con
**datos de prueba** las pantallas cuya ruta de la API todavía no existe, sin
trabajar a ciegas.

- **Parte 1:** rutas que **ya funcionan** (registro, login, perfil, vistas).
- **Parte 2:** datos que tendrán las pantallas **pendientes**. Salen de las
  vistas reales de la base, pero la ruta se confirma al construir cada módulo.

Ver también: [diagrama de la base](DIAGRAMA_BD.md) · [hoja de ruta](HOJA_DE_RUTA.md).

---

## Conexión

| | |
|---|---|
| **URL base (internet)** | `https://api-mdrmarket-production.up.railway.app/api` |
| **URL base (tu PC)** | `http://localhost:8001/api` (Chrome) · `http://10.0.2.2:8001/api` (emulador) |
| **Cabeceras** | `Accept: application/json` · `Content-Type: application/json` |
| **Sesión** | `Authorization: Bearer <token>`. La app ya lo agrega sola (`app/lib/core/network/api_client.dart`) |
| **Fechas** | En UTC, formato ISO 8601 |
| **Dinero** | Bolivianos (Bs), con 2 decimales, enviados como texto: `"185.00"` |

En la app, la URL se elige con `--dart-define=API_URL=...` (ver `app/lib/core/config/env.dart`).

### Formato de los errores

Siempre JSON y en español. La app los convierte en `ApiException`
(`app/lib/core/network/api_exception.dart`): `e.mensaje` para el mensaje general
y `e.errorDe('campo')` para mostrarlo debajo de cada campo.

| Código | Cuándo | Ejemplo |
|---|---|---|
| **422** | Datos inválidos o regla del negocio | `{"message":"El campo apellido es obligatorio.","errors":{"apellido":["El campo apellido es obligatorio."]}}` |
| **422** | Regla de la base (trigger) | `{"message":"Stock insuficiente"}` |
| **401** | Sin sesión o token vencido | `{"message":"Tu sesión expiró o no iniciaste sesión."}` |
| **403** | Cuenta desactivada o bloqueada | `{"message":"Tu cuenta está bloqueada por una sanción."}` |
| **500** | Error del servidor | `{"message":"Server Error"}` → **reportar como bug** |

---

## Parte 1 — Rutas que ya funcionan ✅

### `POST /auth/registro`
```json
{
  "nombre": "Lucía",
  "apellido": "Rojas",
  "email": "lucia@correo.com",
  "password": "Secreta123",
  "password_confirmation": "Secreta123",
  "ci_numero": "9876543",
  "ci_complemento": "1A",
  "ci_expedido": "SC",
  "telefono": "70012345",
  "dispositivo": "app-flutter"
}
```
- Obligatorios: `nombre`, `apellido`, `email`, `password`, `password_confirmation`, `ci_numero`.
- Contraseña: mínimo 8, con mayúscula, minúscula y número; las dos deben coincidir.
- `ci_expedido`: `SC`, `LP`, `CB`, `OR`, `PT`, `CH`, `TJ`, `BE`, `PD`.

**Respuesta 201** (igual a la del login):
```json
{
  "token": "12|aBcD...",
  "usuario": {
    "id": 11,
    "nombre": "Lucía",
    "apellido": "Rojas",
    "email": "lucia@correo.com",
    "telefono": "70012345",
    "ci_numero": "9876543",
    "ci_complemento": "1A",
    "ci_expedido": "SC",
    "foto_perfil_url": null,
    "rol_activo": "cliente",
    "es_admin": false,
    "vistas": ["cliente"],
    "puede_cambiar_vista": false,
    "roles": {
      "cliente": { "activo": true },
      "repartidor": null,
      "comerciante": null
    }
  }
}
```

### `POST /auth/login`
```json
{ "email": "lucia@correo.com", "password": "Secreta123", "dispositivo": "app-flutter" }
```
Respuesta **200** con `token` + `usuario` (mismo formato). Contraseña mala → **422**
`"Correo o contraseña incorrectos."`.

### `POST /auth/logout` 🔒
Respuesta **200** `{"message":"Sesión cerrada."}`. El token deja de servir.

### `GET /me` 🔒
Devuelve el objeto `usuario` (sin `token`). La app lo llama al abrirse para
saber si hay sesión.

**Campos que importan al frontend:**

| Campo | Para qué |
|---|---|
| `vistas` | Vistas que puede abrir: `cliente` siempre; `repartidor` y `comerciante` si los tiene |
| `puede_cambiar_vista` | `true` solo si tiene más de una vista → mostrar el botón ⇄ |
| `rol_activo` | Última vista elegida → en cuál abrir la app |
| `roles.repartidor.estado` | `pendiente`, `aprobado`, `rechazado`, `suspendido` → mostrar "Solicitud en revisión" si no está aprobado |
| `roles.*.sancionado` | Mostrar aviso si tiene una sanción vigente |

### `PUT /me/vista` 🔒
```json
{ "vista": "repartidor" }
```
Respuesta **200** con el `usuario` actualizado. Si no tiene esa vista → **422**
`"No tienes acceso a esa vista."`.

---

## Parte 2 — Datos para las pantallas pendientes ⏳

> Las **rutas** de esta parte son propuestas (ver [hoja de ruta](HOJA_DE_RUTA.md)).
> Los **campos** salen de la base real. Úsalos para maquetar con datos falsos;
> cuando la ruta exista, solo se cambia el repositorio de datos falso por el real.

### Catálogo (módulo 5)
`GET /productos?categoria=2&subcategoria=203&q=crema&ofertas=1` — cada producto
viene de la vista `v_catalogo_producto`. **Ejemplo real** de la base:
```json
{
  "id": 21,
  "nombre": "Crema Hidratante Facial 50 g",
  "descripcion": "Hidratación con ácido hialurónico. Para todo tipo de piel.",
  "precio": "28.00",
  "precio_final": "28.00",
  "en_oferta": false,
  "descuento_pct": 0,
  "stock": 45,
  "rating_promedio": null,
  "total_resenas": 0,
  "total_vendidos": 0,
  "imagen_url": "https://placehold.co/400x300/1b5e20/ffffff?text=Crema+Hidratante+Facial+50+g",
  "categoria_id": 203,
  "categoria": "Cosmética y cuidado de la piel",
  "categoria_icono": "💄",
  "categoria_principal_id": 2,
  "categoria_principal": "Salud y Belleza",
  "negocio_id": 4,
  "negocio": "FarmaSuper",
  "negocio_logo": "https://placehold.co/150/1b5e20/ffffff?text=Farma",
  "negocio_rating": null,
  "negocio_abierto": true,
  "negocio_latitud": "-17.7696000",
  "negocio_longitud": "-63.1658000"
}
```
- Si `en_oferta` es `true`: mostrar `precio` tachado, `precio_final` grande y la etiqueta `-{descuento_pct}%`.
- `rating_promedio: null` → "Sin reseñas todavía".
- `stock: null` → no se controla stock (ej. comida hecha al momento).

`GET /categorias` — árbol de dos niveles:
```json
[
  { "id": 2, "nombre": "Salud y Belleza", "icono": "💊",
    "subcategorias": [
      { "id": 201, "nombre": "Farmacia y medicamentos", "icono": "💊" },
      { "id": 203, "nombre": "Cosmética y cuidado de la piel", "icono": "💄" }
    ] }
]
```
Las 12 categorías y 49 subcategorías reales están en el script de la base
(ids de subcategoría = id del padre × 100 + n; ej. `201`).

### Pedido (módulos 6–8)
Estados y cómo mostrarlos:

| `estado` | Texto sugerido | Lo cambia |
|---|---|---|
| `pendiente` | Esperando al negocio | — |
| `confirmado` | El negocio aceptó tu pedido | Comerciante |
| `preparando` | Preparando tu pedido | Comerciante |
| `listo` | Listo, buscando repartidor | Comerciante |
| `en_camino` | Tu pedido va en camino 🛵 | Repartidor |
| `entregado` | Entregado ✅ | Repartidor (con PIN `codigo_entrega`) |
| `cancelado` / `rechazado` | Cancelado | Cliente / comerciante |

`GET /pedidos/{id}` — campos principales (tabla `pedido` + vista `v_pedido_resumen`):
```json
{
  "id": 100,
  "estado": "en_camino",
  "negocio": "TechStore SCZ",
  "repartidor": "Diego Rodríguez",
  "vehiculo": "Moto",
  "placa": "SCZ-1234",
  "direccion_entrega": "Av. El Trompillo 301",
  "latitud_entrega": "-17.8007823",
  "longitud_entrega": "-63.1886937",
  "anillo_entrega": 3,
  "subtotal": "384.50",
  "costo_envio": "5.00",
  "total": "389.50",
  "metodo_pago": "efectivo",
  "estado_pago": "pendiente",
  "codigo_entrega": "4821",
  "items": [
    { "producto_id": 1, "producto_nombre": "Auriculares Bluetooth Premium", "precio_unitario": "185.00", "cantidad": 2, "subtotal": "370.00" },
    { "producto_id": 2, "producto_nombre": "Cable USB-C a USB-A 2m", "precio_unitario": "14.50", "cantidad": 1, "subtotal": "14.50" }
  ],
  "created_at": "2026-10-03T20:15:00Z"
}
```
- `metodo_pago`: `efectivo`, `qr`, `transferencia`, `tarjeta`.
- `codigo_entrega` (PIN) solo lo ve el comprador; el repartidor lo pide al entregar.

**Cotizar envío** (`POST /envio/cotizar`) → `{ "costo_envio": "5.00", "distancia_km": 3.2, "anillo": 3 }`
o **422** "Fuera de cobertura" si la dirección está más allá del 10mo anillo.
Precios: hasta 3 km 3 Bs · 6 km 5 Bs · 10 km 8 Bs · 15 km 12 Bs · 20 km 15 Bs · 30 km 20 Bs.

### Rastreo en el mapa (módulo 9)
`GET /pedidos/{id}/seguimiento` — la app del cliente lo consulta cada 5–10 s:
```json
{
  "estado": "en_camino",
  "repartidor": { "nombre": "Diego Rodríguez", "vehiculo": "Moto", "placa": "SCZ-1234",
                  "latitud": "-17.7801200", "longitud": "-63.1902100",
                  "actualizado_en": "2026-10-03T20:31:05Z" },
  "negocio":  { "latitud": "-17.7745000", "longitud": "-63.1935000" },
  "destino":  { "latitud": "-17.8007823", "longitud": "-63.1886937" },
  "tiempo_estimado_min": 8
}
```
El repartidor envía su posición con `POST /repartidor/ubicacion`
`{ "pedido_id": 100, "latitud": -17.78012, "longitud": -63.19021 }`.

### Reseñas (módulo 10)
`PUT /resenas` (crea o edita la del usuario):
```json
{ "tipo": "repartidor", "repartidor_id": 5, "estrellas": 4, "comentario": "Muy amable" }
```
`tipo`: `producto` (con `producto_id`), `negocio` (`negocio_id`) o `repartidor` (`repartidor_id`).
Mostrar el promedio como "⭐ 4.0 (17 reseñas)" con `rating_promedio` y `total_resenas`.

### Ganancias del comerciante (módulo 11)
`GET /mi-negocio/reporte?desde=2026-10-01&hasta=2026-10-31&agrupar=dia` — una fila
por periodo (sale de `sp_reporte_negocio`):
```json
{ "periodo": "2026-10-03", "ventas": "384.50", "costo_de_lo_vendido": "240.00",
  "ganancia_bruta": "144.50", "compras": "1200.00", "gastos": "50.00",
  "comisiones": "0.00", "ganancia_neta": "94.50", "flujo_caja": "-865.50",
  "unidades_vendidas": 3 }
```

---

## Consejo para maquetar antes de que exista la API

En `app/lib/features/<feature>/data/` crea el repositorio con dos versiones: una
**falsa** que devuelve los JSON de este documento y la **real** que llama a la
API. Las pantallas usan el provider de Riverpod; cuando la ruta exista, solo se
cambia qué versión entrega el provider, sin tocar las pantallas.
