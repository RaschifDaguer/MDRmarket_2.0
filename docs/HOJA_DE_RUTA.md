# Hoja de ruta — MDR Market 2.0

Se trabaja **módulo por módulo**: cada uno se termina, se prueba con una prueba
simple que demuestre que cumple su función y recién entonces se pasa al
siguiente. La base de datos ya tiene casi todo lo necesario: la mayoría del
trabajo que falta es **API (Laravel) + pantallas (Flutter)**.

## Ya hecho

| # | Módulo | Qué incluye |
|---|---|---|
| 1 | Base de datos | 40 tablas, 6 vistas, 15 triggers, 10 funciones y procedimientos, evento de limpieza; subcategorías |
| 2 | API base | Registro, login, logout, `GET /me`, `PUT /me/vista`; errores en JSON y español |
| 3 | App base | Arranque, login, registro (2 contraseñas + requisitos en vivo), inicio por vista y cambio de vista |
| — | Publicación | API en Railway (despliegue automático) + base en Aiven |
| 4a | Registrar mi negocio | Formulario con rubro, mapa de Google + GPS, foto, NIT opcional y carnet (solo si falta); vista comerciante con estado "en revisión" y lista de lo que falta con botón **Subir**. API: `/categorias`, `/negocios`, `/documentos`, `/me/faltantes/{rol}`, `PUT /me` |

---

## Vista comerciante — se hace por partes

Toda la interfaz del comerciante, una parte a la vez, cada una con su prueba:

| Parte | Qué | Estado |
|---|---|---|
| 1 | Registrar mi negocio | ✅ |
| 2 | Mis productos (crear, editar, foto, precio, oferta, stock) | ⏳ siguiente |
| 3 | Compras y gastos | ⏳ |
| 4 | Ganancias (hoy, semana, mes, año; gráfico) | ⏳ |
| 5 | Pedidos entrantes (con datos de ejemplo hasta que exista el carrito) | ⏳ |
| 6 | Calificaciones del negocio | ⏳ |
| 7 | Perfil del negocio (editar datos, horario, abierto/cerrado) | ⏳ |

Las partes 2–7 cubren lo que abajo figura como módulos 7 y 11, y la parte de
reseñas del negocio del módulo 10.

---

## Pendiente

### Módulo 4b — Registro de repartidor ⏳
**Objetivo:** que un cliente se convierta en repartidor pidiendo solo lo que le falta.

- **Pantallas:** "Quiero ser repartidor" (tipo de vehículo, placa, RUAT, fotos).
  La lista "Te falta subir…" y la hoja para subir documentos ya existen
  (`features/perfil/`): se reutilizan.
- **API:** `GET /api/tipos-vehiculo`, `POST /api/repartidor`, `POST /api/vehiculos`.
  `GET /api/me/faltantes/repartidor` y `POST /api/documentos` ya funcionan.
- **Base (ya existe):** `repartidor`, `vehiculo`, `requisito_rol`, `sp_datos_faltantes`, `trg_documento_bi`.
- **Cómo probarlo:** un cliente se registra como repartidor en moto → la lista de
  faltantes muestra placa, RUAT y fotos → al subirlas la lista queda vacía y
  aparece el botón "cambiar vista" con estado "en revisión". Con bicicleta solo
  pide CI y foto del vehículo.

### Módulo 5 — Catálogo ⏳
- **Pantallas:** inicio del cliente con categorías (ícono + nombre),
  subcategorías, lista de productos, búsqueda, detalle del producto (fotos,
  precio, oferta, negocio, estrellas) y página del negocio.
- **API:** `GET /api/categorias` (con subcategorías), `GET /api/productos`
  (filtros: categoría, subcategoría, negocio, texto, solo ofertas),
  `GET /api/productos/{id}`, `GET /api/negocios/{id}`.
- **Base:** `v_catalogo_producto` (ya calcula precio final, descuento y excluye sancionados), índice FULLTEXT en `producto`.
- **Cómo probarlo:** filtrar "Salud y Belleza" muestra los 7 productos de
  FarmaSuper; "Farmacia y medicamentos" muestra 3; buscar "salteña" encuentra 2.

