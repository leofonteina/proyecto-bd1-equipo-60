# Etapa V – Manejo de transacciones

## 1. Definición y objetivo

### ¿Qué es una transacción?

Una **transacción** es un conjunto de operaciones SQL que el motor ejecuta como **una sola unidad de trabajo**: o se realizan **todas**, o no se realiza **ninguna**. Si algo falla a mitad de camino, la base de datos vuelve al estado que tenía antes de empezar.

| Sentencia | Qué hace |
|---|---|
| `BEGIN TRANSACTION` | Inicia la transacción. Desde acá los cambios son provisorios. |
| `COMMIT TRANSACTION` | **Confirma** la transacción: los cambios se guardan de forma permanente. |
| `ROLLBACK TRANSACTION` | **Deshace** todos los cambios realizados desde el `BEGIN TRANSACTION`. |
| `BEGIN TRY ... BEGIN CATCH` | Captura errores y permite reaccionar (por ejemplo, haciendo `ROLLBACK`). |

### Propiedades ACID

| Propiedad | Significado | Cómo se cumple en este proyecto |
|---|---|---|
| **A**tomicidad | Todo o nada. | Si una regla no se cumple o hay un error, se lanza un error y el `ROLLBACK` deshace lo hecho. |
| **C**onsistencia | La base pasa de un estado válido a otro válido. | Se respetan los `CHECK`, `FOREIGN KEY` y `UNIQUE`; el stock nunca queda negativo. |
| **A**islamiento | Una transacción no interfiere con otra en curso. | `READ COMMITTED` (nivel por defecto) más `UPDLOCK`, que bloquea la fila mientras dura la transacción. |
| **D**urabilidad | Lo confirmado no se pierde. | `COMMIT TRANSACTION` guarda los cambios de forma permanente. |

### Objetivo en este proyecto

1. **Registrar una venta completa** (encabezado, detalle, pago y descuento de stock), con uno o varios productos, como una operación indivisible.
2. **Cancelar una venta** cambiando su estado y devolviendo el stock, también de forma indivisible.
3. **Validar las reglas de negocio antes de modificar datos** y cancelar toda la operación, con un error claro, si alguna no se cumple.

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aprovecha en el sistema |
|---|---|
| **Integridad:** evita datos a medias. | Nunca queda una venta sin detalle ni un detalle sin pago. |
| **Consistencia del stock** | Se descuenta al vender y se devuelve al cancelar, siempre en la misma transacción. |
| **Recuperación ante errores** | Ante cualquier falla, `XACT_ABORT` y el bloque `CATCH` hacen `ROLLBACK` y reenvían el error original. |
| **Reglas centralizadas** | Las reglas viven en la base y se aplican desde cualquier aplicación. |
| **Usuario confiable** | El usuario sale de la sesión (`SESSION_CONTEXT`) y no de un parámetro que la aplicación podría falsear. |
| **Concurrencia segura** | Con `UPDLOCK`, dos sesiones no pueden vender o cancelar lo mismo a la vez. |

**Aplicaciones habituales:** ventas, transferencias bancarias, reservas, movimientos de inventario, cancelaciones y devoluciones.

---

## 3. Implementación en SQL Server

| Script | Contenido |
|---|---|
| [`sql/tecnico/transacciones/implementacion_transacciones.sql`](../../sql/tecnico/transacciones/implementacion_transacciones.sql) | Tipo de tabla y procedimientos almacenados. |
| [`sql/tecnico/transacciones/demostracion_transacciones.sql`](../../sql/tecnico/transacciones/demostracion_transacciones.sql) | Casos de prueba. |

### Objetos creados y utilizados

| Objeto | Tipo | Función |
|---|---|---|
| `sp_RegistrarVenta` | Procedimiento | Registra una venta con uno o varios productos. |
| `sp_CancelarVenta` | Procedimiento | Cancela una venta pendiente y devuelve el stock. |
| `tipo_item_venta` | Tipo de tabla | Lista de `id_producto` y `cantidad` que recibe `sp_RegistrarVenta`. |
| `fn_CalcularImporteConDescuento` | Función (etapa de funciones) | Aplica al total el descuento del método de pago. |
| `fn_PorcentajeDescuentoMetodoPago` | Función (etapa de funciones) | Devuelve el descuento del método de pago; la usa la anterior. |
| `fn_EstadoStockProducto` | Función (etapa de funciones) | Diagnóstico de stock de un producto; se usa para avisar los productos a reponer. |

### Reglas de negocio implementadas

| Código | Regla |
|---|---|
| **RN.01** | No se puede vender más cantidad que el stock disponible. |
| **RN.02** | Al registrar una venta se descuenta el stock del producto. |
| **RT.01** | Una venta ya cancelada no puede cancelarse de nuevo (evita devolver el stock dos veces). |
| **RT.02** | Al cancelar una venta se devuelve el stock de todos sus productos. |
| **RT.03** | Solo compran usuarios identificados en la sesión, existentes y activos. |
| **RT.04** | Solo se pueden vender productos existentes y activos (no discontinuados). |
| **RT.05** | Datos válidos: domicilio informado, cantidades mayores a 0 y dentro del límite, y método de pago existente. |
| **RT.06** | Una venta con varios productos se registra completa o no se registra; los productos repetidos se suman en una sola línea. |
| **RT.07** | Solo el usuario que realizó la venta puede cancelarla. |
| **RT.08** | Solo se pueden cancelar ventas pendientes. |
| **RT.09** | El importe de la venta incluye el descuento del método de pago. |

