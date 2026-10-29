
# Etapa V – Triggers de auditoría

## 1. Definición y objetivo

### ¿Qué es un trigger?

Un **trigger** (disparador) es un procedimiento almacenado que el motor ejecuta **automáticamente** cuando ocurre un evento de modificación (`INSERT`, `UPDATE` o `DELETE`) sobre una tabla. Nadie lo invoca: se activa solo, sin que el usuario o la aplicación lo noten.

### Tipos de triggers DML en SQL Server

| Tipo | Cuándo se ejecuta | Uso típico |
|---|---|---|
| `AFTER` | Después de que la operación se realizó. | Auditoría y registro de cambios. |
| `INSTEAD OF` | **En lugar de** la operación: la sentencia original no se ejecuta. | Bloquear o reemplazar una operación. |

SQL Server no tiene triggers `BEFORE`. Existen además triggers DDL (ante `CREATE`, `ALTER`, `DROP`) y de inicio de sesión, que no se usan en este proyecto.

### Tablas especiales `inserted` y `deleted`

Dentro de un trigger, el motor crea dos tablas temporales con la misma estructura que la tabla afectada:

| Operación | `deleted` | `inserted` |
|---|---|---|
| `INSERT` | vacía | filas nuevas |
| `UPDATE` | valores **antes** del cambio | valores **después** del cambio |
| `DELETE` | filas borradas | vacía |

Un trigger se dispara **una vez por sentencia, no por fila**: si un `UPDATE` modifica 5 filas, `deleted` e `inserted` tienen 5 filas cada una. Por eso el código usa `INSERT ... SELECT` y no variables.

### Objetivo en este proyecto

1. **Auditar** los `UPDATE` y `DELETE` sobre la tabla `VENTA`, guardando en una tabla auxiliar los valores anteriores y nuevos, la fecha y hora, y el usuario de la base de datos que realizó la operación.
2. **Bloquear** el `DELETE` sobre la tabla `PRODUCTO`, emitiendo un mensaje y registrando el intento.

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aprovecha en el sistema |
|---|---|
| **Automatismo:** se ejecutan sin intervención. | Cada cambio queda registrado aunque se haga desde SSMS, una aplicación o un script. |
| **Trazabilidad:** permiten reconstruir el historial. | Responden quién cambió una venta, cuándo y qué valor tenía antes. |
| **Integridad:** protegen reglas que la estructura sola no puede imponer. | Impiden borrar productos del catálogo. |
| **Centralización:** la regla vive en la base de datos y no depende de cada programa. | Cualquier cliente que acceda a la base queda alcanzado por la misma auditoría. |
| **Disuasión:** saber que todo queda registrado desalienta modificaciones indebidas. | Los cambios sobre importes y estados de ventas son rastreables. |

**Aplicaciones habituales:** auditoría de cambios, control de operaciones prohibidas, validaciones complejas, mantenimiento de datos derivados y sincronización entre tablas.

---

## 3. Implementación en SQL Server

Scripts asociados:

| Script | Contenido |
|---|---|
| [`sql/tecnico/triggers/implementacion_triggers.sql`](../../sql/tecnico/triggers/implementacion_triggers.sql) | Tablas de auditoría y los tres triggers. |
| [`sql/tecnico/triggers/demostracion_triggers.sql`](../../sql/tecnico/triggers/demostracion_triggers.sql) | Casos de prueba. |

### Objetos creados

| Objeto | Tipo | Tabla | Función |
|---|---|---|---|
| `AUDITORIA_VENTA` | Tabla | – | Historial de `UPDATE` y `DELETE` sobre `VENTA`. |
| `AUDITORIA_INTENTOS_BORRADO` | Tabla | – | Registro de intentos de borrado bloqueados. |
| `t_update_venta` | Trigger `AFTER UPDATE` | `VENTA` | Registra valores anteriores y nuevos. |
| `t_delete_venta` | Trigger `AFTER DELETE` | `VENTA` | Registra los valores de la venta borrada. |
| `t_bloquear_delete_producto` | Trigger `INSTEAD OF DELETE` | `PRODUCTO` | Impide el borrado, avisa y registra el intento. |

### 3.1 Tablas auxiliares

