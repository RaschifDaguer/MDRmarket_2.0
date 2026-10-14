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

> Nunca subir al repositorio la contraseña de la base ni el `ca.pem`.
