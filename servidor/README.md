# MDR Market en el servidor de la universidad

Todo el sistema corre en un solo servidor con Docker, en lugar de Railway (API)
y Aiven (base de datos):
- la base de datos;
- la API;
- el panel de administración `/admin`;
- la app web `/app/`;
- la documentación `/docs/api`;
- las fotos, videos y documentos que suben los usuarios.

El servidor es Ubuntu, tiene 1 CPU y unos 4 GB de RAM libres, y es
**compartido con otros grupos**. Cómo identificarlo:
- máquina **CoproInv**, IP interna `192.168.46.112`;
- túnel de Cloudflare `489b791d-7044-47ad-b8e6-db2676e88eee` (`softwareii.sistemasunifranz.site`).

**Dónde está:** en la cuenta **`remoto1`**, carpeta **`/home/remoto1/mdrmarket`**
(el repositorio). La configuración del servidor está en `servidor/`. Se movió
ahí desde `remoto` el 12-nov-2026.

## Qué corre

| Contenedor | Qué hace | Puerto |
|---|---|---|
| `mdrmarket-db-1` | MySQL 8.4.13 con la base `mdrmarket_new` | ninguno (solo por dentro) |
| `mdrmarket-api-1` | API, panel, app web y documentación (imagen de `api/Dockerfile`) | `127.0.0.1:8090` |
| `mdrmarket-respaldo-1` | Respaldo diario de la base a las 04:00 de Bolivia; guarda 14 días en `servidor/respaldos/` | — |
| `mdrmarket-tunel-1` | **Temporal:** dirección pública `*.trycloudflare.com` | — |

- **Lo permanente** queda en dos volúmenes de Docker y sobrevive a cada
  actualización:
  - `mdrmarket_mysql`: la base;
  - `mdrmarket_archivos`: fotos, videos, carnets y licencias.
- **Las claves** están en `servidor/.env`:
  - las crea `instalar.sh` al azar y no van a git;
  - la base no tiene ningún puerto abierto;
  - la API solo escucha en `127.0.0.1`, así que de afuera solo se llega por el
    túnel de Cloudflare.

## Entrar al servidor

En `~/.ssh/config` de la PC (requiere `cloudflared`):

```
Host ssh-software
  HostName softwareii.sistemasunifranz.site
  User remoto
  ProxyCommand cloudflared access ssh --hostname %h
```

Luego:
```
ssh ssh-software
sudo -i
cd /home/remoto1/mdrmarket/servidor
```

**Permisos:**
- La carpeta es de `remoto1`. Desde `remoto` no se puede abrir sin pasar
  antes a administrador con `sudo -i`, que pide la misma contraseña.
- Ya como administrador, los comandos de abajo funcionan con o sin el `sudo`
  de adelante.
- `remoto1` no está en el grupo `docker`. Si el administrador la agrega, desde
  esa cuenta ya no hace falta `sudo`.

## Dirección pública

- **Definitiva.** La agrega quien administra `sistemasunifranz.site` en Cloudflare:
  - Ruta: Zero Trust → Networks → Tunnels → el túnel del servidor → *Public hostname*.
  - Valores: `mdrmarket.sistemasunifranz.site` → tipo `HTTP` → `localhost:8090`.

  Después:
  1. Poner `APP_URL=https://mdrmarket.sistemasunifranz.site` en `.env` y correr `sudo docker compose up -d api`.
  2. Apagar el túnel temporal: `sudo docker compose --profile temporal rm -sf tunel`.
  3. Armar el APK con `--dart-define=API_URL=https://mdrmarket.sistemasunifranz.site/api`.

     La app web no hace falta rearmarla: usa la API del mismo sitio desde donde se abre.
- **Temporal** (para probar o mostrar, sin pedir nada a nadie):
  - Encender: `sudo docker compose --profile temporal up -d tunel`.
  - Ver la dirección: `sudo ./direccion_temporal.sh`.
  - Cambia cada vez que el servidor se reinicia, así que no sirve para el APK.

## Tareas comunes

| Para… | Comando (en `/home/remoto1/mdrmarket/servidor`) |
|---|---|
| Ver el estado | `sudo docker compose ps` y `curl -s http://127.0.0.1:8090/api` |
| Ver errores de la API | `sudo docker compose logs --tail 100 api` |
| Actualizar a lo último de GitHub | `sudo ./actualizar.sh` (no toca la base ni los archivos) |
| Respaldar ahora | `sudo docker compose exec respaldo bash /respaldo.sh ahora` |
| Bajar un respaldo a la PC | Copiarlo primero a un lugar que se pueda leer (ej. `sudo cp respaldos/ARCHIVO /tmp/ && sudo chmod 644 /tmp/ARCHIVO`), bajarlo con `scp ssh-software:/tmp/ARCHIVO .` y después borrarlo de `/tmp` |
| Restaurar un respaldo | `sudo ./importar_base.sh respaldos/ARCHIVO.sql.gz` (**reemplaza** la base) |
| Consola de MySQL | `sudo docker compose exec db sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" mdrmarket_new'` |
| Reiniciar la verificación en dos pasos de un admin | En la consola: `UPDATE usuario SET app_authentication_secret = NULL, app_authentication_recovery_codes = NULL WHERE email = '…';` |

## Pasar los datos desde Aiven

Hay que hacerlo dos veces:
- una al principio;
- otra justo antes de cambiar el APK a la dirección nueva, para traer lo que
  se haya hecho en Railway mientras tanto.

Pasos:
1. **En la PC**, respaldar Aiven con `mysqldump` de Laragon:
   - opciones: `--single-transaction --routines --triggers --events --set-gtid-purged=OFF --no-tablespaces`;
   - la clave va en un `--defaults-extra-file` temporal, nunca en el repo.
2. Copiarlo al servidor: `scp aiven.sql ssh-software:/tmp/`.
3. Importarlo y borrar el `.sql`, porque tiene datos personales:
   ```
   sudo ./importar_base.sh /tmp/aiven.sql
   sudo rm /tmp/aiven.sql
   ```

La `APP_KEY` del `.env` tiene que ser **la misma de Railway**. Con ella se
cifró la verificación en dos pasos del panel; con otra clave, los admins
tendrían que configurarla de nuevo.

## Cuidados

- **El servidor es compartido:**
  - no tocar los contenedores ni las carpetas de otros grupos;
  - no usar los puertos 80, 3306, 5173 ni 8081, que son de ellos.
- **Tamaño de los archivos.** Cloudflare deja pasar hasta 100 MB por
  solicitud, por eso la multimedia llega hasta 90 MB por archivo y 300 MB por
  usuario. Se cambia con `MULTIMEDIA_MAX_MB` y `MULTIMEDIA_CUOTA_MB` en `.env`.
- **Espacio libre.** Si al disco le quedan menos de 3 GB, la API deja de
  aceptar archivos.
- **Respaldos fuera del servidor.** Los respaldos están en el mismo disco.
  Bajar una copia a la PC cada semana.
