# Diagrama de la base de datos

Esquema visual de las tablas principales de `mdrmarket_new` y cómo se
relacionan. GitHub dibuja estos diagramas automáticamente.

- Solo se muestran los **campos más importantes** de cada tabla.
- La definición completa (todas las columnas, tipos y comentarios) está en el
  script [`mdrmarketnewdatabase.sql`](https://github.com/RaschifDaguer/MDRmarket_2.0_docker/blob/main/mdrmarketnewdatabase.sql).
- Explicación de cada tabla, vista y trigger: [BASE_DE_DATOS.md](BASE_DE_DATOS.md).
- Qué datos recibe la app en cada pantalla: [API_FRONTEND.md](API_FRONTEND.md).

**Cómo leer las líneas:** `||--o{` = "uno a muchos" (un usuario tiene muchas
direcciones); `||--o|` = "uno a uno opcional" (un usuario puede tener un
perfil de repartidor).

---

## 1. Usuarios y roles

Una sola cuenta por persona. Repartidor y comerciante son perfiles que
"cuelgan" del usuario.

```mermaid
erDiagram
    usuario ||--o{ direccion : "guarda"
    usuario ||--o| repartidor : "puede ser"
    usuario ||--o{ negocio : "es dueño de"
    usuario ||--o{ documento : "sube"
    repartidor ||--o{ vehiculo : "registra"
    tipo_vehiculo ||--o{ vehiculo : "clasifica"
    categoria_vehiculo ||--o{ tipo_vehiculo : "agrupa"
    tipo_documento ||--o{ documento : "tipo de"
    vehiculo ||--o{ documento : "foto, placa, RUAT"
    negocio ||--o{ documento : "NIT"

    usuario {
        bigint id PK
        varchar nombre
        varchar apellido
        varchar email UK
        varchar password "cifrada"
        varchar ci_numero "carnet"
        varchar ci_complemento
        enum ci_expedido "SC, LP, CB..."
        enum rol_activo "cliente, repartidor, comerciante, admin"
        bool es_admin
        timestamp deleted_at "borrado lógico"
    }
    direccion {
        bigint id PK
        bigint usuario_id FK
        varchar etiqueta "Casa, Trabajo"
        varchar direccion
        decimal latitud
        decimal longitud
    }
    repartidor {
        bigint usuario_id PK, FK
        enum estado_verificacion "pendiente, aprobado, rechazado, suspendido"
        bool disponible "en línea"
        decimal latitud_actual
        decimal longitud_actual
        decimal rating_promedio
        int total_entregas
    }
    vehiculo {
        bigint id PK
        bigint repartidor_id FK
        tinyint tipo_vehiculo_id FK
        varchar placa
        varchar ruat
        bool en_uso
    }
    tipo_vehiculo {
        tinyint id PK
        tinyint categoria_vehiculo_id FK
        varchar codigo "moto, bicicleta, auto, camioneta, camion"
        bool requiere_placa
        bool requiere_ruat
        bool requiere_licencia
    }
    categoria_vehiculo {
        tinyint id PK
        varchar codigo "liviano, mediano, grande"
    }
    negocio {
        bigint id PK
        bigint usuario_id FK "dueño"
        bigint categoria_id FK "rubro"
        varchar nombre
        varchar nit "opcional"
        decimal latitud "GPS"
        decimal longitud
        varchar logo_url "foto del negocio"
        bool abierto
        enum estado_verificacion
        decimal rating_promedio
    }
    documento {
        bigint id PK
        bigint usuario_id FK
        smallint tipo_documento_id FK
        bigint vehiculo_id FK "si es del vehículo"
        bigint negocio_id FK "si es del negocio"
        varchar archivo_url
        enum estado "pendiente, aprobado, rechazado"
    }
    tipo_documento {
        smallint id PK
        varchar codigo "ci_anverso, ci_reverso, licencia_conducir, foto_vehiculo, foto_placa, ruat, nit"
        enum ambito "persona, vehiculo, negocio"
    }
```

---

## 2. Catálogo, pedidos y rastreo

```mermaid
erDiagram
    categoria ||--o{ categoria : "subcategorías"
    categoria ||--o{ producto : "clasifica"
    negocio ||--o{ producto : "vende"
    producto ||--o{ producto_imagen : "fotos"
    usuario ||--o{ pedido : "compra"
    negocio ||--o{ pedido : "recibe"
    repartidor ||--o{ pedido : "lleva"
    pedido ||--|{ pedido_item : "contiene"
    producto ||--o{ pedido_item : "aparece en"
    pedido ||--o{ pedido_estado_historial : "cambios de estado"
    pedido ||--o{ ubicacion_repartidor : "rastreo GPS"
    repartidor ||--o{ ubicacion_repartidor : "envía"

    categoria {
        bigint id PK
        bigint categoria_padre_id FK "NULL = principal"
        varchar nombre
        varchar icono "emoji"
    }
    producto {
        bigint id PK
        bigint negocio_id FK
        bigint categoria_id FK "siempre subcategoría"
        varchar nombre
        text descripcion
        decimal precio
        decimal precio_oferta "opcional"
        decimal costo "lo que le cuesta al comerciante"
        int stock "NULL = sin control"
        decimal rating_promedio
        int total_resenas
    }
    producto_imagen {
        bigint id PK
        bigint producto_id FK
        varchar url
        bool es_principal
    }
    pedido {
        bigint id PK
        bigint comprador_id FK
        bigint negocio_id FK
        bigint repartidor_id FK "NULL hasta que lo acepten"
        enum estado "pendiente, confirmado, preparando, listo, en_camino, entregado, cancelado, rechazado"
        varchar direccion_entrega
        decimal latitud_entrega
        decimal longitud_entrega
        tinyint anillo_entrega "se calcula solo"
        decimal subtotal
        decimal costo_envio
        decimal total "calculado"
        enum metodo_pago "efectivo, qr, transferencia, tarjeta"
        enum estado_pago "pendiente, pagado, fallido, reembolsado"
        char codigo_entrega "PIN"
        timestamp entregado_en
    }
    pedido_item {
        bigint id PK
        bigint pedido_id FK
        bigint producto_id FK
        varchar producto_nombre "copia"
        decimal precio_unitario
        smallint cantidad
        decimal subtotal "calculado"
    }
    pedido_estado_historial {
        bigint id PK
        bigint pedido_id FK
        varchar estado_anterior
        varchar estado_nuevo
        enum rol "quién lo cambió"
    }
    ubicacion_repartidor {
        bigint id PK
        bigint repartidor_id FK
        bigint pedido_id FK
        decimal latitud
        decimal longitud
        timestamp registrado_en
    }
```

Tablas de envío sin relaciones directas: `tarifa_envio` (precio por km según
`categoria_vehiculo`) y `anillo` (radios del 1er al 10mo anillo).

---

## 3. Reseñas, reportes, sanciones y ganancias

```mermaid
erDiagram
    usuario ||--o{ resena : "escribe"
    producto ||--o{ resena : "recibe"
    negocio ||--o{ resena : "recibe"
    repartidor ||--o{ resena : "recibe"
    usuario ||--o{ reporte : "reporta"
    motivo_reporte ||--o{ reporte : "motivo"
    reporte ||--o{ sancion : "origina"
    usuario ||--o{ sancion : "recibe"
    negocio ||--o{ registro_comercio : "compras y ventas"
    pedido ||--o{ registro_comercio : "venta"

    resena {
        bigint id PK
        bigint autor_id FK
        enum tipo "producto, negocio, repartidor"
        bigint producto_id FK
        bigint negocio_id FK
        bigint repartidor_id FK
        tinyint estrellas "1 a 5"
        text comentario
        bool visible
    }
    reporte {
        bigint id PK
        bigint reportante_id FK
        enum tipo "producto, negocio, repartidor, usuario, resena"
        smallint motivo_id FK
        varchar descripcion
        enum estado "pendiente, en_revision, resuelto, descartado"
    }
    motivo_reporte {
        smallint id PK
        varchar nombre
        set aplica_a
        enum gravedad "baja, media, alta"
    }
    sancion {
        bigint id PK
        bigint usuario_id FK
        enum rol_afectado "cliente, repartidor, comerciante, todos"
        enum tipo "advertencia, suspension, bloqueo, retiro_producto"
        datetime termina_en "NULL = permanente"
    }
    registro_comercio {
        bigint id PK
        bigint negocio_id FK
        enum tipo "compra, venta, gasto, comision"
        bigint producto_id FK
        int cantidad
        decimal ingreso "calculado"
        decimal egreso "calculado"
        decimal ganancia "calculado"
        datetime fecha "UTC"
    }
```
