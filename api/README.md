# MDR Market 2.0 — API (Laravel 12)

API REST que usa la app Flutter. Se conecta a la base `mdrmarket_new`
([repo Docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker)).

## Ejecutar en la PC

```
composer install
copy .env.example .env        # en Linux/Mac: cp .env.example .env
php artisan key:generate
php artisan serve --host=0.0.0.0 --port=8001
```

Queda en `http://localhost:8001/api`. Con `--host=0.0.0.0` también la puede
usar un celular conectado a la misma red Wi-Fi.

> En Laragon esta carpeta también aparece como `laragon\www\mdrmarket_v2_api`
> (es un enlace a esta misma carpeta).

## Rutas

Todas las rutas, con sus campos y respuestas, en **`/docs/api`**
(`http://localhost:8001/docs/api`). La documentación la genera **Scramble**
leyendo los controladores: no hay que mantenerla a mano. Tiene un botón
**Authorize** para pegar el token y probar las rutas con sesión.

Resumen: cuenta (`/auth/*`, `/me`), catálogo (`/categorias`, `/productos`,
`/tiendas`), cliente (`/direcciones`, `/envio/cotizar`, `/pedidos`,
`/resenas`) y comerciante (`/negocios` y todo `/negocios/{negocio}/…`, que
solo puede usar el dueño). Ejemplos de cada respuesta en
[docs/API_FRONTEND.md](../docs/API_FRONTEND.md).

Las rutas con sesión necesitan la cabecera `Authorization: Bearer <token>`.

## Panel de administración

En **`/admin`** (Filament 5). Entra quien tenga `usuario.es_admin = 1`, con el
correo y la contraseña de la app. Para nombrar al primero:

```
php artisan mdr:admin tu@correo.com            # --quitar para sacarle el permiso
```

Las fotos de documentos (carnet, licencia) son privadas: el panel las muestra
desde `/panel/documentos/{id}/archivo`, que solo responde a administradores.

**Verificación en dos pasos (obligatoria).** La primera vez que un admin entra,
el panel muestra un código QR: se escanea con Google Authenticator (o Microsoft
Authenticator, Authy) y desde entonces, además de la contraseña, pide el código
de 6 dígitos del celular. En ese momento también da **códigos de recuperación**:
guárdalos fuera del celular; cada uno sirve una vez si pierdes el teléfono.

Si un admin pierde el celular y los códigos, otro admin (o quien tenga acceso a
la base) la reinicia y el panel vuelve a mostrar el QR:

```sql
UPDATE usuario SET app_authentication_secret = NULL, app_authentication_recovery_codes = NULL
WHERE email = 'correo@del.admin';
```

> La clave del autenticador se guarda cifrada con `APP_KEY`. Si alguna vez se
> cambia `APP_KEY`, todos los admins deben reiniciarla así.

## Seguridad

