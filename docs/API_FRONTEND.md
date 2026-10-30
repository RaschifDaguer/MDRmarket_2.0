# API para el frontend

Qué manda y qué recibe la app en cada pantalla. Sirve para maquetar con
**datos de prueba** las pantallas cuya ruta de la API todavía no existe, sin
trabajar a ciegas.

- **Parte 1:** cuenta, perfil, registro del negocio y del repartidor.
- **Parte 2:** catálogo, pedidos y todo lo del comerciante (también funcionan).
- **Parte 3:** lo que todavía **falta** (vista repartidor y rastreo): datos
  propuestos para maquetar.

> **Referencia completa y siempre al día:** `/docs/api` en la API (la genera
> Scramble leyendo el código). Este documento explica *cómo usarla* desde la app.

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

### `PUT /me` 🔒
Completa datos personales; solo se mandan los campos que cambian
(`nombre`, `apellido`, `telefono`, `ci_numero`, `ci_complemento`, `ci_expedido`).
```json
{ "apellido": "Suárez", "ci_numero": "7654321" }
```
Respuesta **200** con el `usuario` actualizado. CI repetido → **422** en `ci_numero`.

### `GET /me/faltantes/{rol}` 🔒
`rol`: `repartidor` o `comerciante`. Sale de `sp_datos_faltantes`. Lista vacía = completo.
```json
{
  "rol": "comerciante",
  "completo": false,
  "faltantes": [
    { "codigo": "negocio", "tipo": "dato", "documento": null,
      "texto": "Registrar tu negocio", "negocio_id": null, "vehiculo_id": null },
    { "codigo": "documento.ci_anverso", "tipo": "documento", "documento": "ci_anverso",
      "texto": "Foto: Carnet de identidad (anverso)", "negocio_id": null, "vehiculo_id": null }
  ]
}
```
- `tipo: "documento"` → mostrar botón **Subir** (`POST /documentos` con `tipo` = `documento`).
- `codigo: "apellido"` o `"ci_numero"` → pedir el dato y guardarlo con `PUT /me`.

### `GET /categorias`
Rubros principales con sus subcategorías (no pide sesión):
```json
[
  { "id": 2, "nombre": "Salud y Belleza", "icono": "💊",
    "subcategorias": [
      { "id": 201, "nombre": "Farmacia y medicamentos", "icono": "💊" },
      { "id": 203, "nombre": "Cosmética y cuidado de la piel", "icono": "💄" }
    ] }
]
```
Son 12 principales y 49 subcategorías (id de subcategoría = id del padre × 100 + n).

### `POST /negocios` 🔒 — Registrar mi negocio
Se manda como **`multipart/form-data`** (lleva la foto):

| Campo | | Notas |
|---|---|---|
| `nombre` | obligatorio | máx. 150 |
| `categoria_id` | obligatorio | una categoría **principal** (no subcategoría) |
| `direccion` | obligatorio | |
| `latitud`, `longitud` | obligatorios | del mapa o del GPS; deben estar del centro al 10mo anillo |
| `foto` | obligatorio | jpg, png o webp, hasta 5 MB |
| `descripcion`, `telefono`, `referencia`, `nit`, `razon_social` | opcionales | `nit` no se puede repetir |

Respuesta **201** (el mismo formato que `GET /negocios`):
```json
{
  "id": 5,
  "nombre": "Tienda Marta",
  "descripcion": null,
  "categoria": { "id": 1, "nombre": "Alimentos y Bebidas", "icono": "🍔" },
  "telefono": "70012345",
  "nit": null,
  "razon_social": null,
  "direccion": "Av. Busch 1234",
  "referencia": null,
  "latitud": -17.78373,
  "longitud": -63.18214,
  "logo_url": "http://localhost:8001/api/archivos/negocios/abc123.png",
  "abierto": true,
  "estado_verificacion": "pendiente",
  "rating_promedio": null,
  "total_resenas": 0,
  "created_at": "2026-10-09T15:35:58.000000Z"
}
```
- Fuera de cobertura → **422** en `latitud`: *"La ubicación está fuera de la zona de cobertura (del centro al 10mo anillo)."*
- Al crearlo, el usuario ya tiene la vista `comerciante` (`GET /me`).
- `estado_verificacion`: `pendiente` (En revisión), `aprobado` (Activo), `rechazado`, `suspendido`. Lo cambia un administrador.

### `GET /negocios` 🔒
Lista de mis negocios (más reciente primero), con el formato de arriba.