> Las reglas `RT.xx` (reglas de transacciones) son las incorporadas en esta etapa.

### 3.1 Identificación del usuario

Los procedimientos no reciben el usuario como parámetro: lo leen de `SESSION_CONTEXT`, un valor que la aplicación guarda en la conexión al iniciar sesión y que dura lo que dure esa conexión.

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;
```

Si el valor no está o no es un número, el procedimiento lanza un error y no hace nada.

### 3.2 Registrar una venta

**Parámetros:** `@domicilio_entrega`, `@id_metodo_pago`, `@items` (lista de productos y cantidades) y `@id_venta` (**salida**: el id de la venta creada).

```sql
CREATE TYPE dbo.tipo_item_venta AS TABLE
(
    id_producto INT NOT NULL,
    cantidad INT NOT NULL
);
GO
```

```sql
CREATE PROCEDURE dbo.sp_RegistrarVenta
    @domicilio_entrega VARCHAR(150),
    @id_metodo_pago INT,
    @items dbo.tipo_item_venta READONLY,
    @id_venta INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- ante un error cancela automaticamente toda la transaccion

    SET @id_venta = NULL;

    BEGIN TRY

        BEGIN TRANSACTION;

        DECLARE @id_usuario INT;

        -- SESSION_CONTEXT lee el valor guardado en la sesion y TRY_CONVERT lo pasa a INT (devuelve NULL si no puede)
        SET @id_usuario =
            TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'));

        IF @id_usuario IS NULL
        BEGIN
            -- THROW lanza un error con numero, mensaje y estado, y salta al CATCH
            THROW 50001,
                'No se pudo identificar al usuario de la sesion.',
                1;
        END;

        DECLARE @estado_usuario INT;
        DECLARE @total DECIMAL(10,2);
        DECLARE @importe_final DECIMAL(10,2);
        DECLARE @cantidad_productos INT;

        -- LTRIM y RTRIM sacan los espacios de los costados para detectar un domicilio vacio
        IF @domicilio_entrega IS NULL
           OR LTRIM(RTRIM(@domicilio_entrega)) = ''
        BEGIN
            THROW 50002,
                'El domicilio de entrega es obligatorio.',
                1;
        END;

        IF NOT EXISTS (SELECT 1 FROM @items)
        BEGIN
            THROW 50003,
                'La venta debe incluir al menos un producto.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @items
            WHERE cantidad <= 0
        )
        BEGIN
            THROW 50004,
                'Todas las cantidades deben ser mayores a cero.',
                1;
        END;

        SELECT @estado_usuario = estado
        FROM dbo.USUARIO
        WHERE id_usuario = @id_usuario;

        IF @estado_usuario IS NULL
        BEGIN
            THROW 50005,
                'El usuario no existe.',
                1;
        END;

        IF @estado_usuario = 0
        BEGIN
            THROW 50006,
                'El usuario se encuentra dado de baja.',
                1;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.METODO_PAGO
            WHERE id_metodo_pago = @id_metodo_pago
        )
        BEGIN
            THROW 50007,
                'El metodo de pago no existe.',
                1;
        END;

        DECLARE @lineas TABLE
        (
            id_producto INT PRIMARY KEY,
            cantidad BIGINT NOT NULL,
            precio DECIMAL(10,2) NULL,
            stock INT NULL,
            estado INT NULL
        );

        -- SUM suma las cantidades por producto y CONVERT las pasa a BIGINT para evitar un desborde
        IF EXISTS
        (
            SELECT id_producto
            FROM @items
            GROUP BY id_producto
            HAVING SUM(CONVERT(BIGINT, cantidad)) > 2147483647
        )
        BEGIN
            THROW 50008,
                'La cantidad total de un producto supera el limite permitido.',
                1;
        END;

        INSERT INTO @lineas (id_producto, cantidad)
        SELECT
            id_producto,
            SUM(CONVERT(BIGINT, cantidad))
        FROM @items
        GROUP BY id_producto;

        -- COUNT cuenta cuantos productos distintos tiene la venta
        SELECT @cantidad_productos = COUNT(*)
        FROM @lineas;

        -- UPDLOCK y ROWLOCK bloquean las filas de PRODUCTO hasta terminar la transaccion
        UPDATE l
        SET
            l.precio = p.precio,
            l.stock = p.stock,
            l.estado = p.estado
        FROM @lineas AS l
        INNER JOIN dbo.PRODUCTO AS p
            WITH (UPDLOCK, ROWLOCK)
            ON p.id_producto = l.id_producto;

        IF EXISTS
        (
            SELECT 1
            FROM @lineas
            WHERE estado IS NULL
        )
        BEGIN
            THROW 50009,
                'Uno o mas productos no existen.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @lineas
            WHERE estado = 0
        )
        BEGIN
            THROW 50010,
                'Uno o mas productos se encuentran discontinuados.',
                1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM @lineas
            WHERE stock < cantidad
        )
        BEGIN
            THROW 50011,
                'Stock insuficiente para uno o mas productos.',
                1;
        END;

        SELECT @total =
            SUM(CONVERT(DECIMAL(10,2), cantidad) * precio)
        FROM @lineas;

        -- fn_CalcularImporteConDescuento aplica al total el descuento del metodo de pago (usa fn_PorcentajeDescuentoMetodoPago)
        SET @importe_final = dbo.fn_CalcularImporteConDescuento(@total, @id_metodo_pago);

        INSERT INTO dbo.VENTA
        (
            domicilio_entrega,
            total,
            id_usuario
        )
        VALUES
        (
            @domicilio_entrega,
            @importe_final,
            @id_usuario
        );

        -- SCOPE_IDENTITY devuelve el ultimo id generado por el IDENTITY en este procedimiento
        SET @id_venta = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.VENTA_DETALLE
        (
            cantidad,
            precio_unitario,
            subtotal,
            id_producto,
            id_venta
        )
        SELECT
            CONVERT(INT, cantidad),
            precio,
            CONVERT(DECIMAL(10,2), cantidad * precio),
            id_producto,
            @id_venta
        FROM @lineas;

        INSERT INTO dbo.VENTA_PAGO
        (
            monto,
            id_venta,
            id_metodo_pago
        )
        VALUES
        (
            @importe_final,
            @id_venta,
            @id_metodo_pago
        );

        UPDATE p
        SET p.stock = p.stock - CONVERT(INT, l.cantidad)
        FROM dbo.PRODUCTO AS p
        INNER JOIN @lineas AS l
            ON l.id_producto = p.id_producto;

        COMMIT TRANSACTION;

        SELECT
            @id_venta AS id_venta,
            @importe_final AS total,
            @cantidad_productos AS cantidad_productos,
            'Venta registrada correctamente.' AS mensaje;

        -- fn_EstadoStockProducto devuelve el diagnostico de stock del producto, se usa para avisar los que quedaron para reponer
        SELECT
            p.id_producto,
            p.nombre,
            p.stock,
            dbo.fn_EstadoStockProducto(p.id_producto) AS estado_stock
        FROM dbo.PRODUCTO AS p
        INNER JOIN @lineas AS l
            ON l.id_producto = p.id_producto
        WHERE dbo.fn_EstadoStockProducto(p.id_producto)
            IN ('Stock Crítico (Reponer)', 'Sin Stock');

    END TRY

    BEGIN CATCH

        -- XACT_STATE devuelve distinto de 0 si hay una transaccion abierta que se puede deshacer
        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @id_venta = NULL;

        -- THROW sin parametros vuelve a lanzar el error original
        THROW;

    END CATCH;