```sql
CREATE TABLE AUDITORIA_VENTA
(
  id_auditoria          INT IDENTITY NOT NULL,
  accion                VARCHAR(60)   NOT NULL,
  id_venta              INT           NOT NULL,

  -- valores ANTES de la operación (tabla deleted)
  estado_anterior       VARCHAR(50)   NULL,
  domicilio_anterior    VARCHAR(150)  NULL,
  total_anterior        DECIMAL(10,2) NULL,
  fecha_venta_anterior  DATETIME      NULL,
  id_usuario_vendedor_anterior   INT           NULL,

  -- valores DESPUÉS de la operación (tabla inserted); NULL en un DELETE
  estado_nuevo                   VARCHAR(50)   NULL,
  domicilio_nuevo                VARCHAR(150)  NULL,
  total_nuevo                    DECIMAL(10,2) NULL,
  fecha_venta_nueva              DATETIME      NULL,
  id_usuario_vendedor_nuevo      INT           NULL,

  -- datos de la auditoría
  fecha_modificacion                 DATETIME      NOT NULL DEFAULT (GETDATE()),
  usuario_bd            VARCHAR(100)  NOT NULL DEFAULT (SUSER_SNAME()),

  CONSTRAINT PK_AUDITORIA_VENTA PRIMARY KEY (id_auditoria)
);
GO

CREATE TABLE AUDITORIA_INTENTOS_BORRADO
(
  id_intento   INT IDENTITY NOT NULL,
  tabla        VARCHAR(50)  NOT NULL,
  accion       VARCHAR(60)  NOT NULL,
  id_registro  INT          NOT NULL,
  fecha        DATETIME     NOT NULL DEFAULT (GETDATE()),
  usuario_bd   VARCHAR(100) NOT NULL DEFAULT (SUSER_SNAME()),
  CONSTRAINT PK_AUDITORIA_INTENTOS_BORRADO PRIMARY KEY (id_intento)
);
GO
```

| Elemento | Explicación |
|---|---|
| `GETDATE()` | Fecha y hora del servidor, en una sola columna `DATETIME`. |
| `SUSER_SNAME()` | Nombre del inicio de sesión (*login*) que ejecutó la operación. |
| Columnas `_nuevo` con `NULL` | En un `DELETE` no existe valor nuevo, por lo que quedan vacías. |
| Valores por defecto (`DEFAULT`) | La fecha y el usuario se completan solos; el trigger no necesita enviarlos. |

### 3.2 Trigger de auditoría para `UPDATE`

```sql
CREATE OR ALTER TRIGGER t_update_venta
ON VENTA
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_VENTA
        (accion, id_venta,
         estado_anterior, estado_nuevo,
         domicilio_anterior, domicilio_nuevo,
         total_anterior, total_nuevo,
         fecha_venta_anterior, fecha_venta_nueva,
         id_usuario_vendedor_anterior, id_usuario_vendedor_nuevo)
    SELECT 'UPDATE en la tabla VENTA', d.id_venta,
           d.estado,            i.estado,
           d.domicilio_entrega, i.domicilio_entrega,
           d.total,             i.total,
           d.fecha_venta,       i.fecha_venta,
           d.id_usuario,        i.id_usuario
    FROM deleted d
    INNER JOIN inserted i ON i.id_venta = d.id_venta
    WHERE d.estado            <> i.estado
       OR d.domicilio_entrega <> i.domicilio_entrega
       OR d.total             <> i.total
       OR d.fecha_venta       <> i.fecha_venta
       OR d.id_usuario        <> i.id_usuario;
END;
GO
```

| Elemento | Explicación |
|---|---|
| `AFTER UPDATE` | Se ejecuta cuando el `UPDATE` ya se realizó. |
| `SET NOCOUNT ON` | Evita mensajes de "filas afectadas" adicionales generados por el trigger. |
| `deleted d` / `inserted i` | Valores anteriores y nuevos de las filas modificadas. |
| `INNER JOIN ... ON i.id_venta = d.id_venta` | Empareja cada fila vieja con su fila nueva (`id_venta` es `IDENTITY` y no cambia). |
| `WHERE d.x <> i.x OR ...` | Audita solo si **algún valor realmente cambió**, evitando filas inútiles cuando un `UPDATE` reescribe los mismos valores. |

### 3.3 Trigger de auditoría para `DELETE`

```sql
CREATE OR ALTER TRIGGER t_delete_venta
ON VENTA
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_VENTA
        (accion, id_venta,
         estado_anterior, domicilio_anterior, total_anterior,
         fecha_venta_anterior, id_usuario_vendedor_anterior)
    SELECT 'DELETE en la tabla VENTA', d.id_venta,
           d.estado, d.domicilio_entrega, d.total,
           d.fecha_venta, d.id_usuario
    FROM deleted d;
END;
GO
```

Guarda los valores de la venta borrada. Los campos `_nuevo` no se completan y quedan en `NULL`.

### 3.4 Trigger que bloquea el `DELETE` en `PRODUCTO`