### `POST /documentos` 🔒
**`multipart/form-data`**: `tipo` (ej. `ci_anverso`, `ci_reverso`, `foto_rostro`, `licencia_conducir`),
`archivo` (jpg, png, webp o pdf, hasta 5 MB) y, si corresponde, `negocio_id` o `vehiculo_id`.
Si ya había uno **pendiente** del mismo tipo, lo reemplaza. Respuesta **201**:
```json
{ "id": 1, "tipo": "ci_anverso", "nombre": "Carnet de identidad (anverso)",
  "estado": "pendiente", "observacion": null, "negocio_id": null, "vehiculo_id": null,
  "created_at": "2026-10-09T15:36:01.000000Z" }
```
Los documentos son **privados**: no tienen URL pública.

`foto_rostro` es una **selfie** que se pide a repartidores y comerciantes: el
administrador la compara con la foto del carnet. La app la toma con la cámara
delantera (`SelectorFoto(selfie: true)`), no desde la galería. En el panel, el
carnet (los dos lados) y la selfie de una persona se revisan como una sola solicitud.

### `GET /documentos` 🔒
Mis documentos con su `estado` (`pendiente`, `aprobado`, `rechazado`) y `observacion`.

### `GET /archivos/{ruta}`
Devuelve una foto pública (logo del negocio, productos). No hace falta armar
esta URL: la API ya la manda completa en `logo_url`.

### Registro de repartidor 🔒 (módulo 4b)

Orden en la app: `GET /tipos-vehiculo` → `POST /repartidor` → `POST /vehiculos`
→ `GET /me/faltantes/repartidor` → subir cada foto con `POST /documentos`.

#### `GET /tipos-vehiculo` 🔒
Para elegir el vehículo y saber qué campos mostrar:
```json
[
  { "id": 1, "codigo": "moto", "nombre": "Moto",
    "requiere_placa": true, "requiere_ruat": true, "requiere_licencia": true,
    "categoria": { "id": 1, "codigo": "liviano", "nombre": "Liviano",
                   "descripcion": "Motos y bicicletas: paquetes chicos y comida", "capacidad_kg_max": 20 } },
  { "id": 2, "codigo": "bicicleta", "nombre": "Bicicleta",
    "requiere_placa": false, "requiere_ruat": false, "requiere_licencia": false,
    "categoria": { "id": 1, "codigo": "liviano", "…": "…" } }
]
```
Son 5: moto y bicicleta (liviano), auto y camioneta (mediano), camión (grande).
Si `requiere_placa` o `requiere_ruat` es `false`, no mostrar esos campos.

#### `POST /repartidor` 🔒
Sin datos. Crea el perfil de repartidor **en revisión**. Respuesta **201**:
```json
{ "usuario_id": 11, "estado_verificacion": "pendiente", "disponible": false,
  "rating_promedio": null, "total_entregas": 0, "vehiculos": [],
  "created_at": "2026-10-30T15:00:00.000000Z" }
```
- Desde ese momento `GET /me` trae la vista `repartidor` y `roles.repartidor.estado: "pendiente"`.
- **Si lo habían rechazado**, sirve para **volver a enviar** la solicitud: responde **200**
  y él y su vehículo quedan otra vez `pendiente`. Los documentos rechazados vuelven a
  aparecer en los faltantes para subirlos de nuevo.
- Si está pendiente, aprobado o suspendido → **422** `{"message":"Ya estás registrado como repartidor."}`.

#### `GET /repartidor` 🔒
Mi perfil (mismo formato que arriba) con el vehículo y, si lo rechazaron, el motivo:
```json
{ "usuario_id": 11, "estado_verificacion": "rechazado", "motivo_rechazo": "La placa no coincide con la foto",
  "vehiculos": [ { "id": 4, "tipo": { "codigo": "moto", "…": "…" }, "placa": "4321-XYZ", "estado_verificacion": "rechazado", "…": "…" } ],
  "…": "…" }
```
`motivo_rechazo` es `null` si no está rechazado. Si todavía no es repartidor → **404**
*"Todavía no te registraste como repartidor."*

