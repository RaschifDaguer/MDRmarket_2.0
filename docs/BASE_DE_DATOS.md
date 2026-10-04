# Base de datos — MDR Market 2.0

MySQL 8.4 · base **`mdrmarket_new`** · todo guardado en **UTC**.

- **Script maestro:** `mdrmarketnewdatabase.sql` en el repo
  [MDRmarket_2.0_docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker).
  Crea todo desde cero: tablas, vistas, funciones, procedimientos, triggers,
  evento y datos iniciales.
- **Producción:** Aiven for MySQL (plan Free), servicio `mdrmarket-db`.
- **Local:** Laragon (importar el script en phpMyAdmin) o Docker (`docker compose up`).

> La estructura la define **el script**, no las migraciones de Laravel
> (`api/database/migrations` está vacío a propósito).

---

## Contenido

- [Mapa de tablas](#mapa-de-tablas)
- [Vistas, funciones y procedimientos](#vistas-funciones-y-procedimientos)
- [Triggers: reglas que la base hace cumplir sola](#triggers-reglas-que-la-base-hace-cumplir-sola)
- [Cómo cambiar la base](#cómo-cambiar-la-base)
- [Conectarse a la base de producción (Aiven)](#conectarse-a-la-base-de-producción-aiven)
- [Datos de ejemplo](#datos-de-ejemplo)

---

## Mapa de tablas

| Grupo | Tablas | Notas |
|---|---|---|
| **Usuarios** | `usuario`, `direccion` | Una cuenta por persona. Todos pueden comprar. `rol_activo` = última vista usada |
| **Repartidor** | `repartidor` (1 a 1 con usuario), `vehiculo`, `tipo_vehiculo`, `categoria_vehiculo` | Vehículos liviano (moto, bici), mediano (auto, camioneta), grande (camión) |
| **Comerciante** | `negocio` (1 a N con usuario), `negocio_horario` | NIT opcional, ubicación GPS, logo |
| **Documentos** | `documento`, `tipo_documento`, `requisito_rol` | Qué se pide a cada rol está en `requisito_rol` (agregar filas, no columnas) |
| **Catálogo** | `categoria` (2 niveles: principal y subcategoría), `producto`, `producto_imagen`, `favorito` | Los productos van siempre en una subcategoría |
| **Pedidos** | `pedido`, `pedido_item`, `pedido_estado_historial` | `total` y `subtotal` son columnas calculadas |
| **Envío** | `tarifa_envio`, `anillo` | Precio por km; cobertura hasta el 10mo anillo |
| **Rastreo** | `ubicacion_repartidor` | GPS del repartidor; un evento borra lo de más de 30 días |
| **Reseñas** | `resena` | Una por usuario y objetivo (producto, negocio o repartidor) |
| **Reportes** | `reporte`, `reporte_evidencia`, `motivo_reporte`, `sancion` | Denuncias y sanciones con efecto real |
| **Dinero** | `registro_comercio` (compras/ventas del comerciante), `transaccion` (plataforma) | |
| **Sistema** | `configuracion`, `notificacion`, `dispositivo` | `configuracion` = parámetros editables (zona horaria, factor de ruta…) |
| **Laravel** | `personal_access_tokens`, `sessions`, `cache`, `cache_locks`, `jobs`, `job_batches`, `failed_jobs`, `password_reset_tokens`, `migrations` | Las usa el framework |

Estados de un pedido: `pendiente → confirmado → preparando → listo → en_camino → entregado`
(o `cancelado` / `rechazado`).

---

## Vistas, funciones y procedimientos

| Nombre | Tipo | Para qué |
|---|---|---|
| `v_catalogo_producto` | Vista | Catálogo listo: precio final con oferta, imagen, categoría y subcategoría, negocio. Excluye lo sancionado |
| `v_usuario_roles` | Vista | Qué perfiles tiene cada usuario y si está sancionado |
| `v_pedido_resumen` | Vista | Pedido con comprador, negocio, repartidor y vehículo |
| `v_registro_diario` | Vista | Ganancias diarias por negocio (hora de Bolivia) |
| `v_reportes_pendientes` | Vista | Panel del admin: reportes abiertos agrupados por gravedad |
| `v_sancion_activa` | Vista | Sanciones vigentes ahora mismo |
| `sp_datos_faltantes(usuario, rol)` | Procedimiento | Qué le falta a un usuario para ser repartidor o comerciante |
| `sp_reporte_negocio(negocio, desde, hasta, 'dia'/'semana'/'mes'/'anio')` | Procedimiento | Ventas, costos, ganancia y flujo de caja |
| `sp_reporte_productos(negocio, desde, hasta)` | Procedimiento | Por producto: cuánto gastó comprándolo y cuánto ganó |
| `sp_recalcular_rating(tipo, id)` | Procedimiento | Recalcula promedio de estrellas (lo usan los triggers) |
| `fn_cotizar_envio(lat_o, lng_o, lat_d, lng_d, km_ruta, categoria_vehiculo)` | Función | Precio del envío; `NULL` = fuera de cobertura |
| `fn_costo_envio(km, categoria)` | Función | Precio según `tarifa_envio` |
| `fn_anillo(lat, lng)` | Función | En qué anillo está un punto (`NULL` = fuera del 10mo) |
| `fn_distancia_km(...)` | Función | Distancia en línea recta |
| `fn_sancion_activa(usuario, rol)` | Función | ¿Tiene sanción vigente? (`'todos'` = cuenta bloqueada, usar en el login) |
| `fn_negocio_sancionado(negocio)` | Función | ¿El negocio está suspendido? |
| `ev_limpiar_ubicaciones` | Evento | Borra cada día el GPS de más de `dias_historial_gps` días |

---

## Triggers: reglas que la base hace cumplir sola

Cuando un trigger rechaza algo, MySQL lanza `SIGNAL '45000'` y la API lo
devuelve a la app como **error 422 con el mensaje** (ej. "Stock insuficiente").

| Trigger | Qué hace |
|---|---|
| `trg_pedido_bi` | Bloquea pedidos de clientes sancionados o a negocios suspendidos; guarda el anillo de entrega |
| `trg_pedido_item_bi` | Descuenta stock (o falla si no alcanza); copia nombre y costo del producto; bloquea productos retirados |
| `trg_pedido_bu` | No deja asignar el pedido a un repartidor sancionado |
| `trg_pedido_au` | Al entregar: registra la venta y la comisión, suma vendidos y entregas. Al cancelar: devuelve el stock |
| `trg_producto_bi` / `_bu` | Un producto debe ir en una subcategoría |
| `trg_registro_ai` | Al registrar una compra de mercadería: suma stock y actualiza el costo |
| `trg_resena_bi` / `_bu` | Solo quien recibió un pedido puede reseñar; no autoreseñas; al editar no se cambia el objetivo |
| `trg_resena_ai` / `_au` / `_ad` | Recalculan el promedio de estrellas |
| `trg_documento_bi` | Documentos de vehículo o negocio deben ir ligados a uno propio |
| `trg_reporte_bi` | Motivo válido, no autorreportes, y a personas solo si compartieron un pedido |
| `trg_sancion_ai` | Al sancionar desde un reporte, cierra los reportes abiertos del mismo objetivo |

---

## Cómo cambiar la base

> 🚨 **Nunca importes el script completo en Aiven.** Empieza con `DROP TABLE`
> de todo: **borra los datos reales** de producción.

### Pasos

1. **Escribe el cambio como un archivo aparte** en el repo Docker, dentro de la
   carpeta `cambios/`, con fecha y nombre claro:
   `cambios/2026-10-15_agregar_propina_a_pedido.sql`
   ```sql
   ALTER TABLE pedido ADD COLUMN propina DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER descuento;
   ```
2. **Actualiza también el script maestro** `mdrmarketnewdatabase.sql` para que
   una instalación nueva ya salga con el cambio.
3. **Pruébalo en local**: aplica el archivo de `cambios/` a tu base de Laragon o
   Docker y prueba la API y la app.
4. **Haz un respaldo de producción** antes de aplicar (ver abajo).
5. **Aplícalo en Aiven** con tu cliente MySQL (DBeaver, Workbench o la línea de
   comandos).
6. **Sube los dos repos** (script + archivo de cambio) y avisa al equipo.

### Respaldo de producción
Con el `mysqldump` que trae Laragon:
```bash
mysqldump -h mdrmarket-db-mdrmarket.h.aivencloud.com -P 26451 -u avnadmin -p \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=ca.pem \
  --routines --triggers --events --set-gtid-purged=OFF \
  mdrmarket_new > respaldo_AAAA-MM-DD.sql
```
Guarda el respaldo **fuera** del repositorio (tiene datos de usuarios).

---

## Conectarse a la base de producción (Aiven)

Pide al dueño: la **contraseña** y el archivo **`ca.pem`** (o acceso a la
consola de Aiven: servicio `mdrmarket-db` → *Overview → Connection information*).

| Dato | Valor |
|---|---|
| Host | `mdrmarket-db-mdrmarket.h.aivencloud.com` |
| Puerto | `26451` |
| Usuario | `avnadmin` |
| Base | `mdrmarket_new` |
| SSL | **Obligatorio**, con el certificado `ca.pem` |

**DBeaver:** *Nueva conexión → MySQL* → datos de arriba → pestaña **SSL** →
marcar *Use SSL* → *CA Certificate*: `ca.pem` → *Verify server certificate*.

**MySQL Workbench:** *New Connection* → datos de arriba → pestaña **SSL** →
*Use SSL: Require and Verify CA* → *SSL CA File*: `ca.pem`.

**Línea de comandos** (el `mysql` que trae Laragon):
```bash
mysql -h mdrmarket-db-mdrmarket.h.aivencloud.com -P 26451 -u avnadmin -p \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca=ca.pem mdrmarket_new
```

Notas de Aiven Free:
- Si la base pasa mucho tiempo sin uso, **Aiven la apaga** (avisa por correo).
  Se vuelve a encender desde la consola.
- Exige *primary key* en todas las tablas: toda tabla nueva debe tener una.
- Acepta triggers, funciones y eventos (`log_bin_trust_function_creators = 1`).

---

## Datos de ejemplo

El script carga: 10 usuarios (`*@mdrmarket.local`: admin, 3 dueños de negocio,
3 repartidores, 3 clientes), 3 negocios (TechStore SCZ, Sabor Cruceño,
FarmaSuper) con 26 productos, 12 categorías con 49 subcategorías, tarifas de
envío, anillos, motivos de reporte y tipos de documento/vehículo.

Las contraseñas de los usuarios de ejemplo vienen de la versión anterior y no
se conocen: para probar, **crea una cuenta nueva** desde la app.