```sql
CREATE OR ALTER TRIGGER t_bloquear_delete_producto
ON PRODUCTO
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_INTENTOS_BORRADO (tabla, accion, id_registro)
    SELECT 'PRODUCTO', 'Intento de DELETE bloqueado', d.id_producto
    FROM deleted d;

    RAISERROR('No se permite eliminar productos. Use la baja lógica (estado = 0).', 16, 1);
END;
GO
```

| Elemento | Explicación |
|---|---|
| `INSTEAD OF DELETE` | Reemplaza al `DELETE`: el borrado **nunca se ejecuta**, por lo que no hace falta `ROLLBACK`. |
| `INSERT ... FROM deleted` | En un `INSTEAD OF`, `deleted` contiene las filas que se **habrían** borrado; se usa para registrar el intento. |
| `RAISERROR(..., 16, 1)` | Emite el mensaje de error al usuario. Va después del `INSERT` para que el registro del intento quede guardado. |

---

## 4. Caso concreto aplicado al sistema de ventas

### ¿Por qué auditar `VENTA`?

`VENTA` es el registro central de las operaciones comerciales y sus cambios son poco frecuentes (casi siempre un cambio de estado), por lo que el historial resulta legible.

| Dato de `VENTA` | Pregunta de negocio que la auditoría responde |
|---|---|
| `estado` | ¿Quién canceló o marcó como entregada una venta, y cuándo? ¿En qué estado estaba antes? |
| `total` | ¿Alguien modificó el importe de una venta ya registrada? ¿Cuál era el valor original? |
| `domicilio_entrega` | ¿Cambió el domicilio después de la compra? ¿Cuál era el original? |

Esto se vincula con la regla de negocio de **historial de precios e importes**: lo ya vendido no debería cambiar retroactivamente y, si cambia, debe quedar rastro.

### ¿Por qué bloquear el borrado en `PRODUCTO`?

Los productos están referenciados por el detalle de las ventas realizadas. El sistema contempla la **baja lógica** (`estado = 0`) para retirarlos del catálogo sin perder el historial, por lo que el borrado físico se impide y el mensaje indica el camino correcto.

### ¿Por qué el bloqueo está en otra tabla?

Si el `INSTEAD OF DELETE` estuviera sobre `VENTA`, el borrado nunca se ejecutaría y el trigger de auditoría `AFTER DELETE` de esa tabla no se dispararía jamás. Separar ambas responsabilidades permite demostrar los dos mecanismos.

### ¿Por qué dos tablas auxiliares?

| Tabla | Responde a |
|---|---|
| `AUDITORIA_VENTA` | ¿Cómo era el registro antes del cambio y cómo quedó? |
| `AUDITORIA_INTENTOS_BORRADO` | ¿Quién intentó borrar y cuándo? (el registro no cambió, por lo que no hay valores anteriores que guardar) |

---

## 5. Demostración y resultados

Las pruebas se ejecutan sobre **tres ventas de prueba** creadas por el propio script (domicilio `PRUEBA AUDITORIA ...`), de modo de no alterar las ventas 1 a 10, de las que dependen las consultas de la Etapa IV. Script completo: Script completo: [`demostracion_triggers.sql`](../../sql/tecnico/triggers/demostracion_triggers.sql).

> Los `id_venta` de los resultados (11, 12 y 13) corresponden a una base recién cargada con el script de datos de prueba. Pueden variar si se insertaron ventas adicionales. Las columnas `fecha` y `usuario_bd` dependen del momento y del usuario que ejecute las pruebas.

### 5.0 Preparación

**Verificación de los triggers creados**

```sql
SELECT t.name                    AS trigger_nombre,
       OBJECT_NAME(t.parent_id)  AS tabla,
       CASE WHEN t.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS tipo,
       t.is_disabled             AS deshabilitado
FROM sys.triggers t
WHERE t.name IN ('t_update_venta', 't_delete_venta', 'trg_bloquear_delete_producto');
```

**Resultado esperado:**
> <img width="428" height="86" alt="image" src="https://github.com/user-attachments/assets/882ea8cd-a2c5-4f03-ab5a-bbaf920710a4" />


**Ventas de prueba**

```sql
INSERT INTO VENTA (domicilio_entrega, total, id_usuario)
VALUES ('PRUEBA AUDITORIA 1', 1000.00, 2),
       ('PRUEBA AUDITORIA 2', 2000.00, 3),
       ('PRUEBA AUDITORIA 3', 3000.00, 4);

SELECT id_venta, estado, domicilio_entrega, total
FROM VENTA WHERE domicilio_entrega LIKE 'PRUEBA AUDITORIA%';

SELECT COUNT(*) AS filas_auditoria FROM AUDITORIA_VENTA;
```
`filas_auditoria` = **0**: los `INSERT` no se auditan, solo los `UPDATE` y `DELETE`.

 **Resultado esperado:**