#### `POST /vehiculos` 🔒
JSON (no lleva fotos; las fotos van después con `POST /documentos`):
```json
{ "tipo_vehiculo_id": 1, "placa": "4321-XYZ", "ruat": "R-778899",
  "marca": "Honda", "modelo": "XR150", "color": "Rojo", "anio": 2022 }
```
- Obligatorio: `tipo_vehiculo_id`. `placa` y `ruat` solo si el tipo los pide (la bicicleta no).
- El resto es opcional. `anio` entre 1950 y el año que viene.
- La placa se guarda en mayúsculas y **no se puede repetir** → **422** en `placa`: *"Esa placa ya está registrada."*
- Sin placa o RUAT cuando el tipo los pide → **422** en `placa` / `ruat`.
- Si todavía no hizo `POST /repartidor` → **422** `{"message":"Primero regístrate como repartidor."}`.
- **Por ahora, un solo vehículo en uso:** si ya tiene uno → **422** `{"message":"Ya tienes un vehículo registrado."}`.
- El vehículo siempre queda a nombre de quien tiene la sesión.

Respuesta **201**:
```json
{ "id": 4, "tipo": { "id": 1, "codigo": "moto", "nombre": "Moto" },
  "placa": "4321-XYZ", "ruat": "R-778899", "marca": "Honda", "modelo": "XR150",
  "color": "Rojo", "anio": 2022, "en_uso": true, "estado_verificacion": "pendiente",
  "created_at": "2026-10-30T15:01:00.000000Z" }
```

#### Lo que falta subir
Después del vehículo, `GET /me/faltantes/repartidor` pide las fotos. Con moto:

| `codigo` | `documento` | `vehiculo_id` |
|---|---|---|
| `documento.ci_anverso`, `documento.ci_reverso` | `ci_anverso`, `ci_reverso` | `null` |
| `documento.foto_rostro` (selfie) | `foto_rostro` | `null` |
| `documento.licencia_conducir` | `licencia_conducir` | `null` |
| `documento.foto_vehiculo:vehiculo4` | `foto_vehiculo` | `4` |
| `documento.foto_placa:vehiculo4` | `foto_placa` | `4` |
| `documento.ruat:vehiculo4` | `ruat` | `4` |

Con bicicleta solo: carnet (los dos lados), selfie y `foto_vehiculo`.

Para cada uno: `POST /documentos` con `tipo` = `documento` y, si no es `null`,
el mismo `vehiculo_id`. Al subir todo, `completo: true`. Con el `vehiculo_id`
de otra persona → **422** *"Este documento debe ir ligado a un vehículo tuyo"*.

Un administrador aprueba o rechaza (con motivo) al repartidor y su vehículo en
`/admin` → Aprobaciones → Repartidores; se le deja un aviso (`repartidor_aprobado`
o `repartidor_rechazado`). Si lo rechazan, la vista `repartidor` desaparece de `vistas`
(`roles.repartidor.estado` sigue diciendo `rechazado`): la app lo invita a ver el
motivo (`GET /repartidor`) y volver a enviar (`POST /repartidor`).

---

## Parte 2 — Catálogo, pedidos y comerciante ✅

### Catálogo (no pide sesión)

`GET /productos?categoria=2&subcategoria=203&negocio=4&q=crema&ofertas=1&orden=precio&page=1`
— todos los filtros son opcionales. `orden`: `populares` (por defecto), `recientes`,
`precio`, `precio_desc`, `rating`. Viene de a 20, con `data` y `meta`
(`current_page`, `last_page`). Solo muestra negocios **aprobados** y sin sanción.

```json
{
  "data": [{
    "id": 21,
    "nombre": "Crema Hidratante Facial 50 g",
    "descripcion": "Hidratación con ácido hialurónico.",
    "precio": "28.00",
    "precio_final": "22.40",
    "en_oferta": true,
    "descuento_pct": 20,
    "stock": 45,
    "rating_promedio": 4.5,
    "total_resenas": 2,
    "total_vendidos": 7,
    "imagen_url": "https://…",
    "categoria": { "id": 203, "nombre": "Cosmética y cuidado de la piel", "icono": "💄" },
    "categoria_principal": { "id": 2, "nombre": "Salud y Belleza" },
    "negocio": { "id": 4, "nombre": "FarmaSuper", "logo_url": "https://…", "rating_promedio": null, "abierto": true }
  }],
  "meta": { "current_page": 1, "last_page": 2 }
}
```
- Con `en_oferta: true`: `precio` tachado, `precio_final` grande y la etiqueta `-{descuento_pct}%`.
- `stock: null` = sin control de stock (siempre disponible). `stock: 0` = agotado.
- `rating_promedio: null` = todavía sin reseñas ("Nuevo").

`GET /productos/{id}` — lo mismo más `imagenes` (lista de URLs), `resenas`
(las últimas 20) y en `negocio`: `pedido_minimo` y `tiempo_preparacion_min`.
404 si ya no está disponible.