END;
GO
```

**Ejemplo de llamada:**

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 1), (5, 2), (6, 1);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Sarmiento 789, Rosario',
    @id_metodo_pago = 4,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
```

**Resultado de la llamada.** Primero un resultado con `id_venta`, `total`, `cantidad_productos` y el mensaje `Venta registrada correctamente.`; después, solo si hay productos para reponer, una lista con su stock y su `estado_stock`.

**Validaciones (en orden).** Se hacen **antes de insertar** y, si una falla, se lanza el error indicado y se deshace todo.

| Orden | Error | Validación | Regla | Mensaje |
|---|---|---|---|---|
| 1 | 50001 | Usuario identificado en la sesión | RT.03 | No se pudo identificar al usuario de la sesion. |
| 2 | 50002 | Domicilio informado | RT.05 | El domicilio de entrega es obligatorio. |
| 3 | 50003 | Lista de productos no vacía | RT.06 | La venta debe incluir al menos un producto. |
| 4 | 50004 | Cantidades mayores a 0 | RT.05 | Todas las cantidades deben ser mayores a cero. |
| 5 | 50005 | El usuario existe | RT.03 | El usuario no existe. |
| 6 | 50006 | El usuario está activo | RT.03 | El usuario se encuentra dado de baja. |
| 7 | 50007 | El método de pago existe | RT.05 | El metodo de pago no existe. |
| 8 | 50008 | Cantidad total por producto dentro del límite | RT.05 | La cantidad total de un producto supera el limite permitido. |
| 9 | 50009 | Los productos existen | RT.04 | Uno o mas productos no existen. |
| 10 | 50010 | Los productos están activos | RT.04 | Uno o mas productos se encuentran discontinuados. |
| 11 | 50011 | Stock suficiente | RN.01 | Stock insuficiente para uno o mas productos. |

**Flujo:**

```
BEGIN TRANSACTION
  │
  ▼
Validaciones 1 a 11 ── alguna falla ──► THROW ──► CATCH ──► ROLLBACK + error (sin cambios)
  │
  ▼
Consolidar productos repetidos → leer precio, stock y estado (UPDLOCK) → calcular total y aplicar descuento
  │
  ▼
INSERT en VENTA → INSERT en VENTA_DETALLE → INSERT en VENTA_PAGO → UPDATE de stock
  │
  ▼
COMMIT TRANSACTION ──► resultado "Venta registrada correctamente."

Cualquier otro error SQL ──► CATCH ──► ROLLBACK + el error original
```

### 3.3 Cancelar una venta

**Parámetro:** `@id_venta`. El usuario sale de `SESSION_CONTEXT`.

