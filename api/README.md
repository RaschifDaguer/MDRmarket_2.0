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

| Método | Ruta | Sesión | Para qué |
|---|---|---|---|
| POST | `/api/auth/registro` | — | Crear cuenta (correo, contraseña ×2, nombre, apellido, carnet). Devuelve token |
| POST | `/api/auth/login` | — | Iniciar sesión. Devuelve token |
| POST | `/api/auth/logout` | ✔ | Cerrar sesión en este dispositivo |
| GET | `/api/me` | ✔ | Datos del usuario, `vistas` y `puede_cambiar_vista` |
| PUT | `/api/me/vista` | ✔ | Guardar la vista elegida (`cliente`, `repartidor`, `comerciante`) |

Las rutas con sesión necesitan la cabecera `Authorization: Bearer <token>`.

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

## Docker y Railway

`Dockerfile` arma la API con PHP 8.3 + Apache. En Railway:

1. **New → GitHub Repo →** `MDRmarket_2.0`, y en **Settings → Root Directory** poner `api`.
2. Variables: `APP_KEY` (de `php artisan key:generate --show`), `APP_ENV=production`,
   `APP_DEBUG=false`, `APP_LOCALE=es`, `LOG_CHANNEL=stderr`, `DB_CONNECTION=mysql`,
   `DB_HOST=<servicio-mysql>.railway.internal`, `DB_PORT=3306`,
   `DB_DATABASE=mdrmarket_new`, `DB_USERNAME=root`, `DB_PASSWORD=<la del MySQL>`.
3. Railway asigna el puerto en `$PORT`; `docker/entrypoint.sh` lo configura solo.