`GET /tiendas?categoria=1&q=pollo` — negocios aprobados (abiertos primero), de a 20.
`GET /tiendas/{id}` — datos del negocio, `horarios`, `productos` y `resenas`.

Reseña (en `resenas` de producto o tienda):
```json
{ "id": 9, "tipo": "negocio", "estrellas": 5, "comentario": "¡Muy rico!", "autor": "Lucía R.",
  "respuesta": "¡Gracias!", "respondido_en": "…", "created_at": "…", "updated_at": "…" }
```

### Direcciones del cliente 🔒

`GET /direcciones` (la predeterminada primero) · `POST /direcciones` ·
`PUT /direcciones/{id}` · `DELETE /direcciones/{id}`

```json
{ "etiqueta": "Casa", "direccion": "Calle Libertad 123", "referencia": "Portón negro",
  "latitud": -17.7895, "longitud": -63.1803, "predeterminada": true }
```
La primera que se guarda queda como predeterminada. Fuera del 10mo anillo → **422** en `latitud`.

### Envío 🔒

`POST /envio/cotizar` `{ "negocio_id": 4, "latitud": -17.7895, "longitud": -63.1803, "productos": [21, 22] }`
```json
{ "costo_envio": "5.00", "distancia_km": 3.2, "anillo": 3, "tarifa_servicio": "0.00" }
```
Fuera de cobertura → **422** en `latitud`. Tarifas: hasta 3 km 3 Bs · 6 km 5 Bs ·
10 km 8 Bs · 15 km 12 Bs · 20 km 15 Bs · 30 km 20 Bs (editables en `/admin`).

### Pedidos del cliente 🔒

`POST /pedidos` — a **un** negocio:
```json
{
  "negocio_id": 4,
  "direccion_id": 7,
  "metodo_pago": "efectivo",
  "notas": "Tocar el timbre",
  "items": [ { "producto_id": 21, "cantidad": 2, "notas": "sin cebolla" } ]
}
```
- En vez de `direccion_id` se puede mandar `direccion`, `referencia`, `latitud` y `longitud`.
- `metodo_pago`: `efectivo`, `qr` o `transferencia`.
- El precio de cada producto lo pone la API (con la oferta vigente).
- **422** con el motivo: negocio cerrado o no disponible, producto agotado
  ("Solo quedan 2 de «…»" en `items.0.cantidad`), pedido mínimo (`items`),
  fuera de cobertura (`latitud`), pedir a tu propio negocio (`negocio_id`).

Respuesta **201** (igual que `GET /pedidos/{id}`):
```json
{
  "id": 42,
  "estado": "pendiente",
  "negocio": { "id": 4, "nombre": "FarmaSuper", "logo_url": "…", "telefono": "…", "direccion": "…", "latitud": -17.76, "longitud": -63.16 },
  "direccion_entrega": "Calle Libertad 123",
  "referencia_entrega": "Portón negro",
  "latitud_entrega": -17.7895, "longitud_entrega": -63.1803,
  "notas": "Tocar el timbre",
  "subtotal": "44.80", "costo_envio": "5.00", "tarifa_servicio": "0.00", "descuento": "0.00", "total": "49.80",
  "metodo_pago": "efectivo", "estado_pago": "pendiente",
  "codigo_entrega": "4821",
  "distancia_km": 3.2,
  "motivo_cancelacion": null,
  "items": [ { "id": 1, "producto_id": 21, "nombre": "Crema…", "imagen_url": "…", "precio_unitario": "22.40", "cantidad": 2, "subtotal": "44.80", "notas": "sin cebolla" } ],
  "historial": [ { "estado": "pendiente", "motivo": null, "fecha": "2026-10-09T16:30:00.000000Z" } ],
  "acciones": ["cancelado"],
  "created_at": "…", "confirmado_en": null, "entregado_en": null, "cancelado_en": null
}
```
- `codigo_entrega` (**PIN**) solo lo recibe el comprador; el negocio lo pide al entregar.
- `acciones` = a qué estados puede pasarlo quien pregunta (para mostrar los botones).
- Cuando está `entregado`, el comprador recibe además `mis_resenas`:
  `{ "negocio": {"estrellas": 4, …} | null, "productos": [ {"producto_id": 21, "estrellas": 5, …} ] }`.
- El negocio no recibe el PIN, pero sí `cliente: { "nombre", "telefono" }`.