```sql
CREATE PROCEDURE dbo.sp_CancelarVenta
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        DECLARE @id_usuario INT;

        SET @id_usuario =
            TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'));

        IF @id_usuario IS NULL
        BEGIN
            THROW 50020,
                'No se pudo identificar al usuario de la sesion.',
                1;
        END;

        DECLARE @id_propietario INT;
        DECLARE @estado VARCHAR(50);

        SELECT
            @id_propietario = id_usuario,
            @estado = estado
        FROM dbo.VENTA WITH (UPDLOCK, ROWLOCK)
        WHERE id_venta = @id_venta;

        IF @id_propietario IS NULL
        BEGIN
            THROW 50021,
                'La venta indicada no existe.',
                1;
        END;

        IF @id_propietario <> @id_usuario
        BEGIN
            THROW 50022,
                'No tiene permisos para cancelar esta venta.',
                1;
        END;

        IF @estado = 'Cancelado'
        BEGIN
            THROW 50023,
                'La venta ya se encuentra cancelada.',
                1;
        END;

        IF @estado <> 'Pendiente'
        BEGIN
            THROW 50024,
                'Solo se pueden cancelar ventas pendientes.',
                1;
        END;

        -- SUM con GROUP BY agrupa la cantidad vendida por producto para devolverla al stock
        UPDATE p
        SET p.stock = p.stock + d.cantidad_total
        FROM dbo.PRODUCTO AS p
        INNER JOIN
        (
            SELECT
                id_producto,
                SUM(cantidad) AS cantidad_total
            FROM dbo.VENTA_DETALLE
            WHERE id_venta = @id_venta
            GROUP BY id_producto
        ) AS d
            ON d.id_producto = p.id_producto;

        UPDATE dbo.VENTA
        SET estado = 'Cancelado'
        WHERE id_venta = @id_venta;

        COMMIT TRANSACTION;

        SELECT
            @id_venta AS id_venta,
            'Venta cancelada y stock repuesto correctamente.'
                AS mensaje;

    END TRY

    BEGIN CATCH

        IF XACT_STATE() <> 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        THROW;

    END CATCH;
END;
GO
```

**Validaciones (en orden):**

| Orden | Error | Validación | Regla | Mensaje |
|---|---|---|---|---|
| 1 | 50020 | Usuario identificado en la sesión | RT.03 | No se pudo identificar al usuario de la sesion. |
| 2 | 50021 | La venta existe | – | La venta indicada no existe. |
| 3 | 50022 | La venta es del usuario de la sesión | RT.07 | No tiene permisos para cancelar esta venta. |
| 4 | 50023 | La venta no está ya cancelada | RT.01 | La venta ya se encuentra cancelada. |
| 5 | 50024 | La venta está pendiente | RT.08 | Solo se pueden cancelar ventas pendientes. |

**Flujo:** `BEGIN TRANSACTION` → leer dueño y estado de la venta con `UPDLOCK` → validaciones 1 a 5 (si falla alguna, error y `ROLLBACK`) → devolver el stock (`UPDATE` de `PRODUCTO`) → pasar la venta a `Cancelado` (`UPDATE` de `VENTA`) → `COMMIT` → resultado `Venta cancelada y stock repuesto correctamente.`

### 3.4 Elementos principales

| Elemento | Explicación |
|---|---|
| `SESSION_CONTEXT` y `TRY_CONVERT` | Leen el usuario guardado en la sesión y lo pasan a `INT` (devuelve `NULL` si no puede). |
| `SET XACT_ABORT ON` | Ante un error cancela automáticamente toda la transacción. |
| `THROW` | Lanza un error con número, mensaje y estado, y salta al `CATCH`. En el `CATCH`, sin parámetros, reenvía el error original. |
| `XACT_STATE()` | Distinto de 0 si hay una transacción abierta que se puede deshacer; el `CATCH` hace `ROLLBACK` solo en ese caso. |
| `OUTPUT` | Parámetro de salida: devuelve a quien llama el `id_venta` creado. |
| `WITH (UPDLOCK, ROWLOCK)` | Bloquea las filas leídas hasta el final de la transacción, para que otra sesión no las modifique al mismo tiempo. |
| `SCOPE_IDENTITY()` | Devuelve el `id_venta` recién generado, para vincular detalle y pago. |
| `CREATE TYPE ... AS TABLE` y `READONLY` | Permiten enviar una lista de productos como parámetro (solo lectura dentro del procedimiento). |
| `SUM(...) ... GROUP BY` | Suma unidades por producto: consolida repetidos al vender y agrupa lo vendido al cancelar. |
| `UPDATE p ... FROM ... INNER JOIN` | Actualiza el stock de varios productos en una sola sentencia. |

---

## 4. Caso concreto aplicado al sistema de ventas

- **Por qué una transacción.** Registrar una venta modifica cuatro tablas (`VENTA`, `VENTA_DETALLE`, `VENTA_PAGO` y `PRODUCTO`). Sin transacción, un error a mitad de camino dejaría una venta sin pago o con el stock sin descontar. Cancelar modifica dos (`PRODUCTO` y `VENTA`): si solo cambiara el estado, el stock quedaría sin devolver. En los datos de prueba originales eso se hacía a mano (venta 5 cancelada y dos `UPDATE` para el stock de los productos 8 y 9).
- **Por qué se valida antes de insertar y se lanza un error.** Ante un dato inválido no se consume ni un número de `IDENTITY` y la aplicación recibe una excepción con número y mensaje (50001 a 50011 al vender, 50020 a 50024 al cancelar), en lugar de un texto que podría pasar inadvertido. Los `CHECK` y `FOREIGN KEY` quedan como segunda línea de defensa.
- **Por qué `UPDLOCK`.** Sin bloqueo, dos sesiones podrían vender más stock del que hay o cancelar la misma venta dos veces, devolviendo el stock duplicado. Con `UPDLOCK` la segunda espera a la primera y se detiene por RN.01 o RT.01 (caso 16).
- **Por qué solo el dueño cancela y solo ventas pendientes.** El usuario sale de la sesión, así que nadie puede cancelar la venta de otro. Una venta entregada ya no se puede cancelar porque el producto salió del negocio.
- **Por qué baja lógica.** Cancelar cambia el `estado` y no elimina la venta: se conserva el historial. `VENTA_PAGO` no tiene estado, por lo que el pago queda registrado.
- **Por qué un tipo de tabla.** Una venta real tiene varias líneas (la venta 1 tiene 3 productos) y un procedimiento no puede recibir una cantidad variable de parámetros. Si un solo producto falla, no se registra ninguno.
- **Descuento por método de pago.** `VENTA.total` y `VENTA_PAGO.monto` guardan el importe con el descuento (`fn_CalcularImporteConDescuento`), mientras que los subtotales de `VENTA_DETALLE` son los precios sin descuento. Por eso el total puede ser menor que la suma de los subtotales.
- **Ventas nuevas en estado `Pendiente`.** `VENTA` tiene `Pendiente` como valor por defecto; recién una venta pendiente se puede cancelar.
- **Transacciones anidadas.** Si un procedimiento se ejecuta dentro de otra transacción, su `COMMIT` solo baja `@@TRANCOUNT`; los cambios se confirman con el `COMMIT` externo. Un error o un `ROLLBACK` deshace todo.
- **Triggers de auditoría.** Si el trigger sobre `VENTA` está creado, cada cancelación queda registrada en `AUDITORIA_VENTA` con el estado anterior y el nuevo.