### Módulo 6 — Carrito, pedido y envío ⏳
- **Pantallas:** carrito (por negocio), elegir/guardar dirección en el mapa,
  resumen con costo de envío, método de pago (efectivo / QR), confirmación.
- **API:** `GET/POST /api/direcciones`, `POST /api/envio/cotizar`,
  `POST /api/pedidos`, `GET /api/pedidos`, `GET /api/pedidos/{id}`,
  `POST /api/pedidos/{id}/cancelar`.
- **Base:** `fn_cotizar_envio` (precio + cobertura hasta el 10mo anillo),
  triggers de stock (`trg_pedido_item_bi`) y cancelación (`trg_pedido_au`).
- **Distancia real:** la API pide los km por calle a **Google Directions**
  (clave en `.env`: `GOOGLE_MAPS_KEY`) y se los pasa a `fn_cotizar_envio`.
- **Cómo probarlo:** pedido de 2 auriculares → el stock baja 2; pedir más del
  stock → "Stock insuficiente"; dirección fuera del 10mo anillo → "fuera de
  cobertura"; cancelar → el stock vuelve.

### Módulo 7 — Vista comerciante ⏳
- **Pantallas:** mis productos (crear, editar, oferta, foto, stock), pedidos
  entrantes (aceptar / rechazar / preparando / listo), registrar compras y gastos.
- **API:** CRUD `/api/mi-negocio/productos`, `GET /api/mi-negocio/pedidos`,
  `PUT /api/pedidos/{id}/estado`, `POST /api/mi-negocio/registro` (compras y gastos).
- **Base:** `pedido_estado_historial`, `registro_comercio`, `trg_registro_ai`.
- **Cómo probarlo:** el comerciante marca un pedido como "listo" → aparece en
  la lista del repartidor (módulo 8); registrar una compra suma stock.

### Módulo 8 — Vista repartidor ⏳
- **Pantallas:** "en línea / desconectado", pedidos disponibles cerca (filtrados
  por la categoría de su vehículo), aceptar, "recogido", "entregado" con PIN.
- **API:** `PUT /api/repartidor/disponible`, `GET /api/repartidor/pedidos-disponibles`,
  `POST /api/pedidos/{id}/aceptar`, `PUT /api/pedidos/{id}/estado`.
- **Base:** `pedido.categoria_vehiculo_requerida_id`, `codigo_entrega`,
  `trg_pedido_bu` (no asigna a sancionados), `trg_pedido_au` (al entregar
  registra la venta y suma entregas).
- **Cómo probarlo:** pedido "listo" → el repartidor lo acepta → "en camino" →
  "entregado" con el PIN correcto → en `registro_comercio` aparece la venta.

### Módulo 9 — Rastreo del pedido en el mapa ⏳
**Objetivo:** que el cliente vea al repartidor moverse en el mapa hasta su casa.

- **App repartidor:** mientras tiene un pedido "en camino", envía su GPS cada
  5–10 s (`geolocator`).
- **App cliente:** pantalla con `google_maps_flutter`: marcador del negocio, de
  la casa y del repartidor, que se actualiza cada 5–10 s; ruta dibujada con
  Google Directions; tiempo estimado.
- **API:** `POST /api/repartidor/ubicacion` (guarda en `ubicacion_repartidor` y
  actualiza `repartidor.latitud_actual/longitud_actual`),
  `GET /api/pedidos/{id}/seguimiento` (última posición + estado).
- **Base:** `ubicacion_repartidor` (+ evento que limpia lo viejo), `v_pedido_resumen`.
- **Primera versión:** consultar cada pocos segundos (*polling*). Tiempo real con
  WebSockets queda para después.
- **Cómo probarlo (pruebas del rastreo):**
  1. **Emulador:** en el emulador del repartidor, *Extended controls → Location
     → Routes*, cargar una ruta y reproducirla → el marcador del cliente se mueve.
  2. **Script:** enviar 10 posiciones seguidas con `curl` a
     `POST /api/repartidor/ubicacion` → `GET /seguimiento` devuelve la última.
  3. **Prueba automática (Laravel):** crear un pedido "en camino", enviar 3
     posiciones y comprobar que `/seguimiento` devuelve la tercera y que otro
     cliente **no** puede ver ese pedido (403).
  4. **Real:** dos celulares, uno como repartidor caminando una cuadra.

