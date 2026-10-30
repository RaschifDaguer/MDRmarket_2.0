# MDR Market 2.0

App de delivery para **Santa Cruz de la Sierra**, del centro al 10mo anillo, con
tres vistas en una sola cuenta:

- **Cliente:** compra productos de los negocios y sigue su pedido.
- **Repartidor:** lleva pedidos en moto, bicicleta, auto, camioneta o camión.
- **Comerciante:** publica productos, recibe pedidos y ve sus ganancias.

Cualquier usuario puede comprar. Si además se registra como repartidor o
comerciante, aparece el botón **"cambiar vista"**.

> 👋 **¿Recién llegas al proyecto?** Empieza por la
> [Guía para el equipo](#guía-para-el-equipo): cómo configurar la app, crear tu
> cuenta, hacerte administrador y qué puedes cambiar en el backend. Lo nuevo
> está en [Cambios recientes](#cambios-recientes).

## 🔗 Enlaces del proyecto

| Qué | Enlace | Acceso |
|---|---|---|
| **API publicada** | https://api-mdrmarket-production.up.railway.app/api | Pública. Abrirla muestra si el servidor y la base están funcionando |
| **Panel de administrador** | https://api-mdrmarket-production.up.railway.app/admin | Solo cuentas administradoras, con verificación en dos pasos ([cómo entrar](#-crear-tu-cuenta-y-hacerte-administrador)) |
| **Railway** (servidor de la API: logs, variables, despliegues) | https://railway.com/project/2f0bb79b-64b4-4c55-9e58-2bd9222020f3 | Pedir que te agreguen al proyecto `confident-hope` |
| **Aiven** (base de datos de producción) | https://console.aiven.io → proyecto **`mdrmarket`** → servicio **`mdrmarket-db`** | Pedir invitación a la organización |
| **Repo de código** | https://github.com/RaschifDaguer/MDRmarket_2.0 | Público para leer; colaborador para subir cambios |
| **Repo de la base (Docker)** | https://github.com/RaschifDaguer/MDRmarket_2.0_docker | Ídem |
| **Google Cloud** (clave de Maps, para los módulos de mapa) | https://console.cloud.google.com/apis/credentials | Pedir al dueño |

## Cambios recientes

**Octubre 2026**

| Fecha | Qué cambió | Qué significa para ti |
|---|---|---|
| 30-oct | **El local ya no entrega** (decisión de operaciones): llega hasta "listo"; "en camino" y "entregado" los hace solo el repartidor | En la app del comerciante, un pedido listo muestra "Buscando repartidor…" (puede cancelarlo mientras nadie lo toma) o "Lo lleva…". Ya no hay botón de entregar ni PIN para el local |
| 30-oct | **Corregido:** al cambiar de cuenta en la misma pestaña se veían los pedidos de la cuenta anterior; y la compra propia de un repartidor no aparecía en su lista sin explicar por qué | Ahora cada cuenta ve solo lo suyo al instante. Su propia compra le aparece con "Es tu propio pedido: lo llevará otro repartidor". También: una dirección guardada sin coordenadas (datos de ejemplo) ya no rompe "¿Dónde lo recibes?" |
| 30-oct | **Vista repartidor (módulo 8):** interruptor "En línea", pedidos listos que su vehículo puede llevar, Aceptar, "Recogido", "Entregado" con el PIN, "Soltar pedido" y "Mis entregas" | Ya se puede probar el pedido completo con repartidor. El cliente ve quién lo lleva (nombre, vehículo y placa). Rutas en [docs/API_FRONTEND.md](docs/API_FRONTEND.md#repartidor-llevar-pedidos--módulo-8) |
| 30-oct | **Registro de repartidor en la app (módulo 4b):** tarjeta "¿Quieres repartir?" en el inicio del cliente, pantalla "Quiero ser repartidor" (tarjetas por tipo de vehículo; placa y RUAT solo si los pide) y, en la vista repartidor, "Te falta subir…" con el botón Subir | Se puede probar todo el registro de punta a punta. Si te rechazan, la app muestra el motivo y el botón "Volver a enviar". Por ahora, un solo vehículo por repartidor |
| 30-oct | **Registro de repartidor (módulo 4b), parte del backend:** `GET /api/tipos-vehiculo`, `POST /api/repartidor`, `POST /api/vehiculos` y la sección **Aprobaciones → Repartidores** del panel | La API ya permite registrarse como repartidor con su vehículo; placa y RUAT solo si el tipo los pide (la bicicleta no). Falta la pantalla de la app. Campos y ejemplos en [docs/API_FRONTEND.md](docs/API_FRONTEND.md#registro-de-repartidor--módulo-4b) |
| 29-oct | **Disco permanente activo** en Railway (Volume en `/var/www/html/storage/app`) | Las fotos de negocios, productos y documentos **ya no se borran** al actualizar el servidor. Comprobado: una foto de prueba sobrevivió a un redespliegue. Las que se perdieron antes hay que volver a subirlas |
| 29-oct | `GET /api` muestra también **dónde se guardan las fotos** | Debe decir `"fotos": "disco permanente"`. Si dice *disco temporal*, el Volume se desconectó |
| 29-oct | **`test@example.com` ya no es administrador** | Era una cuenta de prueba sin verificación en dos pasos. Los admins ahora son cuentas reales |
| 28-oct | **PHP 8.3.36** en el servidor (imagen fijada en `api/Dockerfile`) | Corrige "PHP2Shell" (CVE-2026-109618 y CVE-2026-109619), una falla grave de PHP. Si trabajas en la API en tu PC, usa **PHP 8.3.36 o más nuevo** |
| 28-oct | **Contraseña de Aiven cambiada** | La anterior ya no sirve. Si la necesitas, pídesela a Raschif por privado |
| 28-oct | Fotos de los productos de ejemplo en **PNG** | Antes salían vacías en la app (eran SVG, que Flutter no dibuja) |
| 28-oct | **"En mantenimiento"** cuando la base está apagada | Si Aiven se duerme, la app y el panel lo dicen claro (error 503) en vez de "Error del servidor" |
| 28-oct | `GET /api` muestra el **estado del servidor** | Abre https://api-mdrmarket-production.up.railway.app/api: debe decir `"base_de_datos": "conectada"` |
| 28-oct | Servidor preparado para un **disco permanente** (Volume de Railway) | `docker/entrypoint.sh` crea las carpetas de fotos dentro del disco y se las da a Apache ([detalle](api/README.md#fotos-que-no-se-borren-volume-de-railway)) |
| 28-oct | Conexión persistente con la base y máximo 10 procesos de Apache | Respuestas más rápidas; ante una avalancha de solicitudes, el servidor no se cae |
| 28-oct | Cabecera de inicio más limpia; plurales en "Más" y calificaciones | Los íconos de fondo ya no tapan el saludo ni "cerrar sesión" |
| 15-oct | **Selfie obligatoria** para comerciantes y repartidores | Al registrar el negocio se pide una foto de la cara con la cámara delantera; el admin la compara con el carnet |
| 15-oct | Carnet (los dos lados) + selfie = **una sola solicitud** en el panel | El admin ve las 3 fotos juntas y elige qué parte rechazar |
| 14-oct | **Seguridad**: verificación en dos pasos en el panel, límites de solicitudes, cabeceras, `/docs/api` solo para admins, sesiones de la app que vencen a los 60 días | Ver [api/README.md](api/README.md#seguridad) |

Pruebas al día: **69 de la API** (`php artisan test`, incluidas pruebas de
ataque) y **113 de la app** (`flutter test`).

---

## Guía para el equipo

Pensada para quien trabaja en el **frontend (Flutter) y las pruebas**. No
necesitas Laragon ni una base de datos en tu PC: la app usa el servidor de
internet (Railway), que ya está conectado a la base (Aiven).

### Paso 1 — Accesos que tienes que pedir

Pídeselos a Raschif (GitHub `RaschifDaguer`):

- **Colaborador en GitHub** de este repo (y del repo de la base, si vas a tocarla).
- **La clave de Google Maps**, por mensaje privado. Sin ella la app funciona igual,
  pero en lugar del mapa muestra solo el botón de GPS.

### Paso 2 — Instala las herramientas

**Git**, **Flutter 3.44** (que `flutter doctor` no muestre errores), **Google
Chrome**, **VS Code** con las extensiones *Flutter* y *Dart*, y si vas a probar
en Android, **Android Studio** (SDK + un emulador). Detalle de versiones en la
[sección 1](#1-herramientas-que-tienes-que-instalar).

### Paso 3 — Configura y ejecuta el frontend

```bash
git clone https://github.com/RaschifDaguer/MDRmarket_2.0.git
cd MDRmarket_2.0/app
flutter pub get
```

Crea tu archivo de configuración local: copia `app/dart_defines.example.json`
como **`app/dart_defines.local.json`** y déjalo así:

```json
{
  "API_URL": "https://api-mdrmarket-production.up.railway.app/api",
  "GOOGLE_MAPS_KEY": "la-clave-que-te-pasó-Raschif"
}
```

Ese archivo **nunca se sube** al repositorio: ya está en `.gitignore`, porque el
repo es público. Después ejecuta desde `app/`:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines.local.json   # navegador
flutter run --dart-define-from-file=dart_defines.local.json             # emulador o celular conectado
```

| Si quieres usar… | `API_URL` |
|---|---|
| El servidor de internet (lo normal) | `https://api-mdrmarket-production.up.railway.app/api` |
| Una API en tu propia PC, desde Chrome | `http://localhost:8001/api` |
| Una API en tu PC, desde el emulador Android | `http://10.0.2.2:8001/api` |
| Una API en tu PC, desde un celular en tu Wi-Fi | `http://IP-DE-TU-PC:8001/api` |

> Si la app dice **"En mantenimiento"** o no carga nada, abre
> https://api-mdrmarket-production.up.railway.app/api: si dice *sin conexión*,
> la base gratuita de Aiven se durmió. Avisa a Raschif para que la encienda
> (tarda 5–10 minutos).

### Paso 4 — Crea tu cuenta y hazte administrador

Sigue [Crear tu cuenta y hacerte administrador](#-crear-tu-cuenta-y-hacerte-administrador):
te registras en la app, Raschif te da el permiso desde el panel y la primera vez
configuras Google Authenticator.

### Paso 5 — Prueba la app completa

Sigue el [recorrido completo](#recorrido-completo-para-probar-o-para-una-demostración):
cliente → registrar negocio → aprobarlo como admin → agregar productos → pedido →
entrega con PIN → reseña. Para entender qué manda y recibe cada pantalla:

- [docs/API_FRONTEND.md](docs/API_FRONTEND.md): JSON de ejemplo, estados del pedido y errores.
- [docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md): pantallas que faltan y **cómo probar cada una**.
- [docs/DIAGRAMA_BD.md](docs/DIAGRAMA_BD.md): las tablas y cómo se relacionan.

La app publicada usa **datos reales**: no borres ni cambies datos de otros
usuarios. Para romper cosas sin miedo, usa una base local
([sección 3](#3-ponerlo-en-marcha-en-tu-pc)).

### Paso 6 — Sube tus cambios del frontend

```bash
git checkout main && git pull
git checkout -b nombre-del-cambio        # una rama por cambio
# … trabajas …
cd app && flutter analyze && flutter test # los dos sin errores
git add -A && git commit -m "App: qué cambiaste"
git push -u origin nombre-del-cambio
```

Luego abre un **Pull Request** a `main` en GitHub para que Raschif lo revise.
Los cambios que solo tocan `app/` **no** cambian nada del servidor. Si encuentras
un error que no vas a arreglar tú, abre un **Issue** con qué hiciste, qué
esperabas, qué pasó, una captura y el dispositivo (Chrome, emulador o celular).

---

## Cambios en el backend (API y base de datos)

**Sí, puedes hacer cambios en el backend**, con estas reglas, porque todo lo que
llega a `main` dentro de `api/` **se publica solo en el servidor real**:

1. **Prepara tu PC:** PHP **8.3.36 o más nuevo** y Composer (con Laragon es lo
   más fácil; si trae una versión más vieja de PHP, actualízala), más la base
   local `mdrmarket_new` y la de pruebas `mdrmarket_prueba`. Pasos en la
   [sección 3](#3-ponerlo-en-marcha-en-tu-pc) y en [api/README.md](api/README.md#pruebas).
2. **Siempre en una rama y con Pull Request.** Nunca hagas push directo a `main`:
   al unir a `main`, Railway reconstruye la API en 3–5 minutos.
3. **Antes de pedir revisión:** `php artisan test` sin fallos. Si agregas una
   ruta, agrega su prueba y actualiza [docs/API_FRONTEND.md](docs/API_FRONTEND.md).
   La documentación de `/docs/api` se genera sola.
4. **La estructura de la base NO se cambia con migraciones de Laravel.** Se
   cambia en el script del [repo Docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker)
   y con un archivo en su carpeta `cambios/`. Ese cambio se aplica en Aiven
   **antes** de publicar el código que lo usa, con un respaldo previo, y lo
   aplica quien tenga acceso a Aiven. **Nunca importes el script completo en
   Aiven**: borra todos los datos. Ver [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md).
5. **No toques sin hablarlo antes:**
   - la versión de PHP del `api/Dockerfile` (solo se sube, por seguridad);
   - los límites de seguridad y la verificación en dos pasos del panel;
   - `docker/entrypoint.sh`.
6. **Secretos:** contraseñas, `.env`, `ca.pem`, `APP_KEY` y la clave de Google
   **nunca** van al repositorio ni a grupos de chat.
7. **Para estas cosas necesitas a Raschif**, porque requieren acceso al servidor:
   variables de Railway, encender o cambiar Aiven y aplicar cambios de la base.

---

## 👤 Crear tu cuenta y hacerte administrador

En MDR Market **no hay cuentas aparte para administradores**: un administrador
es una cuenta normal de la app con el permiso activado. Con la misma cuenta
compras como cliente en la app y entras al panel web.

### Paso 1 — Crea tu cuenta en la app

1. Abre la app contra el servidor de internet (ver arriba,
   [Configura y ejecuta el frontend](#paso-3--configura-y-ejecuta-el-frontend)) y toca
   **"Crear cuenta"**.
2. Llena tus datos reales:
   - **Nombre y apellido.**
   - **Correo:** no puede estar usado por otra cuenta. Es tu usuario para la app y el panel.
   - **Contraseña, escrita dos veces:** mínimo 8 caracteres, con al menos una
     **mayúscula**, una **minúscula** y un **número**. Ejemplo válido: `Mdrmarket2026`.
   - **Carnet:** número; complemento y lugar de expedición son opcionales.
     El mismo carnet no puede repetirse en dos cuentas.
   - **Teléfono:** opcional.
3. Al terminar ya quedas con sesión abierta en la **vista cliente**.

> Si no tienes Flutter instalado, también puedes crear la cuenta directo contra la
> API (Git Bash o terminal de Mac/Linux):
> ```bash
> curl -X POST https://api-mdrmarket-production.up.railway.app/api/auth/registro \
>   -H "Accept: application/json" -H "Content-Type: application/json" \
>   -d '{"nombre":"Tu nombre","apellido":"Tu apellido","email":"tu@correo.com",
>        "password":"Mdrmarket2026","password_confirmation":"Mdrmarket2026","ci_numero":"1234567"}'
> ```
> Si responde `201` con un `token`, la cuenta quedó creada.

### Paso 2 — Pide el permiso de administrador

Nadie puede darse el permiso a sí mismo desde la app: lo da **otro administrador**.
Pásale tu **correo** a Raschif (o a cualquier admin) y él hace una de estas:

| Quién lo da | Cómo |
|---|---|
| **Un admin, desde el panel** (lo normal) | `/admin` → **Operación → Usuarios** → busca tu correo → menú **⋮** → **"Hacer administrador"** |
| Quien tenga acceso a Aiven | En un cliente MySQL conectado a producción: `UPDATE usuario SET es_admin = 1 WHERE email = 'tu@correo.com';` |
| En una base local (Laragon) | Desde `api/`: `php artisan mdr:admin tu@correo.com` (con `--quitar` lo saca) |

### Paso 3 — Primer ingreso al panel (verificación en dos pasos)

El panel guarda datos personales (fotos de carnets), así que además de la
contraseña pide un **código del celular**. Es obligatorio para todos los admins.

1. Instala en tu celular **Google Authenticator** o **Microsoft Authenticator** (gratis).
2. Entra a **https://api-mdrmarket-production.up.railway.app/admin** con tu correo y
   tu contraseña de la app.
3. La primera vez aparece **"Configurar la aplicación de autenticación"** con un
   **código QR**. En la app del celular toca **+ → Escanear código QR** y apunta a la pantalla.
4. Escribe el **código de 6 dígitos** que muestra el celular y tu **contraseña
   actual**, y toca **Siguiente**.
5. Te muestra **códigos de recuperación**. **Guárdalos fuera del celular**
   (papel o gestor de contraseñas): cada uno sirve una vez si pierdes el teléfono.
6. Desde ahora, cada ingreso pide **contraseña + código de 6 dígitos** (cambia cada 30 s).

> 🔒 No mandes capturas de esa pantalla: el texto debajo del QR es la llave de tu
> verificación. Si se compartió, cancela y vuelve a abrir: se genera otra.

**¿Perdiste el celular y los códigos?** Pide a Raschif que reinicie tu
verificación (en Aiven: `UPDATE usuario SET app_authentication_secret = NULL,
app_authentication_recovery_codes = NULL WHERE email = 'tu@correo.com';`). Al
entrar de nuevo aparece otra vez el QR.

### Qué hace un administrador

| Sección | Para qué |
|---|---|
| **Aprobaciones → Negocios** | Ver cada negocio nuevo (foto, ubicación, datos, documentos del dueño) y **aprobarlo** o rechazarlo con motivo. **Un negocio no aparece en el catálogo hasta que se aprueba.** |
| **Aprobaciones → Documentos** | Revisar la identidad de comerciantes y repartidores: **el carnet (los dos lados) y la selfie van juntos en una sola solicitud**, con las fotos lado a lado. Comprueba que la cara de la selfie sea la del carnet. Al rechazar eliges qué parte debe volver a subir; la persona recibe el motivo. |
| **Operación → Pedidos** | Ver todos los pedidos y cancelar uno si hace falta (devuelve el stock). |
| **Operación → Usuarios** | Activar o desactivar cuentas y **dar o quitar el permiso de administrador**. |
| **Configuración** | Tarifas de envío por distancia, tarifa de servicio y comisión. |

Reglas: no compartas tu cuenta de admin; cada persona usa la suya. Las fotos de
documentos son privadas y solo se ven dentro del panel.

### Recorrido completo para probar (o para una demostración)

1. **Antes de empezar:** abre https://api-mdrmarket-production.up.railway.app/api.
   Debe decir `"base_de_datos": "conectada"`. Si dice *sin conexión* o la app
   muestra **"En mantenimiento"**, la base de Aiven está dormida: hay que
   encenderla (ver [Problemas conocidos](#10-problemas-conocidos)) y esperar
   5–10 minutos. Conviene revisarlo **10 minutos antes** de una presentación.
2. **Cliente:** en la app, pestaña **Inicio** (productos), **Tiendas** y
   **Pedidos**. Los productos que ves son de los negocios **aprobados**.
3. **Volverse comerciante:** en Inicio, **"¿Tienes un negocio? → Registrar"**:
   nombre, rubro, ubicación, foto del negocio, y si faltan, carnet (frente y
   reverso) y **una selfie** (abre la cámara delantera). El negocio queda **"en revisión"**.
4. **Admin:** en el panel, aprueba el negocio y la solicitud de identidad.
5. **Comerciante:** cambia a la vista comerciante (botón de arriba) →
   **Productos → Agregar producto** (foto, precio, stock) → en **Resumen**, que
   esté **Abierto**.
6. **Cliente (otra cuenta):** ve el producto en Inicio o en la tienda → carrito →
   dirección → **hacer pedido**. La app muestra un **PIN de 4 números**.
7. **Comerciante:** **Pedidos → aceptar → preparando → listo → en camino →
   entregado** (pide el PIN del cliente).
8. **Cliente:** califica el negocio y los productos. El comerciante ve sus
   **Ganancias** y puede responder la reseña.

---

## Contenido

- [Cambios recientes](#cambios-recientes)
- [Guía para el equipo](#guía-para-el-equipo) (configurar el frontend, subir cambios)
- [Cambios en el backend (API y base de datos)](#cambios-en-el-backend-api-y-base-de-datos)
- [Crear tu cuenta y hacerte administrador](#-crear-tu-cuenta-y-hacerte-administrador)
- [Estado actual](#estado-actual)
- [Cómo está armado](#cómo-está-armado)
- [1. Herramientas que tienes que instalar](#1-herramientas-que-tienes-que-instalar)
- [2. Accesos que tienes que pedir](#2-accesos-que-tienes-que-pedir)
- [3. Ponerlo en marcha en tu PC](#3-ponerlo-en-marcha-en-tu-pc)
- [4. Servidor en internet (Railway + Aiven)](#4-servidor-en-internet-railway--aiven)
- [5. Cómo trabajar sin romper nada](#5-cómo-trabajar-sin-romper-nada)
- [6. Estructura del código](#6-estructura-del-código)
- [7. API: rutas disponibles](#7-api-rutas-disponibles)
- [8. Reglas del negocio que ya están implementadas](#8-reglas-del-negocio-que-ya-están-implementadas)
- [9. Pruebas](#9-pruebas)
- [10. Problemas conocidos](#10-problemas-conocidos)
- [Documentación adicional](#documentación-adicional)

---

## Estado actual

| # | Módulo | Estado |
|---|---|---|
| 1 | **Base de datos** completa: usuarios y roles, documentos, vehículos, 12 categorías con 49 subcategorías, productos, pedidos, envío por km y anillos, reseñas, reportes, sanciones, ganancias del comerciante | ✅ Hecho |
| 2 | **API:** registro (contraseña segura escrita dos veces), inicio y cierre de sesión, perfil y cambio de vista | ✅ Hecho |
| 3 | **App:** pantallas de arranque, inicio de sesión, registro e inicio por vista, con el botón "cambiar vista" | ✅ Hecho |
| — | **Servidor en internet:** API en Railway + base en Aiven, con despliegue automático | ✅ Hecho |
| 4a | Registro de comerciante (negocio, mapa/GPS, foto, carnet y selfie) | ✅ Hecho |
| 4b | Registro de repartidor (vehículo y documentos) | ✅ Hecho (API, panel y app; un solo vehículo por ahora) |
| 5 | Catálogo con categorías, búsqueda, ofertas y páginas de tienda | ✅ Hecho |
| 6 | Carrito, direcciones, costo del envío y pedido (con PIN de entrega) | ✅ Hecho |
| 7 | Vista comerciante: productos, pedidos entrantes, compras y gastos, perfil y horario | ✅ Hecho |
| 8 | Vista repartidor: en línea, pedidos disponibles, aceptar, recoger, entregar con PIN y mis entregas | ✅ Hecho (todo pedido lo lleva un repartidor de la app; el local no entrega) |
| 9 | **Rastreo del pedido en el mapa** (GPS del repartidor en vivo) | ✅ Hecho (consulta cada pocos segundos; falta probar el mapa con Playwright) |
| 10 | Reseñas (✅ producto y negocio, con respuesta del negocio); reportes y sanciones en la app ⏳ | Parcial |
| 11 | Ganancias del comerciante (por período con gráfico y por producto) | ✅ Hecho |
| 12 | Panel de administrador web (Filament) en `/admin`: aprobar negocios, repartidores e identidades (carnet + selfie), pedidos, usuarios, tarifas; verificación en dos pasos | ✅ Hecho |
| 13 | Notificaciones, recuperar contraseña y publicación (APK / Play Store / iOS) | ⏳ |

El detalle de cada módulo pendiente, con qué construir y cómo probarlo, está en
**[docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md)**.

---

## Cómo está armado

```
📱 App Flutter  ──HTTP──▶  API Laravel  ──SSL──▶  MySQL 8.4
 (Android, iOS, web)        (Railway)              (Aiven)
```

| Repositorio | Contenido |
|---|---|
| **[MDRmarket_2.0](https://github.com/RaschifDaguer/MDRmarket_2.0)** (este) | Código: `api/` (Laravel) y `app/` (Flutter) |
| **[MDRmarket_2.0_docker](https://github.com/RaschifDaguer/MDRmarket_2.0_docker)** | Base de datos: script `mdrmarketnewdatabase.sql` + Dockerfile |

| Parte | Dónde corre | URL / acceso |
|---|---|---|
| API | Railway, plan Free | https://api-mdrmarket-production.up.railway.app/api |
| Base de datos | Aiven for MySQL, plan Free, servicio `mdrmarket-db` | Consola de Aiven (pedir acceso) |
| Código | GitHub | Los dos repos de arriba |

**Decisión importante:** la estructura de la base **la define el script SQL**
del repo Docker, **no** las migraciones de Laravel. Tiene triggers, vistas y
procedimientos que hacen cumplir las reglas del negocio (stock, reseñas,
sanciones…). Ver [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md).

---

## 1. Herramientas que tienes que instalar

### Elige tu camino: no todos necesitan todo

| Vas a trabajar en… | Instala | ¿Laragon? |
|---|---|---|
| **Solo la app** (pantallas Flutter) | Git, Flutter, Android Studio (SDK y emulador), VS Code | ❌ No. La app usa la API de Railway, que ya está conectada a la base de Aiven |
| **La API** (Laravel) | Lo anterior + PHP 8.3 y Composer | ✅ Recomendado. Es la forma más fácil de tener PHP, Composer y MySQL en Windows (alternativas: XAMPP, Herd o Docker) |
| **La base de datos** | Un cliente MySQL: **DBeaver**, **MySQL Workbench** o **HeidiSQL** | ❌ No obligatorio. Puedes conectarte directo a Aiven con SSL ([cómo](docs/BASE_DE_DATOS.md#conectarse-a-la-base-de-producción-aiven)) |

> ⚠️ Aiven es la base **de producción**. Prueba los cambios primero en una base
> local (Laragon o Docker) y aplícalos en Aiven solo cuando funcionen.

### Versiones

Versiones con las que se desarrolló (usa las mismas o más nuevas dentro de la misma versión mayor):

| Herramienta | Versión | Para qué | Notas |
|---|---|---|---|
| **Git** | 2.54 | Clonar y subir cambios | https://git-scm.com |
| **Laragon** | 8.6 (trae PHP 8.3, MySQL 8.4, Apache, phpMyAdmin, HeidiSQL) | Correr la API y la base en tu PC | https://laragon.org — en Windows es lo más simple |
| **PHP** | **8.3.36 o más nuevo** | La API | Viene con Laragon, pero puede traer una 8.3 vieja: las anteriores a la 8.3.36 tienen la falla "PHP2Shell". Para actualizar: descarga `php-8.3.36-1-Win32-vs16-x64.zip` de https://downloads.php.net/~windows/releases/, descomprímelo en `laragon\bin\php\php-8.3.36-Win32-vs16-x64`, copia ahí tu `php.ini` (corrigiendo `extension_dir`) y elígelo en Laragon → PHP → Versión |
| **Composer** | 2.9 | Dependencias de PHP | Viene con Laragon o https://getcomposer.org |
| **MySQL** | 8.4 | Base de datos local | Viene con Laragon |
| **Flutter SDK** | 3.44.1 (Dart 3.12.1), canal stable | La app | https://docs.flutter.dev/get-started/install — corre `flutter doctor` al terminar |
| **Android Studio** | Reciente | SDK de Android y emulador | Solo para Android SDK + emulador; el código se edita en VS Code |
| **VS Code** | Reciente | Editor | Extensiones: *Flutter*, *Dart*, *PHP Intelephense*, *Laravel Extra Intellisense* (opcional) |
| **Google Chrome** | Reciente | Probar la app en web | `flutter run -d chrome` |
| Docker Desktop | Opcional | Levantar la base con un comando | Solo si no usas Laragon |
| Xcode (Mac) | Opcional | Compilar para iPhone | **Solo en Mac.** Desde Windows no se puede compilar iOS |

Paquetes principales (se instalan solos con `composer install` / `flutter pub get`):

- **App:** `flutter_riverpod` 3.4 (estado), `go_router` 18 (navegación), `dio` 5 (HTTP), `flutter_secure_storage` 11 (token guardado cifrado).
- **API:** `laravel/framework` 12, `laravel/sanctum` 4 (login con tokens), `laravel-lang/common` (mensajes en español).

---

## 2. Accesos que tienes que pedir

Pídeselos al dueño del proyecto (**Raschif Daguer**, GitHub `RaschifDaguer`):

| Acceso | Para qué | Cómo te lo da |
|---|---|---|
| **GitHub** — colaborador en los dos repos | Subir cambios (push) | Repo → *Settings → Collaborators → Add people* |
| **Railway** — proyecto `confident-hope` | Ver logs y variables de la API | *Project Settings → Members* (si el plan lo permite; si no, te comparte los logs) |
| **Aiven** — proyecto `mdrmarket` | Ver/administrar la base de producción | *Admin → Users → Invite* |
| **Valores del `.env` de producción** | Solo si vas a tocar el servidor | Por mensaje privado, **nunca** por el repo ni grupos |
| **Clave de Google Maps** | Mapa al registrar el negocio; rastreo (9) | Es la misma de la versión anterior; va en `app/dart_defines.local.json` (ver [app/README.md](app/README.md#con-el-mapa-de-google-chrome)), nunca en el código |

> 🔒 **Secretos:** contraseñas, `APP_KEY`, la clave de Google y el `ca.pem` de
> Aiven **nunca** se suben al repositorio. Los `.gitignore` ya excluyen `.env`
> y `*.pem`.

---

## 3. Ponerlo en marcha en tu PC

### 3.1 Clonar
```bash
git clone https://github.com/RaschifDaguer/MDRmarket_2.0.git
git clone https://github.com/RaschifDaguer/MDRmarket_2.0_docker.git
```

### 3.2 Base de datos local
1. Abre **Laragon → Start All**.
2. Abre **phpMyAdmin** (o HeidiSQL) → **Importar** → uno de estos dos archivos del repo Docker:
   - `mdrmarket_new_aiven_2026-10-03.sql`: **copia exacta de producción (Aiven)**. Úsala para tener lo mismo que la app publicada.
   - `mdrmarketnewdatabase.sql`: script maestro comentado, para crear la base desde cero.

   Cualquiera de los dos crea solo la base **`mdrmarket_new`** (hoy con 10
   usuarios, 3 negocios y 26 productos de ejemplo). ⚠️ Ninguno se importa en Aiven.

   *Alternativa con Docker:* dentro de `MDRmarket_2.0_docker`, `docker compose up -d --build`
   (queda en `localhost:3307`, usuario `root`, contraseña `root`).

### 3.3 API
```bash
cd MDRmarket_2.0/api
composer install
copy .env.example .env          # en Mac/Linux: cp .env.example .env
php artisan key:generate
php artisan serve --host=0.0.0.0 --port=8001
```
Abre http://localhost:8001/up → debe responder. El `.env.example` ya apunta a
`mdrmarket_new` en `127.0.0.1:3306` con usuario `root` sin contraseña (Laragon).

### 3.4 App
```bash
cd MDRmarket_2.0/app
flutter pub get
flutter run -d chrome           # navegador
flutter run                     # emulador Android abierto en Android Studio
```

| Dónde corre la app | API que usa por defecto |
|---|---|
| Chrome | `http://localhost:8001/api` |
| Emulador Android | `http://10.0.2.2:8001/api` (así ve el emulador a tu PC) |
| Celular real en tu Wi-Fi | `flutter run --dart-define=API_URL=http://IP-DE-TU-PC:8001/api` |
| Contra el servidor de internet | `flutter run --dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api` |

Para ver el **mapa de Google** en Chrome hace falta la clave en un archivo local:
ver [app/README.md](app/README.md#con-el-mapa-de-google-chrome). Sin clave, la
app usa solo el botón de GPS.

Usuarios de ejemplo: los `*@mdrmarket.local` del script. Lo más simple es
**crear tu propia cuenta** desde la pantalla de registro.

### 3.5 Atajos sin Laragon

- **Solo app:** salta 3.2 y 3.3, y en 3.4 corre
  `flutter run --dart-define=API_URL=https://api-mdrmarket-production.up.railway.app/api`.
- **API local contra la base de Aiven** (sin MySQL local): en `api/.env` pon los
  datos de Aiven y la ruta del certificado (pídelos al dueño):
  ```
  DB_HOST=mdrmarket-db-mdrmarket.h.aivencloud.com
  DB_PORT=26451
  DB_DATABASE=mdrmarket_new
  DB_USERNAME=avnadmin
  DB_PASSWORD=(pedir al dueño)
  MYSQL_ATTR_SSL_CA=C:/ruta/a/ca.pem
  ```
  ⚠️ Así trabajas sobre **datos reales**: lo que crees o borres se ve en la app publicada.

### 3.6 Panel de administrador

Es una página web dentro de la misma API: **`/admin`**
(`http://localhost:8001/admin` en tu PC, `https://api-mdrmarket-production.up.railway.app/admin`
en internet). Cómo crear la cuenta, hacerte administrador y configurar la
verificación en dos pasos: ver
[Crear tu cuenta y hacerte administrador](#-crear-tu-cuenta-y-hacerte-administrador).

En tu base local, el permiso se da con `php artisan mdr:admin tu@correo.com`
(desde `api/`). La verificación en dos pasos también se pide en local.

---

## 4. Servidor en internet (Railway + Aiven)

- **Despliegue automático:** cada `git push` a `main` que cambie algo dentro de
  `api/` hace que Railway reconstruya y publique la API sola (3–5 min).
  Cambios solo en `app/` no redespliegan nada.
- **La app instalada en celulares no se actualiza sola:** si cambias pantallas,
  hay que generar e instalar un APK nuevo (`flutter build apk`).
- **La base en Aiven NO se actualiza sola.** Si cambias el script SQL, hay que
  aplicar el cambio a mano. **Nunca importes el script completo en Aiven**: borra
  todas las tablas y los datos. Ver [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md#cómo-cambiar-la-base).
- Configuración de Railway (Root Directory `/api`, variables, `DB_SSL_CA_BASE64`):
  ver [api/README.md](api/README.md#docker-y-railway).

---

## 5. Cómo trabajar sin romper nada

1. **Una rama por módulo o arreglo:**
   ```bash
   git checkout main && git pull
   git checkout -b modulo-4-registro-repartidor
   ```
2. **Prueba en tu PC** (Laragon + `flutter run`) antes de subir.
3. **Corre las pruebas** (ver [Pruebas](#9-pruebas)) y `flutter analyze` sin errores.
4. **Sube la rama y abre un Pull Request** a `main`. Que el otro lo revise.
5. Al unir a `main`, si tocaste `api/`, Railway publica solo. Revisa que el
   servicio quede *Online* y prueba `https://…/up`.

Convenciones del código:

- **Todo en español:** nombres de tablas, columnas, variables, mensajes y commits.
- **App:** una carpeta por funcionalidad en `app/lib/features/<feature>/` con
  `data/` (llamadas a la API), `domain/` (modelos) y `presentation/` (pantallas y
  estado con Riverpod). Lo compartido va en `app/lib/core/`.
- **API:** controladores en `app/Http/Controllers/Api`, validaciones en
  `app/Http/Requests`, respuestas con `app/Http/Resources`. Errores siempre en
  JSON y en español.
- **Reglas del negocio importantes van en la base** (triggers), así se cumplen
  aunque alguien llame a la API de otra forma.

---

## 6. Estructura del código

```
MDRmarket_2.0/
├── README.md                 ← este archivo
├── docs/
│   ├── HOJA_DE_RUTA.md       ← qué falta y cómo hacerlo
│   ├── API_FRONTEND.md       ← qué manda y recibe cada pantalla
│   ├── DIAGRAMA_BD.md        ← diagrama de la base
│   └── BASE_DE_DATOS.md      ← cómo está la base y cómo cambiarla
├── api/                      ← Laravel 12
│   ├── app/Http/Controllers/Api/              cuenta, catálogo, pedidos, direcciones, reseñas…
│   ├── app/Http/Controllers/Api/Comerciante/  productos, pedidos, compras y gastos, ganancias, reseñas
│   ├── app/Http/Requests/ y Resources/        validaciones y formato de las respuestas
│   ├── app/Models/                            una clase por tabla (Usuario, Negocio, Producto, Pedido…)
│   ├── app/Support/                           FlujoPedido (estados), Envio, Revision (admin), Archivos
│   ├── app/Filament/                          panel de administración (/admin)
│   ├── routes/api.php, web.php, console.php   rutas y el comando mdr:admin
│   ├── tests/Feature/                         pruebas (php artisan test)
│   ├── bootstrap/app.php                      errores JSON en español
│   ├── Dockerfile + docker/entrypoint.sh      imagen para Railway
│   └── README.md
└── app/                      ← Flutter
    ├── lib/main.dart, app.dart
    ├── lib/core/            config (URL de la API), red (Dio), router, tema, almacenamiento,
    │                        maps/ (mapa + GPS), archivos/ (fotos), formato/ (Bs y fechas), widgets/
    ├── lib/features/auth/        login, registro, sesión
    ├── lib/features/inicio/      inicio por vista (cliente / repartidor / comerciante) + cambio de vista
    ├── lib/features/catalogo/    catálogo, detalle de producto, tiendas
    ├── lib/features/carrito/     carrito (de un solo negocio)
    ├── lib/features/pedidos/     confirmar pedido, direcciones, mis pedidos, calificar
    ├── lib/features/comerciante/ registrar negocio y todas las pantallas del comerciante
    ├── lib/features/perfil/      lo que falta para cada rol + subir documentos
    ├── test/                pruebas (falsos.dart = datos de prueba sin internet)
    └── README.md
```

En la PC del dueño, `C:\Raschif\laragon\www\mdrmarket_v2_api` es un enlace a
`api/` para que Laragon la muestre; no hace falta replicarlo.

---

## 7. API: rutas disponibles

| Método | Ruta | Sesión | Para qué |
|---|---|---|---|
| GET | `/api` | — | Estado del servidor, de la base de datos (`"base_de_datos": "conectada"`) y de las fotos (`"fotos": "disco permanente"`) |
| POST | `/api/auth/registro` | — | Crear cuenta. Devuelve `token` y `usuario` |
| POST | `/api/auth/login` | — | Iniciar sesión. Devuelve `token` y `usuario` |
| POST | `/api/auth/logout` | ✔ | Cerrar sesión en este dispositivo |
| GET | `/api/me` | ✔ | Usuario, `vistas` y `puede_cambiar_vista` |
| PUT | `/api/me/vista` | ✔ | Guardar la vista activa (`cliente` / `repartidor` / `comerciante`) |
| PUT | `/api/me` | ✔ | Completar datos personales (apellido, CI, teléfono…) |
| GET | `/api/me/faltantes/{rol}` | ✔ | Lo que le falta para ser `repartidor` o `comerciante` |
| GET | `/api/categorias` | — | Rubros principales con sus subcategorías |
| GET | `/api/negocios` | ✔ | Mis negocios |
| POST | `/api/negocios` | ✔ | Registrar mi negocio (con foto; queda en revisión) |
| GET | `/api/documentos` | ✔ | Mis documentos subidos y su estado |
| POST | `/api/documentos` | ✔ | Subir la foto de un documento (carnet, licencia, fotos del vehículo con `vehiculo_id`…) |
| GET | `/api/tipos-vehiculo` | ✔ | Moto, bicicleta, auto, camioneta, camión: categoría y si piden placa, RUAT y licencia |
| GET | `/api/repartidor` | ✔ | Mi perfil de repartidor, con el vehículo y el motivo si me rechazaron |
| POST | `/api/repartidor` | ✔ | Registrarme como repartidor (queda en revisión) o volver a enviar si me rechazaron |
| POST | `/api/vehiculos` | ✔ | Registrar mi vehículo (uno solo; placa y RUAT si el tipo los pide; placa única) |
| PUT | `/api/repartidor/disponible` | ✔ repartidor | En línea o desconectado (con su ubicación) |
| GET | `/api/repartidor/pedidos-disponibles` | ✔ repartidor | Pedidos listos que su vehículo puede llevar, del más cercano al más lejano |
| GET | `/api/repartidor/pedido-actual` | ✔ repartidor | El pedido que lleva ahora |
| POST | `/api/pedidos/{id}/aceptar`, `/soltar` | ✔ repartidor | Tomar un pedido (gana el primero) o soltarlo antes de recogerlo |
| PUT | `/api/repartidor/pedidos/{id}/estado` | ✔ repartidor | "en_camino" (recogido) o "entregado" con el PIN |
| GET | `/api/repartidor/entregas` | ✔ repartidor | Historial de entregas con lo ganado en envíos |
| GET | `/api/archivos/{ruta}` | — | Ver una foto pública (negocios, productos) |
| GET | `/api/productos`, `/api/productos/{id}` | — | Catálogo (filtros: categoría, negocio, texto, ofertas, orden) y detalle |
| GET | `/api/tiendas`, `/api/tiendas/{id}` | — | Negocios aprobados y página de cada uno |
| GET/POST/PUT/DELETE | `/api/direcciones` | ✔ | Direcciones guardadas del cliente |
| POST | `/api/envio/cotizar` | ✔ | Costo del envío hasta una dirección |
| GET/POST | `/api/pedidos` | ✔ | Mis pedidos / hacer un pedido |
| GET | `/api/pedidos/{id}` | ✔ | Detalle (lo ven el comprador y el negocio) |
| POST | `/api/pedidos/{id}/cancelar` | ✔ | Cancelar (solo mientras está pendiente) |
| PUT | `/api/resenas` | ✔ | Calificar un producto o negocio (crea o edita) |
| … | `/api/negocios/{id}/…` | ✔ dueño | Perfil, horario, abierto, productos, pedidos, compras y gastos, ganancias, reseñas |

**Todas las rutas, con sus campos y para probarlas:** `http://localhost:8001/docs/api`
(o `https://api-mdrmarket-production.up.railway.app/docs/api`). La genera
**Scramble** leyendo el código. Ejemplos en [docs/API_FRONTEND.md](docs/API_FRONTEND.md).

Sesión = cabecera `Authorization: Bearer <token>` (Laravel Sanctum).
Prueba rápida:
```bash
curl https://api-mdrmarket-production.up.railway.app/api/me -H "Accept: application/json"
# → 401 {"message":"Tu sesión expiró o no iniciaste sesión."}
```

---

## 8. Reglas del negocio que ya están implementadas

- **Registro:** correo, contraseña **escrita dos veces** (mínimo 8 caracteres
  con mayúscula, minúscula y número), nombre, apellido y carnet
  (número + complemento + expedido). Correo y carnet no se pueden repetir.
- **Vistas:** cliente siempre; repartidor si tiene perfil (aunque esté en
  revisión); comerciante si tiene un negocio. El botón "cambiar vista" **solo
  aparece si tiene más de una**.
- **Convertirse en repartidor o comerciante** pidiendo solo lo que falta:
  `CALL sp_datos_faltantes(usuario, 'repartidor')`. Al repartidor se le piden
  carnet (anverso y reverso), **selfie**, licencia, foto del vehículo, foto de
  la placa y RUAT; a una bicicleta solo carnet, selfie y foto del vehículo. Al
  comerciante, carnet y selfie. La selfie se toma con la cámara delantera y el
  administrador la compara con la foto del carnet.
- **Envío:** precio por km recorrido (`tarifa_envio`: hasta 3 km 3 Bs, hasta
  6 km 5 Bs, hasta 10 km 8 Bs, hasta 15 km 12 Bs, hasta 20 km 15 Bs, hasta 30 km 20 Bs)
  y cobertura del centro al **10mo anillo** (`fn_cotizar_envio`).
- **Stock:** se descuenta en la base al crear el pedido (falla con "Stock
  insuficiente") y se devuelve si se cancela.
- **Reseñas:** una por usuario para cada producto, negocio o repartidor,
  editable; solo después de recibir un pedido; nadie se reseña a sí mismo.
- **Reportes y sanciones:** reportes con motivo; las sanciones bloquean pedidos,
  ocultan negocios/productos y vencen solas.
- **Ganancias del comerciante:** las ventas se registran solas al entregar un
  pedido; reportes por día, semana, mes o año (`sp_reporte_negocio`). Las
  compras de mercadería suman stock y actualizan el costo.
- **Pedido:** a un solo negocio, aprobado y abierto; el precio sale del
  catálogo (con la oferta vigente), respeta el pedido mínimo y la cobertura.
  Estados: pendiente → aceptado → preparando → listo → en camino → entregado
  (o rechazado / cancelado). El cliente cancela solo mientras está pendiente.
- **Entrega:** un pedido "listo" lo acepta un **repartidor** (aprobado, sin
  sanción, en línea y con un vehículo del tamaño necesario), que lo recoge y lo
  marca "entregado" con el **PIN de 4 números** que solo ve el cliente. Lleva un
  pedido a la vez y puede soltarlo antes de recogerlo. **El local no entrega**
  (no tiene delivery propio): lleva el pedido hasta "listo" y ve "Buscando
  repartidor…" o quién lo lleva; mientras nadie lo toma, puede cancelarlo.
- **Aprobación:** un negocio nuevo queda "en revisión" hasta que un
  administrador lo aprueba en `/admin`; recién ahí aparece en el catálogo.
- **Horario:** todo se guarda en **UTC**; los reportes se muestran en hora de
  Bolivia (-04:00).

Detalle completo en [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md).

---

## 9. Pruebas

```bash
# App (desde app/)
flutter analyze
flutter test                                                        # todas las pantallas con datos falsos
flutter test --dart-define=API_URL=http://127.0.0.1:8001/api        # + recorridos reales contra la API local
flutter test test/responsivo_test.dart --dart-define=CAPTURAS=true  # imágenes de cada pantalla en build/capturas/

# API (desde api/): usa la base aparte mdrmarket_prueba (ver api/README.md)
php artisan test
```

Regla del equipo: **cada módulo nuevo trae al menos una prueba simple que
demuestre que cumple su función** (ver "Cómo probarlo" en cada módulo de la
[hoja de ruta](docs/HOJA_DE_RUTA.md)).

---

## 10. Problemas conocidos

| Síntoma | Causa | Qué hacer |
|---|---|---|
| La primera consulta al servidor tarda 10–30 s | Railway Free "duerme" la API sin uso | Normal; las siguientes son rápidas |
| La app o el panel dicen **"En mantenimiento"** (o `/api` dice `"base_de_datos": "sin conexión"`) | Aiven apagó la base gratuita por inactividad | https://console.aiven.io → proyecto `mdrmarket` → servicio `mdrmarket-db` → **Power on**. Pasa por *Rebuilding* y en 5–10 min queda **Running**; todo vuelve solo, sin tocar nada más. Si no tienes acceso a Aiven, avisa a Raschif |
| Railway: `AH00534: More than one MPM loaded` | Imagen php:apache | Ya resuelto en `Dockerfile` y `entrypoint.sh`; no borrar esas líneas |
| Railway: "Free plan resource provision limit exceeded" | Límite del plan Free (1 USD/mes) | Por eso la base está en Aiven y no en Railway |
| La app en el emulador no conecta | Usa `localhost` | El emulador usa `10.0.2.2`; un celular real necesita la IP de la PC |
| Error de CORS en Chrome | API apagada o URL mal escrita | Revisa que la API esté encendida y la URL termine en `/api` |
| Al registrar el negocio no aparece el mapa, solo el botón GPS | Falta la clave de Google Maps, o la clave no tiene activada la Maps JavaScript API | Ver [app/README.md](app/README.md#con-el-mapa-de-google-chrome) |
| Una foto subida (negocio, producto, documento) no se ve o desapareció | Si es de antes del 29-oct, se borró con un despliegue (todavía no había disco permanente). Si es nueva, el Volume de Railway pudo desconectarse | Las antiguas hay que volver a subirlas. Abre https://api-mdrmarket-production.up.railway.app/api: si `"fotos"` no dice *disco permanente*, revisa el Volume del servicio en Railway ([cómo](api/README.md#fotos-que-no-se-borren-volume-de-railway)) |
| En el panel, al entrar, no se ve el QR | Versión vieja del panel | Ya corregido (`AutenticadorApp`); recarga con Ctrl + F5 |
| VS Code marca en rojo cosas de Laravel | El editor no tiene indexado `vendor/` | Abre la carpeta `api/` sola en VS Code o corre `composer install` |

---

## Documentación adicional

- [docs/HOJA_DE_RUTA.md](docs/HOJA_DE_RUTA.md) — módulos pendientes, uno por uno.
- [docs/API_FRONTEND.md](docs/API_FRONTEND.md) — qué manda y recibe la app en cada pantalla (JSON de ejemplo).
- [docs/DIAGRAMA_BD.md](docs/DIAGRAMA_BD.md) — diagrama de la base de datos.
- [docs/BASE_DE_DATOS.md](docs/BASE_DE_DATOS.md) — tablas, vistas, triggers y cómo cambiar la base.
- [api/README.md](api/README.md) — API y despliegue en Railway.
- [app/README.md](app/README.md) — app Flutter.
- [Repo de la base (Docker)](https://github.com/RaschifDaguer/MDRmarket_2.0_docker).