---

## 5. Demostración y resultados

Script completo: [`demostracion_transacciones.sql`](../../sql/tecnico/transacciones/demostracion_transacciones.sql).

> Los casos se ejecutan **en orden**, sobre una base recién cargada con los datos de prueba y con las funciones de la etapa creadas. Los `id_venta` (11 a 13) pueden variar si se insertaron ventas adicionales (por ejemplo, con la demostración de triggers).
>
> Cada caso fija el usuario con `sp_set_session_context`. Los errores se ven en rojo en la pestaña **Mensajes**, con su número, por ejemplo `Mens. 50011, Nivel 16, Estado 1, Procedimiento sp_RegistrarVenta ... Stock insuficiente para uno o mas productos.` Como el error aborta el lote, la verificación se ejecuta en un lote aparte.

### 5.0 Situación inicial

```sql
SELECT id_producto, nombre, stock 
FROM PRODUCTO 
WHERE id_producto IN (1, 3);

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
```

| id_producto | nombre | stock |
|---|---|---|
| 1 | Ryzen 5 5600 | 14 |
| 3 | RTX 3060 12GB | 4 |

El stock inicial de los datos de prueba era 15 y 5 unidades, y se descontó 1 de cada uno por las ventas 1 y 2 cargadas en el script.

> **Captura 1:** stock inicial de los productos 1 y 3 y última venta registrada.
> <img width="1201" height="411" alt="image" src="https://github.com/user-attachments/assets/0b5242de-394c-4527-b597-534504a2fe88" />
> <img width="582" height="217" alt="image" src="https://github.com/user-attachments/assets/87c1980f-809a-4d70-ba43-620547d54b39" />


**Datos de referencia de los casos siguientes:**
- **Stock inicial:** P1=14, P2=7, P3=4, P5=12, P6=23, P8=27.
- **Producto discontinuado:** 8. **Usuario dado de baja:** 6.
- **Ventas:** `Pendiente` 10 (usuario 2); `Entregado` 1 (usuario 2).
- **Métodos de pago:** 1 Efectivo, 2 Débito, 4 Mercado Pago.

---

### Parte A – Registrar una venta (`sp_RegistrarVenta`)

#### Caso 1 – Venta correcta (stock suficiente)

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 2);   -- Ryzen 5 5600

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,    -- Efectivo
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
```

**Resultado esperado de la llamada:** `id_venta = 11`, `cantidad_productos = 1` y `Venta registrada correctamente.`

> **Captura 2:** resultado de la llamada.

> <img width="627" height="272" alt="image" src="https://github.com/user-attachments/assets/358dd444-d8cf-4708-b50e-55224a9fcd5f" />


**Verificación:**

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
```

| Tabla | Resultado esperado |
|---|---|
| `VENTA` | Nueva fila: `id_venta = 11`, estado **`Pendiente`**, usuario 2, `total` = `440000.00` menos el descuento del método de pago. |
| `VENTA_DETALLE` | Nueva fila: cantidad `2`, precio unitario `220000.00`, subtotal `440000.00`, producto 1, venta 11. |
| `VENTA_PAGO` | Nueva fila: monto igual al `total` de la venta, venta 11, método 1 (Efectivo). |
| `PRODUCTO` (id 1) | Stock baja de **14 a 12**. |

> **Captura 3:** las cuatro consultas de verificación.
> <img width="862" height="415" alt="image" src="https://github.com/user-attachments/assets/2247a626-8702-493a-9c48-0cf2cc082d80" />


**Qué demuestra:** las cuatro tablas se modificaron de forma coordinada y se confirmaron juntas con `COMMIT`. El usuario se tomó de la sesión y la venta quedó `Pendiente`.

#### Casos 2 a 6 – Stock y validaciones

Todos usan `sp_RegistrarVenta`; se indica solo lo que cambia. "Sin cambios" significa que no se modificó ninguna tabla.