### Módulo 10 — Reseñas, reportes y sanciones en la app ⏳
- **Pantallas:** después de recibir: calificar repartidor, negocio y productos
  (editar si ya calificó); botón "Reportar" con motivos; promedio "⭐ 4.0 (17)".
- **API:** `PUT /api/resenas` (crea o edita, usa `updateOrCreate`),
  `GET /api/{producto|negocio|repartidor}/{id}/resenas`, `POST /api/reportes`,
  `GET /api/motivos-reporte`.
- **Base:** todos los controles ya están en triggers.
- **Cómo probarlo:** reseñar antes de recibir → rechazado; reseñar dos veces →
  edita la misma; el promedio cambia solo.

### Módulo 11 — Ganancias del comerciante ⏳
- **Pantallas:** resumen de hoy, semana, mes y año; gráfico por día; tabla por
  producto (gasto vs. ganancia); filtro por fechas.
- **API:** `GET /api/mi-negocio/reporte?desde&hasta&agrupar=dia|semana|mes|anio`,
  `GET /api/mi-negocio/reporte-productos`.
- **Base:** `sp_reporte_negocio`, `sp_reporte_productos`, `v_registro_diario`.
- **Paquete Flutter sugerido:** `fl_chart`.

### Módulo 12 — Panel de administrador (web) ⏳
- **Herramienta:** **Filament** dentro de la misma API (`composer require filament/filament`).
  Entra solo quien tenga `usuario.es_admin = 1`.
- **Secciones:** aprobar/rechazar repartidores, vehículos, negocios y
  documentos; reportes pendientes (`v_reportes_pendientes`); aplicar y levantar
  sanciones; tarifas de envío y configuración.

### Módulo 13 — Cierre ⏳
- **Recuperar contraseña** por correo (tabla `password_reset_tokens` ya existe;
  falta proveedor de correo: Mailpit en local, Resend o Brevo gratis en producción).
- **Notificaciones push** (nuevo pedido, pedido en camino…). Requieren Firebase
  Cloud Messaging; mientras tanto, la tabla `notificacion` + consulta periódica.
- **Publicación:** APK firmado (`flutter build apk --release`), Google Play
  (25 USD una vez), iOS (necesita Mac + 99 USD al año).

---

## Pendientes técnicos

- [x] Almacenamiento de imágenes: **disco local por ahora** (`MEDIA_DISK=public`).
- [ ] **Pasar las fotos públicas a Cloudinary antes de publicar** (el disco de
  Railway se borra en cada despliegue). Solo cambia `MEDIA_DISK` y la clase
  `api/app/Support/Archivos.php`; la app no se toca. Los documentos privados
  (carnet, licencia) necesitan un disco privado que no se borre.
- [x] Clave de Google Maps en la app: archivo local `app/dart_defines.local.json` (no se sube).
- [ ] Restringir la clave de Google Maps en Google Cloud (por dominio web y por paquete `bo.mdrmarket.app`).
- [ ] Configurar la clave de Google Maps para Android/iOS (al compilar para celular).
- [ ] Clave de Google Maps en el `.env` de la API para Google Directions (módulo 6).
- [ ] Pruebas automáticas de la API (`php artisan test`) por cada módulo.
- [ ] Integración continua en GitHub Actions: `flutter analyze` + `flutter test` + pruebas de la API en cada PR.
- [ ] Limitar CORS al dominio real cuando exista versión web publicada.
- [ ] Quitar `android:usesCleartextTraffic="true"` del `AndroidManifest.xml` cuando la app use solo HTTPS.
- [ ] Cambiar `APP_KEY` de Railway si alguna vez se expone (cierra todas las sesiones).
- [ ] Si el proyecto crece: plan pago en Railway/Aiven para que no se duerman.