`GET /pedidos` — mis pedidos (de a 20, con `total_items`).
`POST /pedidos/{id}/cancelar` `{ "motivo": "…" }` — solo mientras está `pendiente`.

| `estado` | Texto en la app | Lo cambia |
|---|---|---|
| `pendiente` | Esperando al negocio | — |
| `confirmado` | Aceptado | Comerciante |
| `preparando` | Preparando | Comerciante |
| `listo` | Listo | Comerciante |
| `en_camino` | En camino | Comerciante (después, el repartidor) |
| `entregado` | Entregado | Comerciante con el PIN (después, el repartidor) |
| `cancelado` / `rechazado` | Cancelado / Rechazado | Cliente (pendiente), comerciante (con motivo), admin |

### Reseñas 🔒

`PUT /resenas` — crea o edita la del usuario (una por producto o negocio):
```json
{ "tipo": "negocio", "negocio_id": 4, "estrellas": 4, "comentario": "Muy amable" }
{ "tipo": "producto", "producto_id": 21, "estrellas": 5 }
```
Antes de recibir un pedido → **422** "Solo puedes reseñar después de recibir un pedido".

### Comerciante: `/negocios/{negocio}/…` 🔒 (solo el dueño; a otro le responde 404)

| Ruta | Para qué |
|---|---|
| `POST /negocios/{id}` | Editar perfil (multipart; `foto` opcional). Campos de `POST /negocios` + `tiempo_preparacion_min`, `pedido_minimo` |
| `PATCH …/abierto` `{abierto}` | Abrir o cerrar ahora (cerrado no recibe pedidos) |
| `PUT …/horario` | `{"horarios": [{"dia_semana": 1, "hora_apertura": "08:00", "hora_cierre": "20:00"}]}` (1 = lunes) |
| `GET …/resumen` | Pedidos nuevos y en curso, montos de hoy y del mes, productos activos y sin stock |
| `GET …/productos` | Mis productos (también los ocultos), con `costo`, `stock`, `disponible`, `categoria_vehiculo_id` |
| `POST …/productos` | Nuevo (multipart): `nombre`, `categoria_id` (**subcategoría**), `precio`, `costo`, `precio_oferta`, `oferta_fin`, `controlar_stock` (1/0), `stock`, `disponible` (1/0), `categoria_vehiculo_id` (1 moto · 2 auto · 3 camión), `foto` |
| `POST …/productos/{p}` | Editar (multipart, mismos campos) |
| `PATCH …/productos/{p}/disponible` | Mostrar u ocultar |
| `DELETE …/productos/{p}` | Eliminar |
| `GET …/pedidos?grupo=nuevos\|en_curso\|terminados` | Pedidos que llegan |
| `PUT …/pedidos/{p}/estado` | `{"estado": "confirmado"}` · rechazar/cancelar con `motivo` · `{"estado": "entregado", "codigo": "4821"}` |
| `GET/POST …/registros`, `DELETE …/registros/{r}` | Compras (`producto_id`, `cantidad`, `costo_unitario`, `proveedor`) y gastos (`descripcion`, `monto`); `fecha` opcional |
| `GET …/reporte?desde&hasta&agrupar=dia\|semana\|mes\|anio` | `totales` y `periodos` (ventas, costo, ganancia bruta, compras, gastos, comisiones, ganancia neta, flujo de caja) |
| `GET …/reporte-productos?desde&hasta` | Por producto: vendidas, ventas, ganancia, margen |
| `GET …/resenas` · `PUT …/resenas/{r}/respuesta` | Reseñas del negocio y sus productos, con el resumen por estrellas; responder |

Fechas de los filtros: `AAAA-MM-DD` en hora de Bolivia.

---

## Parte 3 — Lo que falta (repartidor y rastreo) ⏳

> Rutas **propuestas**: los campos salen de la base real. Sirven para maquetar
> con datos falsos; se confirman al construir cada módulo.

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

### Reseñas del repartidor (módulo 10)
`PUT /resenas` con `{ "tipo": "repartidor", "repartidor_id": 5, "estrellas": 4 }`
(la base ya lo acepta; falta habilitarlo en la API cuando exista el repartidor).

---

## Consejo para maquetar antes de que exista la API

En `app/lib/features/<feature>/data/` crea el repositorio con dos versiones: una
**falsa** que devuelve los JSON de este documento y la **real** que llama a la
API. Las pantallas usan el provider de Riverpod; cuando la ruta exista, solo se
cambia qué versión entrega el provider, sin tocar las pantallas.