| Caso | Qué cambia | Resultado esperado |
|---|---|---|
| 2 | Usuario 3, producto 3 × 10 (solo hay 4) | **Error 50011** (stock insuficiente). Sin cambios: la última venta sigue siendo la 11 y el producto 3 sigue en 4. |
| 3 | Sesión **sin usuario** (`@value = NULL`) | **Error 50001**. Sin cambios. |
| 4 | Usuario **6** (dado de baja) | **Error 50006**. Sin cambios. |
| 5 | Producto **8** (discontinuado) | **Error 50010**. Sin cambios. |
| 6 | Cantidad **0** | **Error 50004**. Sin cambios. |

Tras los casos 3 a 6 la última venta sigue siendo la **11** y los productos 1 y 8 siguen en **12** y **27**.

> **Captura 4:** caso 2: error y verificación.
> <img width="871" height="261" alt="image" src="https://github.com/user-attachments/assets/59f99eac-0fbb-4919-bc84-ba7b72a71d6a" />
> <img width="680" height="385" alt="image" src="https://github.com/user-attachments/assets/4ae9e3cc-3713-4e31-a8cf-d6115452a2e0" />


> **Captura 5:** casos 3 a 6: errores de validación y verificación final.
> <img width="841" height="205" alt="image" src="https://github.com/user-attachments/assets/62558598-7383-45c4-9c7a-90e669a16a53" />

> <img width="837" height="179" alt="image" src="https://github.com/user-attachments/assets/1962c354-b307-425e-ad17-5c18406580dd" />

> <img width="835" height="189" alt="image" src="https://github.com/user-attachments/assets/3f7f7d3f-8b28-4c0f-b1bd-ae4069c928e8" />

> <img width="830" height="180" alt="image" src="https://github.com/user-attachments/assets/9ee413ef-e234-44d8-ac69-8ec896f3caf8" />

> <img width="646" height="307" alt="image" src="https://github.com/user-attachments/assets/92fbb81a-4cb8-4e02-b396-0656fc75a160" />

> <img width="573" height="188" alt="image" src="https://github.com/user-attachments/assets/feae69ba-a2a7-47c2-bbea-bac3fdc4ff7e" />

**Qué demuestra:** el caso 2 es la **Atomicidad**: al no cumplirse RN.01, la operación se cancela completa. Los casos 3 a 6 muestran que cada dato inválido se detecta antes de insertar, con un error específico y sin modificar ninguna tabla.

---

### Parte B – Venta con varios productos (`sp_RegistrarVenta`)

| Caso | Productos | Resultado esperado |
|---|---|---|
| 7 | Usuario 3, método 4: P1 × 1, P5 × 2, P6 × 1 | **Éxito** con `cantidad_productos = 3`: venta **12** con 3 detalles (subtotales `220000.00`, `130000.00` y `90000.00`) y un pago igual al `total`; stock P1: 12 → **11**, P5: 12 → **10**, P6: 23 → **22**. |
| 8 | P6 × 1 y P3 × 10 (el 3 solo tiene 4) | **Error 50011**. **Sin cambios**: el producto 6 sigue en 22 aunque sí tenía stock. |
| 9 | P6 × 1 y P6 × 2 (repetido) | **Éxito** con `cantidad_productos = 1`: venta **13** con **un solo detalle** (cantidad 3, subtotal `270000.00`); stock P6: 22 → **19**. |

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
```

> **Captura 6:** caso 7: resultado de la llamada y consultas de verificación.

> <img width="589" height="308" alt="image" src="https://github.com/user-attachments/assets/55b5aa26-4614-415c-bbbd-203256c779d4" />

> <img width="728" height="419" alt="image" src="https://github.com/user-attachments/assets/0a5f8f8e-b010-4136-b51e-bee558388338" />

> **Captura 7:** casos 8 y 9: error, resultado y verificación.

> <img width="850" height="255" alt="image" src="https://github.com/user-attachments/assets/65b0971f-c3a9-4d6f-9f92-e16ef152a6f8" />

> <img width="716" height="303" alt="image" src="https://github.com/user-attachments/assets/84c63a08-4fda-4929-8c44-d056bb4a0432" />

> <img width="555" height="235" alt="image" src="https://github.com/user-attachments/assets/fc98bffb-4484-4189-b148-6908247caec6" />

> <img width="724" height="419" alt="image" src="https://github.com/user-attachments/assets/e390fd11-2de4-4553-8ee3-481963bb1db5" />


**Qué demuestra:** una venta con varias líneas se confirma completa (caso 7) o no se registra en absoluto (caso 8: un solo producto inválido cancela toda la venta). Los productos repetidos se consolidan en una sola línea (caso 9).

---

### Parte C – Cancelar una venta (`sp_CancelarVenta`)

Cada caso fija primero el usuario de la sesión.

| Caso | Usuario y venta | Resultado esperado |
|---|---|---|
| 10 | Usuario 3, venta **12** (`Pendiente`: P1 × 1, P5 × 2, P6 × 1) | **Éxito** (`Venta cancelada y stock repuesto correctamente.`): venta 12 pasa a `Cancelado`; stock P1: 11 → **12**, P5: 10 → **12**, P6: 19 → **20**. |
| 11 | Usuario 3, venta **12** otra vez | **Error 50023**. El stock **no cambia** (no se devuelve dos veces). |
| 12 | Usuario 4, venta **10** (es del usuario 2) | **Error 50022**. La venta 10 sigue `Pendiente`. |
| 13 | Usuario 2, venta **1** (`Entregado`) | **Error 50024**. La venta 1 sigue `Entregado`. |

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;
EXEC dbo.sp_CancelarVenta @id_venta = 12;

SELECT id_venta, estado, id_usuario FROM VENTA WHERE id_venta = 12;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
```

