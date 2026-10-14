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
| 4a | Registrar mi negocio | Rubro, mapa de Google + GPS, foto, NIT opcional, carnet (solo si falta); queda "en revisión" |
| 5 | Catálogo | Buscador, categorías, ofertas, orden, detalle de producto (fotos, reseñas) y página de cada tienda (horario, productos, reseñas) |
| 6 | Carrito y pedido | Carrito de un negocio con notas, direcciones guardadas (mapa/GPS), costo de envío por km, efectivo/QR/transferencia, pedido con **PIN de entrega**, cancelar mientras está pendiente, seguimiento del estado |
| 7 | Vista comerciante | Resumen, abierto/cerrado, productos (foto, oferta, stock, tamaño), pedidos entrantes (aceptar → … → entregar con PIN), compras y gastos, perfil y horario |
| 10a | Reseñas | Cliente califica negocio y productos (una por cada uno, editable) después de recibir; el negocio responde |
| 11 | Ganancias | Por período (hoy, 7 días, mes, año) con gráfico y por producto |
| 12 | Panel de administrador | Filament en `/admin`: aprobar/rechazar negocios y documentos (fotos privadas), pedidos (cancelar), usuarios (activar, dar admin), tarifas de envío y comisiones |
| — | Documentación de la API | Scramble en `/docs/api`, generada desde el código |

**Entrega mientras no exista el repartidor:** el negocio entrega con su propio
delivery: pasa el pedido a "en camino" y lo marca "entregado" con el PIN que le
da el cliente. Así funcionan ya las ventas, las ganancias y las reseñas.

**Pruebas:** 23 de la API (`php artisan test`, base `mdrmarket_prueba`) y 69 de
la app con datos falsos, más recorridos en vivo contra la API local.

---

## Pendiente

### Módulo 4b — Registro de repartidor ⏳ *siguiente*
**Objetivo:** que un cliente se convierta en repartidor pidiendo solo lo que le falta.

- **Pantallas:** "Quiero ser repartidor" (tipo de vehículo, placa, RUAT, fotos).
  La lista "Te falta subir…" y la hoja para subir documentos ya existen
  (`features/perfil/`): se reutilizan.
- **API:** `GET /api/tipos-vehiculo`, `POST /api/repartidor`, `POST /api/vehiculos`.
  `GET /api/me/faltantes/repartidor` y `POST /api/documentos` ya funcionan.
- **Panel:** sección para aprobar repartidores y vehículos (como la de negocios).
- **Base (ya existe):** `repartidor`, `vehiculo`, `requisito_rol`, `sp_datos_faltantes`, `trg_documento_bi`.
- **Cómo probarlo:** un cliente se registra como repartidor en moto → la lista de
  faltantes muestra placa, RUAT y fotos → al subirlas la lista queda vacía y
  aparece el botón "cambiar vista" con estado "en revisión". Con bicicleta solo
  pide CI y foto del vehículo.

### Módulo 8 — Vista repartidor ⏳
- **Pantallas:** "en línea / desconectado", pedidos "listos" cerca (filtrados
  por la categoría de su vehículo), aceptar, "recogido", "entregado" con PIN.
- **API:** `PUT /api/repartidor/disponible`, `GET /api/repartidor/pedidos-disponibles`,
  `POST /api/pedidos/{id}/aceptar`, `PUT /api/pedidos/{id}/estado`.
- **Código:** agregar el rol `repartidor` en `api/app/Support/FlujoPedido.php`
  (`listo → en_camino → entregado`). La entrega propia del negocio puede quedar
  como opción para negocios con su delivery.
- **Base:** `pedido.categoria_vehiculo_requerida_id` (ya se llena al pedir),
  `codigo_entrega`, `trg_pedido_bu` (no asigna a sancionados), `trg_pedido_au`.
- **Cómo probarlo:** pedido "listo" → el repartidor lo acepta → "en camino" →
  "entregado" con el PIN correcto → en `registro_comercio` aparece la venta.

### Módulo 9 — Rastreo del pedido en el mapa ⏳
**Objetivo:** que el cliente vea al repartidor moverse en el mapa hasta su casa.

- **App repartidor:** mientras tiene un pedido "en camino", envía su GPS cada
  5–10 s (`geolocator`).
- **App cliente:** en el detalle del pedido, un mapa con el negocio, la casa y el
  repartidor, que se actualiza cada 5–10 s; ruta con Google Directions; tiempo estimado.
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
     cliente **no** puede ver ese pedido.
  4. **Real:** dos celulares, uno como repartidor caminando una cuadra.

### Módulo 10b — Reportes, sanciones y reseña del repartidor ⏳
- **App:** botón "Reportar" (producto, negocio, repartidor) con motivos; calificar
  al repartidor después de recibir.
- **API:** `GET /api/motivos-reporte`, `POST /api/reportes`; habilitar `tipo: repartidor` en `PUT /api/resenas`.
- **Panel:** reportes pendientes (`v_reportes_pendientes`), aplicar y levantar sanciones.
- **Base:** todos los controles ya están en triggers.

### Módulo 13 — Cierre ⏳
- **Avisos en la app:** la tabla `notificacion` ya se llena (pedido nuevo,
  aceptado, en camino, negocio aprobado, documento rechazado…). Falta la
  pantalla de avisos y `GET /api/notificaciones`.
- **Recuperar contraseña** por correo (tabla `password_reset_tokens` ya existe;
  falta proveedor de correo: Mailpit en local, Resend o Brevo gratis en producción).
- **Notificaciones push** (nuevo pedido, pedido en camino…). Requieren Firebase
  Cloud Messaging; mientras tanto, la app consulta cada 20 s.
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
- [ ] Distancia real por calles con Google Directions (hoy: línea recta × `factor_ruta`).
- [x] Pruebas automáticas de la API (`php artisan test`) por cada módulo.
- [ ] Integración continua en GitHub Actions: `flutter analyze` + `flutter test` + pruebas de la API en cada PR.
- [ ] Carrito guardado en el teléfono (hoy se pierde al cerrar la app).
- [ ] Limitar CORS al dominio real cuando exista versión web publicada.
- [ ] Quitar `android:usesCleartextTraffic="true"` del `AndroidManifest.xml` cuando la app use solo HTTPS.
- [ ] Cambiar `APP_KEY` de Railway si alguna vez se expone (cierra todas las sesiones).
- [ ] Si el proyecto crece: plan pago en Railway/Aiven para que no se duerman.