- **Versión de PHP fijada** en el `Dockerfile` (`php:8.3.36-apache`). La 8.3.36
  corrige "PHP2Shell" (CVE-2026-109618 y CVE-2026-109619, oct-2026). Cuando PHP
  publique otra versión de seguridad de la rama 8.3 (https://www.php.net), sube
  ese número y haz push: Railway reconstruye con la nueva.
- **Sesión de la app:** el token vence a los 60 días (`SANCTUM_EXPIRATION`, en
  minutos). Los datos de cada usuario y negocio solo los ve su dueño: con un
  número ajeno en la URL la API responde 404.
- **Límites de solicitudes** (al pasarse: 429 "Demasiadas solicitudes…" y la
  cabecera `Retry-After`). Se cuentan por usuario, o por IP si no hay sesión.
  Ver `AppServiceProvider::limitesDeSolicitudes`.

  | Qué | Límite |
  |---|---|
  | Toda la API | 120 por minuto |
  | Iniciar sesión | 10 por minuto por IP y 5 por minuto por correo |
  | Crear cuenta | 5 por minuto y 30 por día por IP |
  | Hacer pedidos | 5 por minuto y 50 por día |
  | Guardar o cambiar datos | 40 por minuto |
  | Subir fotos | 15 por minuto y 200 por día |
  | Ver fotos (`/api/archivos/…`) | 600 por minuto por IP (no gastan el límite general) |

  Además, un cliente puede tener como máximo **5 pedidos esperando respuesta**
  (`PedidoController::MAXIMO_PENDIENTES`); los aceptados no cuentan.
- **Cabeceras de seguridad** en todas las respuestas (`CabecerasSeguridad`):
  no se puede meter el panel dentro de otra página, el navegador no adivina
  tipos de archivo, HTTPS obligatorio (HSTS) y no se muestran las versiones de
  PHP ni de Apache.
- **Documentación `/docs/api`:** en el servidor solo la ven administradores con
  sesión abierta en `/admin`.
- **Ataques de saturación (DDoS):** los límites frenan a una persona o un bot,
  pero un ataque grande desde miles de IP hay que pararlo antes de que llegue al
  servidor. Para eso hace falta un dominio propio con el proxy de Cloudflare
  (plan gratis) delante de Railway.
- `tests/Feature/SeguridadTest.php` prueba todo esto como lo intentaría un
  atacante (sin sesión, con la sesión de otro, inyección SQL, archivos
  disfrazados, solicitudes en masa).

## Pruebas

`php artisan test` usa una **base aparte, `mdrmarket_prueba`**, creada con el
mismo script maestro (así se prueban los triggers y procedimientos reales).
Cada prueba se deshace sola al terminar (DatabaseTransactions). Para crearla
la primera vez (Laragon encendido; en Git Bash):

```bash
sed 's/mdrmarket_new/mdrmarket_prueba/g' mdrmarketnewdatabase.sql > prueba.sql
mysql -uroot < prueba.sql
```

(el script está en el [repo Docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker)).
Si cambias el script maestro, vuelve a crearla.

**Contraseña:** mínimo 8 caracteres, con mayúscula, minúscula y número, y debe
enviarse dos veces (`password` y `password_confirmation`).

**Errores:** siempre en JSON y en español. Los de validación devuelven 422 con
`message` y `errors` por campo. Las reglas que controla la base de datos (por
ejemplo "Stock insuficiente") también llegan como 422 con su mensaje.

## Notas de diseño

- El esquema lo define el script SQL del repo Docker, no las migraciones de
  Laravel (por eso `database/migrations` está vacío).
- El modelo de login es `App\Models\Usuario` (tabla `usuario`).
- La conexión a MySQL usa UTC (`timezone => +00:00`).
- Los cambios de estado de un pedido pasan siempre por `App\Support\FlujoPedido`
  (quién puede hacer cada cambio, fechas, historial y avisos). Las ventas, el
  stock y los promedios de estrellas los actualiza la base con sus triggers.
- Los archivos de Filament (`public/js/filament`, `public/css/filament`) no se
  suben: los genera `php artisan filament:upgrade`, que corre solo con
  `composer install` y al armar la imagen de Docker.

## Docker y Railway

Publicada en **https://api-mdrmarket-production.up.railway.app/api**.

| Parte | Dónde |
|---|---|
| API | Railway (plan Free), se despliega sola con cada push que cambie `api/` |
| Base de datos | Aiven for MySQL 8.4 (plan Free), base `mdrmarket_new`, conexión SSL |

`Dockerfile` arma la API con PHP 8.3 + Apache. Configuración en Railway:

1. **New → GitHub Repo →** `MDRmarket_2.0`; en **Settings**: Root Directory `/api`
   y Watch Paths `/api/**`.
2. Variables: `APP_KEY` (de `php artisan key:generate --show`), `APP_ENV=production`,
   `APP_DEBUG=false`, `APP_LOCALE=es`, `LOG_CHANNEL=stderr`, `DB_CONNECTION=mysql`,
   `DB_HOST`, `DB_PORT`, `DB_DATABASE=mdrmarket_new`, `DB_USERNAME`, `DB_PASSWORD`
   (los de Aiven) y `DB_SSL_CA_BASE64` (el `ca.pem` de Aiven en base64:
   `base64 -w0 ca.pem`).
3. Railway asigna el puerto en `$PORT`; `docker/entrypoint.sh` lo configura solo,
   escribe el certificado de la base y deja Apache con un solo MPM (prefork).
4. **Disco permanente para las fotos** (ver abajo).

> Nunca subir al repositorio la contraseña de la base ni el `ca.pem`.

### Fotos que no se borren (Volume de Railway)

✅ **Activo desde el 29-oct-2026.** Se comprobó subiendo una foto de prueba y
redesplegando: la foto siguió viéndose.

Las fotos que suben los usuarios (negocios, productos y documentos privados)
se guardan en `storage/app`. El disco normal de Railway **se borra en cada
despliegue**, por eso ahí está montado un disco permanente. Si alguna vez hay
que volver a crearlo (por ejemplo, en un servicio nuevo):

1. En el proyecto de Railway, `Ctrl + K` (o clic derecho en el lienzo) → **Volume**.
2. Elige el servicio de la API.
3. **Mount path:** `/var/www/html/storage/app`
4. Railway redespliega solo. `docker/entrypoint.sh` crea las carpetas
   `public/` y `private/` dentro del disco y se las da a Apache.

**Para comprobarlo:** `GET /api` debe decir `"fotos": "disco permanente"`. Si dice
*disco temporal*, el Volume no está montado y las fotos nuevas se perderán en el
próximo despliegue. Los documentos privados quedan en el mismo disco y nunca se
sirven sin sesión de administrador.

### Rendimiento y caídas de la base

- Cada proceso de Apache reutiliza su conexión cifrada con Aiven
  (`DB_PERSISTENT=true` en el `Dockerfile`), en vez de abrir una nueva en cada solicitud.
- Apache atiende como máximo **10 solicitudes a la vez** (`MaxRequestWorkers`):
  alcanza para la memoria del plan y para las 76 conexiones de Aiven. Si llegan
  más, esperan su turno en vez de tumbar el servidor.
- Si la base está apagada o no responde, la API devuelve **503** con
  "El servicio está en mantenimiento…", y el panel muestra una página "En
  mantenimiento", en vez de "Error del servidor". `GET /api` muestra en todo
  momento si la base está conectada.
- La API (Railway) y la base (Aiven, San Francisco) conviene que estén en la
  misma región de EE. UU. Si se nota lenta, en Railway: servicio → **Settings →
  Region → US West**.
