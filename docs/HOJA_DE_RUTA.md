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
| 4a | Registrar mi negocio | Rubro, mapa de Google + GPS, foto, NIT opcional, carnet y selfie (solo si faltan); queda "en revisión" |
| 5 | Catálogo | Buscador, categorías, ofertas, orden, detalle de producto (fotos, reseñas) y página de cada tienda (horario, productos, reseñas) |
| 6 | Carrito y pedido | Carrito de un negocio con notas, direcciones guardadas (mapa/GPS), costo de envío por km, efectivo/QR/transferencia, pedido con **PIN de entrega**, cancelar mientras está pendiente, seguimiento del estado |
| 7 | Vista comerciante | Resumen, abierto/cerrado, productos (foto, oferta, stock, tamaño), pedidos entrantes (aceptar → … → entregar con PIN), compras y gastos, perfil y horario |
| 10a | Reseñas | Cliente califica negocio y productos (una por cada uno, editable) después de recibir; el negocio responde |
| 11 | Ganancias | Por período (hoy, 7 días, mes, año) con gráfico y por producto |
| 12 | Panel de administrador | Filament en `/admin`: aprobar/rechazar negocios y documentos (fotos privadas), pedidos (cancelar), usuarios (activar, dar admin), tarifas de envío y comisiones |
| — | Documentación de la API | Scramble en `/docs/api`, generada desde el código |

**Entrega:** todo pedido lo lleva un repartidor de la app (módulo 8): lo acepta
cuando está "listo", lo recoge y lo entrega con el PIN. El local no tiene
delivery propio: llega hasta "listo" y, mientras nadie lo toma, puede cancelarlo.

**Pruebas:** 69 de la API (`php artisan test`, base `mdrmarket_prueba`), incluidas
pruebas de ataque (`SeguridadTest`), y 113 de la app con datos falsos, más
recorridos en vivo contra la API local.

---

## Pendiente

### Módulo 4b — Registro de repartidor ✅ *hecho (en revisión)*
**Objetivo:** que un cliente se convierta en repartidor pidiendo solo lo que le falta.

- **Hecho (backend y panel):** `GET /api/tipos-vehiculo`, `GET` y `POST /api/repartidor`
  (un rechazado puede volver a enviar su solicitud), `POST /api/vehiculos` (un solo
  vehículo en uso; placa y RUAT si el tipo los pide; placa única) y
  Aprobaciones → Repartidores en el panel (aprobar, rechazar con motivo, suspender).
- **Hecho (app):** `features/repartidor/` (pantalla "Quiero ser repartidor"), tarjeta
  "¿Quieres repartir?" en la vista cliente y "Te falta subir…" en la vista repartidor.
- **Pendiente para después:** editar los datos del vehículo (hoy, si lo rechazan por
  la placa o el RUAT, no se pueden corregir desde la app) y permitir más de un vehículo.
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
  pide CI, selfie y foto del vehículo. La selfie (`foto_rostro`) ya la pide la
  base a todo repartidor; la hoja de subir documentos ya abre la cámara delantera.

### Módulo 8 — Vista repartidor ✅ *hecho (en revisión)*
- **Pantallas (hecho):** interruptor "En línea" (manda el GPS si hay permiso),
  pedidos "listos" que su vehículo puede llevar (se actualizan al deslizar),
  Aceptar, pantalla del pedido en curso ("Recogido", "Entregado" con PIN de 4
  números, "Soltar pedido" antes de recogerlo) y pestaña "Mis entregas".
  El cliente ve nombre, vehículo y placa de su repartidor; el negocio, quién lo lleva.
- **API (hecho):** `PUT /api/repartidor/disponible`, `GET /api/repartidor/pedidos-disponibles`,
  `GET /api/repartidor/pedido-actual`, `POST /api/pedidos/{id}/aceptar`,
  `POST /api/pedidos/{id}/soltar`, `PUT /api/repartidor/pedidos/{id}/estado`,
  `GET /api/repartidor/entregas`. Detalle en [API_FRONTEND.md](API_FRONTEND.md#repartidor-llevar-pedidos--módulo-8).
- **Reglas:** solo aprobados, sin sanción, con vehículo aprobado y en línea; un
  pedido a la vez; aceptar con `lockForUpdate` (gana el primero); rol
  `repartidor` en `FlujoPedido` (`listo → en_camino → entregado`). El comerciante
  nunca pone "en camino" ni "entregado" (el local no entrega); con un pedido
  listo ve "Buscando repartidor…" o "Lo lleva…". Su propia compra le aparece al
  repartidor marcada como propia (no la puede tomar).
- **Base (sin cambios):** `pedido.repartidor_id`, `vehiculo_id`, `asignado_en`,
  `recogido_en`, `codigo_entrega`, `fn_distancia_km`, `fn_sancion_activa`,
  `trg_pedido_bu` (no asigna a sancionados), `trg_pedido_au` (venta y `total_entregas`).
- **Pendiente para después:** avisar al repartidor cuando aparece un pedido
  nuevo (push, módulo 13) y paginar "Mis entregas" más allá de las últimas 20.

### Módulo 9 — Rastreo del pedido en el mapa ✅ *hecho (en revisión)*
- **Hecho:** `POST /api/repartidor/ubicacion` (solo con pedido activo, una cada 3 s), `GET /api/pedidos/{id}/seguimiento` (cliente y negocio; posición solo mientras lo lleva), envío del GPS cada 7 s en la app del repartidor y mapa o texto con el tiempo estimado para el cliente. Velocidad: clave `velocidad_promedio_kmh` en `configuracion` (25 km/h si no existe).
- **Pendiente:** probar el mapa real con Playwright y la clave de Maps; ruta por calles con Google Directions.
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
- [x] **Fotos que no se borren en Railway:** Volume montado en
  `/var/www/html/storage/app` desde el 29-oct-2026 (ver
  [api/README.md](../api/README.md#fotos-que-no-se-borren-volume-de-railway)).
  `GET /api` debe decir `"fotos": "disco permanente"`.
  Más adelante, opcional: fotos públicas en Cloudinary (`MEDIA_DISK`).
- [x] Quitar el permiso de administrador a la cuenta de prueba `test@example.com` (29-oct-2026).
- [x] PHP 8.3.36 en el servidor (corrige "PHP2Shell") y contraseña de Aiven cambiada (28-oct-2026).
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