> **Captura 8:** caso 10: resultado, estado de la venta y stock de los tres productos.

> <img width="513" height="184" alt="image" src="https://github.com/user-attachments/assets/293924c0-2439-4217-9b80-55781bed662c" />

> <img width="545" height="393" alt="image" src="https://github.com/user-attachments/assets/97790a57-ecb0-4ef5-aa74-8c2a533eaa69" />


> **Captura 9:** casos 11 a 13: errores y verificación.

> <img width="839" height="184" alt="image" src="https://github.com/user-attachments/assets/950415ea-6371-4690-969c-85dd0f208469" />

> <img width="424" height="170" alt="image" src="https://github.com/user-attachments/assets/a0fb57d0-732b-4fb3-ad0a-c7e6c782f981" />


> <img width="874" height="175" alt="image" src="https://github.com/user-attachments/assets/91eb25a2-1837-4805-96a9-af7e1150ca9f" />


> <img width="389" height="130" alt="image" src="https://github.com/user-attachments/assets/b4196768-6436-4e5f-ba24-766dae18d048" />


> <img width="850" height="171" alt="image" src="https://github.com/user-attachments/assets/28e2d5a8-3b20-46f4-983b-9570990938c3" />


> <img width="387" height="114" alt="image" src="https://github.com/user-attachments/assets/e74802fe-b03e-4a81-ae4d-cb2e0c39a404" />


**Qué demuestra:** el estado y el stock de **todos** los productos cambian juntos en una sola transacción (caso 10, que además cierra el ciclo vender y cancelar). La cancelación respeta las reglas: no se devuelve el stock dos veces (caso 11), solo cancela el dueño (caso 12) y solo se cancelan ventas pendientes (caso 13).

---

### Parte D – Propiedades ACID

#### Caso 14 – `ROLLBACK` y `COMMIT` manuales

```sql
BEGIN TRANSACTION;
    UPDATE PRODUCTO SET stock = stock - 3 WHERE id_producto = 2;
    SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;   -- 4 (provisorio)
ROLLBACK TRANSACTION;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;      -- 7 (se deshizo)

BEGIN TRANSACTION;
    UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 2;
COMMIT TRANSACTION;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;      -- 6 (permanente)
```

| Momento | Stock del producto 2 |
|---|---|
| Antes de la transacción | 7 |
| Dentro de la transacción, antes del `ROLLBACK` | **4** (provisorio) |
| Después del `ROLLBACK` | **7** (se deshizo) |
| Después del `UPDATE` + `COMMIT` | **6** (permanente) |

> **Captura 10:** los cuatro resultados del stock del producto 2.

> <img width="559" height="290" alt="image" src="https://github.com/user-attachments/assets/fa8df4f2-074f-40be-90f6-c919e4d20600" />

> <img width="464" height="422" alt="image" src="https://github.com/user-attachments/assets/683e722f-0ea0-4c8e-83a6-5053ef6fad09" />

**Qué demuestra:** el `ROLLBACK` deshace los cambios provisorios (**Atomicidad**) y el `COMMIT` los vuelve permanentes (**Durabilidad**).

#### Caso 15 – Falla real en el último paso

Para mostrar un error **dentro** de una transacción ya avanzada, se repiten a mano los pasos de una venta (`INSERT` en `VENTA`, en `VENTA_DETALLE` y en `VENTA_PAGO` con el método de pago 99, que no existe), dentro de `BEGIN TRY ... BEGIN CATCH` con `ROLLBACK`. El código completo está en el script.

**Resultado esperado:** el `CATCH` muestra el error de clave foránea hacia `METODO_PAGO`; no queda ninguna venta `PRUEBA ATOMICIDAD`, la última venta sigue siendo la **13** y el stock del producto 5 **sigue en 12**.

> **Captura 11:** mensaje de error y consultas de verificación.

> <img width="1494" height="348" alt="image" src="https://github.com/user-attachments/assets/16d31e6f-17d2-4635-8a19-ff00a7565510" />

> <img width="685" height="381" alt="image" src="https://github.com/user-attachments/assets/b19daf35-4996-451e-9555-f4337bb359c2" />

**Qué demuestra:** el caso más completo de **Atomicidad**: el error ocurre cuando la venta y el detalle **ya estaban insertados**, y el `ROLLBACK` igual los deshace. Aunque la fila se deshace, el número del `IDENTITY` se consume (la próxima venta sería la 15).

#### Caso 16 – Aislamiento con dos sesiones

Se usan 2 o 3 pestañas de consulta de SSMS (cada una es una sesión y **fija su propio usuario**). Venta 10: `Pendiente`, del usuario 2, con 1 u. del producto 2 y 2 u. del producto 5.

| Paso | Sesión | Código | Qué ocurre |
|---|---|---|---|
| 1 | 1 | `sp_set_session_context` (usuario 2), `BEGIN TRANSACTION;` y `EXEC sp_CancelarVenta @id_venta = 10;` | Resultado de éxito. La transacción queda **abierta** (`@@TRANCOUNT = 1`) y la fila bloqueada. |
| 2 | 2 | `sp_set_session_context` (usuario 2) y `EXEC sp_CancelarVenta @id_venta = 10;` | Queda **"Ejecutando consulta..."**, esperando. |
| 3 | 3 (opcional) | `SELECT session_id, blocking_session_id, wait_type FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;` | Muestra a la sesión 2 bloqueada por la 1 (`wait_type` típicamente `LCK_M_U`). Se ejecuta **mientras la sesión 2 espera**. |
| 4 | 1 | `COMMIT TRANSACTION;` | Se libera el bloqueo. |
| 5 | 2 | (se completa sola) | **Error 50023**: la venta ya se encuentra cancelada. |