> <img width="352" height="174" alt="image" src="https://github.com/user-attachments/assets/b057f910-41d8-4cf9-b535-8a644fe90b73" />




---

### Caso 1 – `UPDATE` de una columna (cambio de estado)

```sql
UPDATE VENTA
SET estado = 'Entregado'
WHERE domicilio_entrega = 'PRUEBA AUDITORIA 1';

SELECT TOP (1) id_auditoria, accion, id_venta,
       estado_anterior, estado_nuevo, total_anterior, total_nuevo,
       domicilio_anterior, domicilio_nuevo, fecha_modificacion, usuario_bd
FROM AUDITORIA_VENTA
ORDER BY id_auditoria DESC;
```

**Resultado esperado:**
> <img width="898" height="50" alt="image" src="https://github.com/user-attachments/assets/60840d53-5275-49e5-870b-fce7dea3a53b" />

**Qué demuestra:** el trigger registra el valor que tenía el estado antes del cambio y el nuevo, sin que el usuario haya hecho nada adicional.

---

### Caso 2 – `DELETE` de una venta

```sql
DELETE FROM VENTA
WHERE domicilio_entrega = 'PRUEBA AUDITORIA 3';

SELECT TOP (1) id_auditoria, accion, id_venta,
       estado_anterior, estado_nuevo, total_anterior, total_nuevo,
       domicilio_anterior, domicilio_nuevo, fecha_modificacion, usuario_bd
FROM AUDITORIA_VENTA
ORDER BY id_auditoria DESC;
```

**Resultado esperado:**
> <img width="997" height="47" alt="image" src="https://github.com/user-attachments/assets/40c56c68-c01b-4f84-bffc-0fb5be1ce712" />


**Qué demuestra:** aunque la venta ya no existe en `VENTA`, sus valores quedan guardados en la auditoría. Los valores "nuevos" son `NULL` porque tras un borrado no hay estado posterior.

---

### Caso 3 – Intento de `DELETE` sobre `PRODUCTO`

```sql
DELETE FROM PRODUCTO WHERE id_producto = 8;
```

**Resultado esperado (pestaña "Mensajes"):**
> <img width="828" height="36" alt="image" src="https://github.com/user-attachments/assets/c76bc4f9-f1ee-452d-ab39-018049b02350" />


**Verificación de que no se borró nada y de que el intento quedó registrado:**

```sql
SELECT COUNT(*) AS cantidad_productos FROM PRODUCTO;

SELECT id_intento, tabla, accion, id_registro, fecha, usuario_bd
FROM AUDITORIA_INTENTOS_BORRADO;
```
**Resultado esperado:**
> <img width="704" height="172" alt="image" src="https://github.com/user-attachments/assets/9a5dc4d9-03b4-4128-baf3-1eec51e60b19" />


**Qué demuestra:** la operación se impide (siguen los 10 productos), el usuario recibe el mensaje y el intento queda registrado con fecha y usuario.

---

## 6. Conclusiones

1. **Control y trazabilidad automáticos.** Los triggers registran los cambios sin depender de que cada usuario o aplicación lo haga. En las pruebas, el `UPDATE` (caso 1) y el `DELETE` (caso 2) sobre `VENTA` dejaron una fila con los valores anteriores y nuevos, la fecha y hora, y el usuario de la base de datos.

2. **Detección de modificaciones indebidas.** Si un usuario con malas intenciones modificara datos para beneficio propio o de terceros (por ejemplo, el importe o el estado de una venta), el cambio quedaría registrado con el valor original. Esto permite analizar lo ocurrido, identificar el inicio de sesión responsable y tomar las medidas que correspondan, y cumple además una función disuasiva. Para poder responsabilizar a una persona, cada usuario debe tener su propio inicio de sesión.

3. **Los datos auditados sobreviven al dato original.** Tras el `DELETE` del caso 2, la venta ya no existía en `VENTA`, pero sus valores quedaron guardados en `AUDITORIA_VENTA`.

4. **Protección de la integridad.** El trigger `INSTEAD OF DELETE` impidió borrar el producto (caso 3), que sigue figurando en ventas históricas, y dejó constancia del intento con fecha y usuario.

5. **Limitaciones.** Un trigger `AFTER` registra pero no impide el cambio; solo el `INSTEAD OF` puede evitar una operación. Además, quien tenga permisos suficientes podría deshabilitar el trigger o modificar la tabla de auditoría, por lo que esas tablas deben quedar accesibles solo para el administrador (tema Seguridad).

---