**Resultado esperado:** venta 10 en `Cancelado`; stock del producto 2: 6 → **7** y del producto 5: 12 → **14** (se devolvió **una sola vez**).

> **Captura 12:** sesión 1 con la transacción abierta.

> <img width="491" height="352" alt="image" src="https://github.com/user-attachments/assets/e53aec07-6ae5-4fdd-ac7a-47c0e84489b7" />

> <img width="593" height="176" alt="image" src="https://github.com/user-attachments/assets/6e48dedc-a811-46f7-bc84-d8ae27df37f9" />

> <img width="480" height="102" alt="image" src="https://github.com/user-attachments/assets/fcdcb1cf-efe8-4b08-9093-b921c84cd66c" />

> **Captura 13:** sesión 2 esperando (ejecutando consulta).

> <img width="352" height="444" alt="image" src="https://github.com/user-attachments/assets/c5b09f63-caf5-4c27-a9b1-b404040ab107" />

> <img width="345" height="440" alt="image" src="https://github.com/user-attachments/assets/3a1c4f7c-58bf-474d-adf9-3cf08e61ed9f" />


> **Captura 14:** sesión 3 con la consulta de bloqueos mientras la sesión 2 espera.

> <img width="437" height="154" alt="image" src="https://github.com/user-attachments/assets/53774a40-ed94-4ec6-b0c9-bf245726b261" />

> <img width="498" height="177" alt="image" src="https://github.com/user-attachments/assets/42439216-54d4-48de-b4ad-8a4f34e740e6" />


> **Captura 15:** sesión 2 liberada con el error 50023 y la verificación final.
> 
> <img width="845" height="167" alt="image" src="https://github.com/user-attachments/assets/3f855c71-e3bc-42d8-b16d-bddd24f1769c" />

><img width="528" height="191" alt="image" src="https://github.com/user-attachments/assets/cdb34f2b-ca2f-4159-b663-858e85f6d5b6" />

><img width="365" height="300" alt="image" src="https://github.com/user-attachments/assets/266b9713-b808-4159-a0e1-bece7cc0e2d8" />


**Qué demuestra:** el **Aislamiento**. Mientras la sesión 1 no confirma, la sesión 2 no puede cancelar la misma venta; al liberarse ve el estado actualizado y se detiene por RT.01.

---

### 5.1 Estado final

Después de ejecutar los 16 casos en orden:

| Producto | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9 | P10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Stock final | 12 | 7 | 4 | 5 | 14 | 20 | 10 | 27 | 15 | 6 |

```sql
SELECT id_producto, nombre, stock FROM PRODUCTO ORDER BY id_producto;
SELECT estado, COUNT(*) AS cantidad FROM VENTA GROUP BY estado;
```

Ventas por estado: `Cancelado` 3 (ventas 5, 10 y 12), `Pendiente` 4 (3, 8, 11 y 13) y `Entregado` 6 (1, 2, 4, 6, 7 y 9). Si no se ejecuta el caso 16, el producto 2 queda en 6, el 5 en 12 y la venta 10 sigue `Pendiente` (Cancelado 2, Pendiente 5).

> **Captura 16:** estado final de stock y conteo de ventas por estado.

> <img width="461" height="198" alt="image" src="https://github.com/user-attachments/assets/82999cd5-c522-4725-a2a0-9b7eb4ec8cd9" />

> <img width="446" height="368" alt="image" src="https://github.com/user-attachments/assets/1e63d3dc-4981-41f1-ad39-489b97bc5668" />


---

## 6. Conclusiones

1. **Atomicidad comprobada.** Las ventas se confirman completas (casos 1, 7 y 9) o no se registran (casos 2, 8 y 15). El caso 15 deshizo incluso filas ya insertadas.
2. **Consistencia del inventario.** El stock se descuenta al vender y se devuelve al cancelar, siempre en la misma transacción. Las reglas RN y RT, junto con los `CHECK` y `FOREIGN KEY`, impiden stock negativo, ventas sobre datos inexistentes o inactivos y devoluciones duplicadas.
3. **Validación previa con errores claros.** Cada dato inválido lanza un error numerado y específico sin modificar tablas ni consumir `IDENTITY`; `XACT_ABORT` y el `CATCH` garantizan el `ROLLBACK` ante cualquier otra falla.
4. **Seguridad y reglas de negocio.** El usuario sale de la sesión: solo el dueño puede cancelar su venta y solo si está pendiente.
5. **Proceso reversible y completo.** Se puede registrar una venta con uno o varios productos, aplicar el descuento del método de pago y cancelarla con trazabilidad, sin eliminar datos ni calcular el stock a mano.
6. **Aislamiento demostrado.** Con `UPDLOCK`, dos sesiones no pueden cancelar la misma venta ni devolver el stock dos veces (caso 16).
7. **Limitaciones y mejoras posibles.**
   - Cada venta registra un único pago por el total, aunque `VENTA_PAGO` admite varios.
   - Al cancelar, el pago queda como historial: no se registra una devolución de dinero.
   - Solo el dueño de la venta puede cancelarla: un administrador no podría hacerlo con este procedimiento.
   - Ante un error posterior al `INSERT` en `VENTA`, el número del `IDENTITY` se pierde y pueden quedar saltos en los `id`.

---
