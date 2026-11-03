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
| **A**tomicidad | Todo o nada. | Si una regla no se cumple o hay un error, el `ROLLBACK` deshace lo hecho. |
| **C**onsistencia | La base pasa de un estado válido a otro válido. | Se respetan los `CHECK`, `FOREIGN KEY` y `UNIQUE`; el stock nunca queda negativo. |
| **A**islamiento | Una transacción no interfiere con otra en curso. | `READ COMMITTED` (nivel por defecto) más `UPDLOCK`, que bloquea la fila mientras dura la transacción. |
| **D**urabilidad | Lo confirmado no se pierde. | `COMMIT TRANSACTION` guarda los cambios de forma permanente. |

### Objetivo en este proyecto

1. **Registrar una venta completa** (encabezado, detalle, pago y descuento de stock), con uno o varios productos, como una operación indivisible.
2. **Cancelar una venta** cambiando su estado y devolviendo el stock, también de forma indivisible.
3. **Validar las reglas de negocio antes de modificar datos** y cancelar toda la operación si alguna no se cumple, sin dejar datos parciales.

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aprovecha en el sistema |
|---|---|
| **Integridad:** evita datos a medias. | Nunca queda una venta sin detalle ni un detalle sin pago. |
| **Consistencia del stock** | Se descuenta al vender y se devuelve al cancelar, siempre en la misma transacción. |
| **Recuperación ante errores** | El bloque `CATCH` hace `ROLLBACK` automáticamente ante cualquier falla. |
| **Reglas centralizadas** | Las reglas viven en la base y se aplican desde cualquier aplicación. |
| **Concurrencia segura** | Con `UPDLOCK`, dos sesiones no pueden vender o cancelar lo mismo a la vez. |

**Aplicaciones habituales:** ventas, transferencias bancarias, reservas, movimientos de inventario, cancelaciones y devoluciones.

---

## 3. Implementación en SQL Server

| Script | Contenido |
|---|---|
| [`sql/tecnico/transacciones/implementacion_transacciones.sql`](../../sql/tecnico/transacciones/implementacion_transacciones.sql) | Tipo de tabla y procedimientos almacenados. |
| [`sql/tecnico/transacciones/demostracion_transacciones.sql`](../../sql/tecnico/transacciones/demostracion_transacciones.sql) | Casos de prueba. |

### Objetos creados

| Objeto | Tipo | Función |
|---|---|---|
| `sp_RegistrarVentaTransaccional` | Procedimiento | Registra una venta de un producto. |
| `sp_CancelarVentaTransaccional` | Procedimiento | Cancela una venta y devuelve el stock. |
| `sp_RegistrarVentaMultipleTransaccional` | Procedimiento | Registra una venta con varios productos. |
| `tipo_item_venta` | Tipo de tabla | Lista de `id_producto` y `cantidad` que recibe la venta múltiple. |

### Reglas de negocio implementadas

| Código | Regla |
|---|---|
| **RN.01** | No se puede vender más cantidad que el stock disponible. |
| **RN.02** | Al registrar una venta se descuenta el stock del producto. |
| **RT.01** | Una venta ya cancelada no puede cancelarse de nuevo (evita devolver el stock dos veces). |
| **RT.02** | Al cancelar una venta se devuelve el stock de todos sus productos. |
| **RT.03** | Solo pueden comprar usuarios existentes y activos. |
| **RT.04** | Solo se pueden vender productos existentes y activos (no discontinuados). |
| **RT.05** | Datos válidos: cantidad mayor a 0, domicilio informado y método de pago existente. |
| **RT.06** | Una venta con varios productos se registra completa o no se registra; los productos repetidos se suman en una sola línea. |

> Las reglas `RT.xx` (reglas de transacciones) son las incorporadas en esta etapa.

### 3.1 Registrar una venta (un producto)

**Parámetros:** `@id_usuario`, `@domicilio_entrega`, `@id_producto`, `@cantidad`, `@id_metodo_pago`.

```sql
CREATE OR ALTER PROCEDURE sp_RegistrarVentaTransaccional
    @id_usuario INT,
    @domicilio_entrega VARCHAR(150),
    @id_producto INT,
    @cantidad INT,
    @id_metodo_pago INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado_usuario INT;
        DECLARE @estado_producto INT;
        DECLARE @stock_actual INT;
        DECLARE @precio_unitario DECIMAL(10,2);
        DECLARE @total DECIMAL(10,2);
        DECLARE @id_venta_nueva INT;

        -- RT.05: datos de entrada válidos
        IF @domicilio_entrega IS NULL OR LTRIM(RTRIM(@domicilio_entrega)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El domicilio de entrega es obligatorio.';
            RETURN;
        END

        IF @cantidad IS NULL OR @cantidad <= 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La cantidad debe ser mayor a 0.';
            RETURN;
        END

        -- RT.03: el usuario debe existir y estar activo
        SELECT @estado_usuario = estado
        FROM USUARIO
        WHERE id_usuario = @id_usuario;

        IF @estado_usuario IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario no existe.';
            RETURN;
        END

        IF @estado_usuario = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario está dado de baja.';
            RETURN;
        END

        -- RT.05: el método de pago debe existir
        IF NOT EXISTS (SELECT 1 FROM METODO_PAGO WHERE id_metodo_pago = @id_metodo_pago)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El método de pago no existe.';
            RETURN;
        END

        -- Paso A: obtener datos del producto (la fila queda bloqueada hasta el final de la transacción)
        SELECT @stock_actual = stock, @precio_unitario = precio, @estado_producto = estado
        FROM PRODUCTO WITH (UPDLOCK, ROWLOCK)
        WHERE id_producto = @id_producto;

        -- RT.04: el producto debe existir y estar activo
        IF @estado_producto IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El producto no existe.';
            RETURN;
        END

        IF @estado_producto = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El producto está discontinuado.';
            RETURN;
        END

        -- RN.01: verificar stock
        IF @stock_actual < @cantidad
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Stock insuficiente para el producto solicitado.';
            RETURN;
        END

        -- Paso B: encabezado de la venta
        SET @total = @cantidad * @precio_unitario;

        INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
        VALUES ('Entregado', @domicilio_entrega, @total, GETDATE(), @id_usuario);

        SET @id_venta_nueva = SCOPE_IDENTITY();

        -- Paso C: detalle
        INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        VALUES (@cantidad, @precio_unitario, @total, @id_producto, @id_venta_nueva);

        -- Paso D: pago
        INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
        VALUES (@total, @id_venta_nueva, @id_metodo_pago);

        -- Paso E: descontar stock (RN.02)
        UPDATE PRODUCTO
        SET stock = stock - @cantidad
        WHERE id_producto = @id_producto;

        COMMIT TRANSACTION;
        PRINT 'ÉXITO: Venta registrada, pago asentado y stock actualizado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END
        PRINT 'ERROR INESPERADO: Se ejecutó un ROLLBACK. Ningún dato fue modificado.';
        PRINT 'Detalle del error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
```

**Validaciones (en orden).** Se hacen **antes de insertar**, y todos los mensajes comienzan con `OPERACIÓN CANCELADA:`.

| Orden | Validación | Regla | Mensaje |
|---|---|---|---|
| 1 | Domicilio informado | RT.05 | `El domicilio de entrega es obligatorio.` |
| 2 | Cantidad mayor a 0 | RT.05 | `La cantidad debe ser mayor a 0.` |
| 3 | El usuario existe | RT.03 | `El usuario no existe.` |
| 4 | El usuario está activo | RT.03 | `El usuario está dado de baja.` |
| 5 | El método de pago existe | RT.05 | `El método de pago no existe.` |
| 6 | El producto existe | RT.04 | `El producto no existe.` |
| 7 | El producto está activo | RT.04 | `El producto está discontinuado.` |
| 8 | Stock suficiente | RN.01 | `Stock insuficiente para el producto solicitado.` |

**Flujo:**

```
BEGIN TRANSACTION
  │
  ▼
Validaciones 1 a 8 ── alguna falla ──► ROLLBACK + mensaje + RETURN (sin cambios)
  │
  ▼
B: INSERT en VENTA → C: INSERT en VENTA_DETALLE → D: INSERT en VENTA_PAGO → E: UPDATE de stock
  │
  ▼
COMMIT TRANSACTION ──► "ÉXITO"

Cualquier error SQL en B a E ──► CATCH ──► ROLLBACK + "ERROR INESPERADO"
```

### 3.2 Cancelar una venta

**Parámetro:** `@id_venta`.

```sql
CREATE OR ALTER PROCEDURE sp_CancelarVentaTransaccional
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(50);

        -- Paso A: leer el estado de la venta y bloquear la fila
        SELECT @estado = estado
        FROM VENTA WITH (UPDLOCK, ROWLOCK)
        WHERE id_venta = @id_venta;

        -- La venta no existe
        IF @estado IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta no existe.';
            RETURN;
        END

        -- RT.01: no se puede cancelar dos veces
        IF @estado = 'Cancelado'
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta ya estaba cancelada.';
            RETURN;
        END

        -- Paso B: devolver el stock de todos los productos de la venta (RT.02)
        UPDATE p
        SET p.stock = p.stock + d.cantidad_total
        FROM PRODUCTO p
        INNER JOIN (SELECT id_producto, SUM(cantidad) AS cantidad_total
                    FROM VENTA_DETALLE
                    WHERE id_venta = @id_venta
                    GROUP BY id_producto) d ON d.id_producto = p.id_producto;

        -- Paso C: marcar la venta como cancelada
        UPDATE VENTA
        SET estado = 'Cancelado'
        WHERE id_venta = @id_venta;

        COMMIT TRANSACTION;
        PRINT 'ÉXITO: Venta cancelada y stock devuelto correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END
        PRINT 'ERROR INESPERADO: Se ejecutó un ROLLBACK. Ningún dato fue modificado.';
        PRINT 'Detalle del error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
```

**Flujo:** `BEGIN TRANSACTION` → leer el estado de la venta con `UPDLOCK` → si no existe, o ya está `Cancelado`, `ROLLBACK` + mensaje → si no, devolver el stock (`UPDATE` de `PRODUCTO`) → pasar la venta a `Cancelado` (`UPDATE` de `VENTA`) → `COMMIT`.

### 3.3 Venta con varios productos

**Parámetros:** `@id_usuario`, `@domicilio_entrega`, `@id_metodo_pago` y `@items` (lista de productos y cantidades).

```sql
IF TYPE_ID(N'dbo.tipo_item_venta') IS NULL
BEGIN
    CREATE TYPE dbo.tipo_item_venta AS TABLE
    (
        id_producto INT NOT NULL,
        cantidad    INT NOT NULL
    );
END
GO
```

```sql
CREATE OR ALTER PROCEDURE sp_RegistrarVentaMultipleTransaccional
    @id_usuario INT,
    @domicilio_entrega VARCHAR(150),
    @id_metodo_pago INT,
    @items dbo.tipo_item_venta READONLY
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado_usuario INT;
        DECLARE @total DECIMAL(10,2);
        DECLARE @id_venta_nueva INT;
        DECLARE @cantidad_productos INT;

        -- Productos consolidados: si un producto se repite, se suman sus cantidades (RT.06)
        DECLARE @lineas TABLE
        (
            id_producto INT PRIMARY KEY,
            cantidad    INT NOT NULL,
            precio      DECIMAL(10,2) NULL,
            stock       INT NULL,
            estado      INT NULL
        );

        -- RT.06: la venta debe incluir al menos un producto
        IF NOT EXISTS (SELECT 1 FROM @items)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta debe incluir al menos un producto.';
            RETURN;
        END

        -- RT.05: datos de entrada válidos
        IF EXISTS (SELECT 1 FROM @items WHERE cantidad <= 0)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Todas las cantidades deben ser mayores a 0.';
            RETURN;
        END

        IF @domicilio_entrega IS NULL OR LTRIM(RTRIM(@domicilio_entrega)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El domicilio de entrega es obligatorio.';
            RETURN;
        END

        -- RT.03: el usuario debe existir y estar activo
        SELECT @estado_usuario = estado
        FROM USUARIO
        WHERE id_usuario = @id_usuario;

        IF @estado_usuario IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario no existe.';
            RETURN;
        END

        IF @estado_usuario = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario está dado de baja.';
            RETURN;
        END

        -- RT.05: el método de pago debe existir
        IF NOT EXISTS (SELECT 1 FROM METODO_PAGO WHERE id_metodo_pago = @id_metodo_pago)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El método de pago no existe.';
            RETURN;
        END

        -- Paso A: consolidar los productos repetidos
        INSERT INTO @lineas (id_producto, cantidad)
        SELECT id_producto, SUM(cantidad)
        FROM @items
        GROUP BY id_producto;

        SELECT @cantidad_productos = COUNT(*) FROM @lineas;

        -- Paso B: traer precio, stock y estado de cada producto (las filas quedan bloqueadas)
        UPDATE l
        SET l.precio = p.precio,
            l.stock  = p.stock,
            l.estado = p.estado
        FROM @lineas l
        INNER JOIN PRODUCTO p WITH (UPDLOCK, ROWLOCK) ON p.id_producto = l.id_producto;

        -- RT.04: todos los productos deben existir y estar activos
        IF EXISTS (SELECT 1 FROM @lineas WHERE estado IS NULL)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Alguno de los productos no existe.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @lineas WHERE estado = 0)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Alguno de los productos está discontinuado.';
            RETURN;
        END

        -- RN.01: stock suficiente para todos los productos
        IF EXISTS (SELECT 1 FROM @lineas WHERE stock < cantidad)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Stock insuficiente en al menos un producto.';
            RETURN;
        END

        -- Paso C: encabezado de la venta
        SELECT @total = SUM(cantidad * precio) FROM @lineas;

        INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
        VALUES ('Entregado', @domicilio_entrega, @total, GETDATE(), @id_usuario);

        SET @id_venta_nueva = SCOPE_IDENTITY();

        -- Paso D: un detalle por cada producto
        INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        SELECT cantidad, precio, cantidad * precio, id_producto, @id_venta_nueva
        FROM @lineas;

        -- Paso E: pago por el total
        INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
        VALUES (@total, @id_venta_nueva, @id_metodo_pago);

        -- Paso F: descontar el stock de todos los productos (RN.02)
        UPDATE p
        SET p.stock = p.stock - l.cantidad
        FROM PRODUCTO p
        INNER JOIN @lineas l ON l.id_producto = p.id_producto;

        COMMIT TRANSACTION;
        PRINT 'ÉXITO: Venta registrada con ' + CAST(@cantidad_productos AS VARCHAR(10))
            + ' producto(s), pago asentado y stock actualizado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END
        PRINT 'ERROR INESPERADO: Se ejecutó un ROLLBACK. Ningún dato fue modificado.';
        PRINT 'Detalle del error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
```

Ejemplo de llamada:

```sql
DECLARE @items dbo.tipo_item_venta;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 1), (5, 2), (6, 1);

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 3, @domicilio_entrega = 'Sarmiento 789, Rosario',
    @id_metodo_pago = 4, @items = @items;
```

### 3.4 Elementos principales

| Elemento | Explicación |
|---|---|
| `SCOPE_IDENTITY()` | Devuelve el `id_venta` recién generado, para vincular detalle y pago. |
| `WITH (UPDLOCK, ROWLOCK)` | Bloquea la fila leída hasta el final de la transacción, para que otra sesión no la modifique al mismo tiempo. |
| `@@TRANCOUNT` | Cantidad de transacciones abiertas. El `CATCH` hace `ROLLBACK` solo si es mayor a 0. |
| `RETURN` | Termina el procedimiento inmediatamente. |
| `SUM(cantidad) ... GROUP BY` | Suma unidades por producto (cancelación y consolidación de productos repetidos). |
| `UPDATE p ... FROM ... INNER JOIN` | Actualiza el stock de varios productos en una sola sentencia. |
| `CREATE TYPE ... AS TABLE` y `READONLY` | Permiten enviar una lista de productos como parámetro (solo lectura dentro del procedimiento). |
| `ERROR_MESSAGE()` | Devuelve el texto del error capturado en el `CATCH`. |

---

## 4. Caso concreto aplicado al sistema de ventas

- **Por qué una transacción.** Registrar una venta modifica cuatro tablas (`VENTA`, `VENTA_DETALLE`, `VENTA_PAGO` y `PRODUCTO`). Sin transacción, un error a mitad de camino dejaría una venta sin pago o con el stock sin descontar. Cancelar modifica dos (`PRODUCTO` y `VENTA`): si solo cambiara el estado, el stock quedaría sin devolver. En los datos de prueba originales eso se hacía a mano (venta 5 cancelada y dos `UPDATE` para el stock de los productos 8 y 9).
- **Por qué se valida antes de insertar.** Ante un dato inválido se cancela con un mensaje claro y no se consume ni un número de `IDENTITY`. Los `CHECK` y `FOREIGN KEY` quedan como segunda línea de defensa y el `CATCH` como red de seguridad.
- **Por qué `UPDLOCK`.** Sin bloqueo, dos sesiones podrían vender más stock del que hay o cancelar la misma venta dos veces, devolviendo el stock duplicado. Con `UPDLOCK` la segunda espera a la primera y se detiene por RN.01 o RT.01 (caso 25).
- **Por qué baja lógica.** Cancelar cambia el `estado` y no elimina la venta: se conserva el historial. `VENTA_PAGO` no tiene estado, por lo que el pago queda registrado.
- **Por qué un tipo de tabla.** Una venta real tiene varias líneas (la venta 1 tiene 3 productos) y un procedimiento no puede recibir una cantidad variable de parámetros. Si un solo producto falla, no se registra ninguno.
- **Transacciones anidadas.** Si un procedimiento se ejecuta dentro de otra transacción, su `COMMIT` solo baja `@@TRANCOUNT`; los cambios se confirman con el `COMMIT` externo. Un `ROLLBACK` deshace todo.
- **Triggers de auditoría.** Si el trigger sobre `VENTA` está creado, cada cancelación queda registrada en `AUDITORIA_VENTA` con el estado anterior y el nuevo.

---

## 5. Demostración y resultados

Script completo: [`demostracion_transacciones.sql`](../../sql/tecnico/transacciones/demostracion_transacciones.sql).

> Los casos se ejecutan **en orden**, sobre una base recién cargada con los datos de prueba. Los `id_venta` (11 a 14) pueden variar si se insertaron ventas adicionales (por ejemplo, con la demostración de triggers).

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
> <img width="1204" height="411" alt="image" src="https://github.com/user-attachments/assets/b47f99f5-5f3b-41eb-8512-391d3d390c9a" />


**Datos de referencia de los casos siguientes:** stock inicial P1=14, P2=7, P3=4, P4=5, P5=12, P6=23, P8=27, P9=15, P10=6. Productos discontinuados: 4 y 8. Usuarios dados de baja: 6 y 9. Ventas `Pendiente`: 3, 8 y 10; `Cancelado`: 5; el resto `Entregado`. Métodos de pago: 1 Efectivo, 2 Débito, 3 Crédito, 4 Mercado Pago.

---

### Parte A – Registrar una venta (`sp_RegistrarVentaTransaccional`)

#### Caso 1 – Venta correcta (stock suficiente)

```sql
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba', 
    @id_producto = 1,       -- Ryzen 5 5600
    @cantidad = 2, 
    @id_metodo_pago = 1;    -- Efectivo
```

**Mensaje esperado:** `ÉXITO: Venta registrada, pago asentado y stock actualizado correctamente.`

> **Captura 2:** mensaje de éxito.
> <img width="1204" height="413" alt="image" src="https://github.com/user-attachments/assets/59979299-65f4-472c-b6c2-451b95e6ffe3" />


**Verificación:**

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
```

| Tabla | Resultado esperado |
|---|---|
| `VENTA` | Nueva fila: `id_venta = 11`, estado `Entregado`, total `440000.00`, usuario 2. |
| `VENTA_DETALLE` | Nueva fila: cantidad `2`, precio unitario `220000.00`, subtotal `440000.00`, producto 1, venta 11. |
| `VENTA_PAGO` | Nueva fila: monto `440000.00`, venta 11, método 1 (Efectivo). |
| `PRODUCTO` (id 1) | Stock baja de **14 a 12**. |

> **Captura 3:** las cuatro consultas de verificación.
> <img width="1204" height="418" alt="image" src="https://github.com/user-attachments/assets/3d125770-edc5-4b72-b8a6-c56b1af05ca1" />


**Qué demuestra:** las cuatro tablas se modificaron de forma coordinada y se confirmaron juntas con `COMMIT`.

#### Caso 2 – Venta incorrecta (stock insuficiente)

```sql
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 3, 
    @domicilio_entrega = 'Sarmiento 789, Rosario', 
    @id_producto = 3,       -- RTX 3060 (stock 4)
    @cantidad = 10, 
    @id_metodo_pago = 2;    -- Tarjeta de Débito
```

**Mensaje esperado:** `OPERACIÓN CANCELADA: Stock insuficiente para el producto solicitado.`

> **Captura 4:** mensaje de operación cancelada.
> <img width="1204" height="413" alt="image" src="https://github.com/user-attachments/assets/cb8bb5de-944f-43e1-bb70-afbae089bbf0" />


**Resultado esperado:** la última venta sigue siendo la **11**, no hay detalle ni pago nuevos, y el stock del producto 3 **sigue en 4**.

> **Captura 5:** consultas de verificación tras la prueba fallida.
> <img width="1204" height="412" alt="image" src="https://github.com/user-attachments/assets/c2525bff-f47e-4dbe-8e84-56755b486e68" />


**Qué demuestra:** la **Atomicidad**. Al no cumplirse RN.01, la operación se cancela completa.

#### Casos 3 a 11 – Límite y validaciones

Todos usan `sp_RegistrarVentaTransaccional`; solo se indican los parámetros que cambian.

| Caso | Parámetros | Mensaje esperado | Resultado esperado |
|---|---|---|---|
| 3 | Usuario 4, producto 10 × 6 (todo el stock), método 3 | `ÉXITO...` | Venta **12** por `1680000.00`; stock del producto 10: 6 → **0**. |
| 4 | Usuario 4, producto 10 × 1 | `Stock insuficiente...` | Sin cambios (stock en 0). |
| 5 | Usuario **999** | `El usuario no existe.` | Sin cambios. |
| 6 | Usuario **6** (dado de baja) | `El usuario está dado de baja.` | Sin cambios. |
| 7 | Producto **999** | `El producto no existe.` | Sin cambios. |
| 8 | Producto **8** (discontinuado) | `El producto está discontinuado.` | Sin cambios; el stock del 8 sigue en 27. |
| 9 | Método de pago **99** | `El método de pago no existe.` | Sin cambios. |
| 10 | Cantidad **0** y **-3** | `La cantidad debe ser mayor a 0.` | Sin cambios. |
| 11 | Domicilio **'   '** (solo espacios) | `El domicilio de entrega es obligatorio.` | Sin cambios. |

"Sin cambios" significa que la última venta sigue siendo la **12** y el stock del producto 1 sigue en **12**.

> **Captura 6:** mensajes y verificación de los casos 3 y 4.
> **Captura 7:** mensajes de los casos 5 a 11.
> <img width="1101" height="383" alt="image" src="https://github.com/user-attachments/assets/9c255c07-c5c8-4d28-9cff-561b6d4468e1" />


**Qué demuestra:** el caso 3 confirma que vender exactamente todo el stock es válido (la condición es `stock < cantidad`). Los casos 5 a 11 muestran que cada dato inválido se detecta antes de insertar, con un mensaje específico y sin modificar ninguna tabla.

---

### Parte B – Cancelar una venta (`sp_CancelarVentaTransaccional`)

| Caso | Llamada | Mensaje esperado | Resultado esperado |
|---|---|---|---|
| 12 | Venta **3** (`Pendiente`, 4 u. del producto 5) | `ÉXITO: Venta cancelada y stock devuelto correctamente.` | Venta 3 pasa a `Cancelado`; stock del producto 5: 12 → **16**. |
| 13 | Venta **3** otra vez | `La venta ya estaba cancelada.` | El stock del producto 5 **sigue en 16** (no se devuelve dos veces, RT.01). |
| 14 | Venta **999** | `La venta no existe.` | Sin cambios. |
| 15 | Venta **1** (`Entregado`: P1 × 1, P4 × 1, P5 × 2) | `ÉXITO...` | Venta 1 pasa a `Cancelado`; stock P1: 12 → **13**, P4: 5 → **6**, P5: 16 → **18**. |
| 16 | Venta **11** (creada en el caso 1, P1 × 2) | `ÉXITO...` | Venta 11 pasa a `Cancelado`; stock P1: 13 → **15** (valor original). |
| 17 | Venta **5** (ya `Cancelado` en los datos de prueba) | `La venta ya estaba cancelada.` | Los productos 8 y 9 siguen en **27** y **15**. |

```sql
EXEC sp_CancelarVentaTransaccional @id_venta = 3;

SELECT id_venta, estado FROM VENTA WHERE id_venta = 3;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 5;
```

> **Captura 8:** casos 12 a 14: mensajes, estado de la venta 3 y stock del producto 5.
> <img width="1187" height="396" alt="image" src="https://github.com/user-attachments/assets/4f5d477b-cf5d-4550-a3fd-7bceeef1b729" />


> **Captura 9:** casos 15 a 17: mensajes, estado de las ventas y stock de los productos.
> <img width="1163" height="86" alt="image" src="https://github.com/user-attachments/assets/d8857e4a-d1c7-4a88-a4ba-05fe705224b4" />



**Qué demuestra:** el estado y el stock cambian juntos en una sola transacción. La cancelación funciona con varios productos (caso 15), cierra el ciclo vender y cancelar (caso 16) y nunca devuelve el stock dos veces (casos 13 y 17).

---

### Parte C – Venta con varios productos (`sp_RegistrarVentaMultipleTransaccional`)

| Caso | Productos | Mensaje esperado | Resultado esperado |
|---|---|---|---|
| 18 | Usuario 3, método 4: P1 × 1, P5 × 2, P6 × 1 | `ÉXITO: Venta registrada con 3 producto(s)...` | Venta **13** por `440000.00` con 3 detalles y un pago de `440000.00`; stock P1: 15 → **14**, P5: 18 → **16**, P6: 23 → **22**. |
| 19 | P6 × 1 y P3 × 10 (el 3 solo tiene 4) | `Stock insuficiente en al menos un producto.` | **Sin cambios**: el producto 6 sigue en 22 aunque sí tenía stock. |
| 20 | P6 × 1 y P4 × 1 (discontinuado) | `Alguno de los productos está discontinuado.` | Sin cambios. |
| 21 | P6 × 1 y P6 × 2 (repetido) | `ÉXITO...` con 1 producto | Venta **14** por `270000.00` con **un solo detalle** (cantidad 3); stock P6: 22 → **19**. |
| 22 | Lista vacía | `La venta debe incluir al menos un producto.` | Sin cambios. |

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
```

> **Captura 10:** caso 18: mensaje y consultas de verificación.
> <img width="1163" height="179" alt="image" src="https://github.com/user-attachments/assets/5dc35f40-56b1-45a9-a608-7404bd81f414" />



> **Captura 11:** casos 19 a 22: mensajes y verificación.
> <img width="1163" height="122" alt="image" src="https://github.com/user-attachments/assets/91bce5ba-e44a-4373-ae49-6dcc11f12870" />
> <img width="1160" height="360" alt="image" src="https://github.com/user-attachments/assets/2c720ae4-4336-4c05-9a73-73f7792da63c" />


**Qué demuestra:** una venta con varias líneas se confirma completa (caso 18) o no se registra en absoluto (caso 19: un solo producto inválido cancela toda la venta). Los productos repetidos se consolidan (caso 21).

---

### Parte D – Propiedades ACID

#### Caso 23 – `ROLLBACK` y `COMMIT` manuales

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

> **Captura 12:** los cuatro resultados del stock del producto 2.
> <img width="1190" height="82" alt="image" src="https://github.com/user-attachments/assets/633b31e7-e080-4e6e-8234-8e0610614819" />
> <img width="1193" height="159" alt="image" src="https://github.com/user-attachments/assets/e0fc6d70-57a4-4714-8f01-9fef8fa1c132" />

**Qué demuestra:** el `ROLLBACK` deshace los cambios provisorios (**Atomicidad**) y el `COMMIT` los vuelve permanentes (**Durabilidad**).

#### Caso 24 – Falla real en el último paso

Como los procedimientos validan antes de insertar, el error se simula repitiendo a mano los pasos de una venta (`INSERT` en `VENTA`, en `VENTA_DETALLE` y en `VENTA_PAGO` con el método de pago 99, que no existe), dentro de `BEGIN TRY ... BEGIN CATCH` con `ROLLBACK`. El código completo está en el script.

**Resultado esperado:** el `CATCH` muestra el error de clave foránea hacia `METODO_PAGO`; no queda ninguna venta `PRUEBA ATOMICIDAD`, la última venta sigue siendo la **14** y el stock del producto 5 **sigue en 16**.

> **Captura 13:** mensaje de error y consultas de verificación.
> <img width="1139" height="259" alt="image" src="https://github.com/user-attachments/assets/b54c0ff4-afe3-43fc-8e18-b11541e15fb2" />


**Qué demuestra:** el caso más completo de **Atomicidad**: el error ocurre cuando la venta y el detalle **ya estaban insertados**, y el `ROLLBACK` igual los deshace. Aunque la fila se deshace, el número del `IDENTITY` se consume (la próxima venta sería la 16).

#### Caso 25 – Aislamiento con dos sesiones

Se usan 2 o 3 pestañas de consulta de SSMS (cada una es una sesión). Venta 8: `Pendiente`, 2 u. del producto 9 y 2 u. del producto 8.

| Paso | Sesión | Código | Qué ocurre |
|---|---|---|---|
| 1 | 1 | `BEGIN TRANSACTION;` + `EXEC sp_CancelarVentaTransaccional @id_venta = 8;` | `ÉXITO`. La transacción queda **abierta** (`@@TRANCOUNT = 1`) y la fila bloqueada. |
| 2 | 2 | `EXEC sp_CancelarVentaTransaccional @id_venta = 8;` | Queda **"Ejecutando consulta..."**, esperando. |
| 3 | 3 (opcional) | `SELECT session_id, blocking_session_id, wait_type FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;` | Muestra a la sesión 2 bloqueada por la 1 (`wait_type` típicamente `LCK_M_U`). |
| 4 | 1 | `COMMIT TRANSACTION;` | Se libera el bloqueo. |
| 5 | 2 | (se completa sola) | `La venta ya estaba cancelada.` |

**Resultado esperado:** venta 8 en `Cancelado`; stock del producto 8: 27 → **29** y del producto 9: 15 → **17** (se devolvió **una sola vez**).

> **Captura 14:** sesión 1 con la transacción abierta.
> <img width="1058" height="315" alt="image" src="https://github.com/user-attachments/assets/d0f51c73-f1b3-4db5-b5cf-a37153aea57c" />
> <img width="918" height="279" alt="image" src="https://github.com/user-attachments/assets/631b9dfe-44b8-48fb-bd11-942380d584f4" />

> **Captura 15:** sesión 2 esperando.

> <img width="415" height="444" alt="image" src="https://github.com/user-attachments/assets/69fa8b62-7764-413d-b98a-a649da2b3cdd" />
> <img width="326" height="439" alt="image" src="https://github.com/user-attachments/assets/dfeadf50-a515-4a23-91eb-2fa461af952e" />



> **Captura 16:** sesión 2 liberada con el mensaje y la verificación final.

> <img width="435" height="440" alt="image" src="https://github.com/user-attachments/assets/f4bf2da6-96e3-4a7e-bd3a-9e7550758348" />
> <img width="553" height="430" alt="image" src="https://github.com/user-attachments/assets/6e78444f-f712-4af5-8c0a-b09a408a2dda" />
> <img width="453" height="231" alt="image" src="https://github.com/user-attachments/assets/1442bbd2-184c-4dbe-abee-e01a9bf53446" />
> <img width="571" height="282" alt="image" src="https://github.com/user-attachments/assets/a3855c9a-98ca-4e38-9900-d6bb0e57cbc8" />



**Qué demuestra:** el **Aislamiento**. Mientras la sesión 1 no confirma, la sesión 2 no puede cancelar la misma venta; al liberarse ve el estado actualizado y se detiene por RT.01.

---

### 5.1 Estado final

Después de ejecutar los 25 casos en orden:

| Producto | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9 | P10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Stock final | 14 | 6 | 4 | 6 | 16 | 19 | 10 | 29 | 17 | 0 |

```sql
SELECT id_producto, nombre, stock FROM PRODUCTO ORDER BY id_producto;
SELECT estado, COUNT(*) AS cantidad FROM VENTA GROUP BY estado;
```

Ventas por estado: `Cancelado` 5 (ventas 1, 3, 5, 8 y 11), `Entregado` 8 (2, 4, 6, 7, 9, 12, 13 y 14) y `Pendiente` 1 (la 10). Si no se ejecuta el caso 25, los productos 8 y 9 quedan en 27 y 15, y la venta 8 sigue `Pendiente`.

> **Captura 17:** estado final de stock y conteo de ventas por estado.

> <img width="419" height="131" alt="image" src="https://github.com/user-attachments/assets/a5e247a1-0d19-4a1b-bdeb-96de99c25f0e" />
> <img width="487" height="90" alt="image" src="https://github.com/user-attachments/assets/9b33f96e-d012-47a3-827d-4a9102193d03" />


---

## 6. Conclusiones

1. **Atomicidad comprobada.** Las ventas se confirman completas (casos 1, 18 y 21) o no se registran (casos 2, 4, 19 y 24). El caso 24 deshizo incluso filas ya insertadas.
2. **Consistencia del inventario.** El stock se descuenta al vender y se devuelve al cancelar, siempre en la misma transacción. Las reglas RN y RT, junto con los `CHECK` y `FOREIGN KEY`, impiden stock negativo, ventas sobre datos inexistentes o inactivos y devoluciones duplicadas.
3. **Validación previa con mensajes claros.** Cada dato inválido se informa de forma específica sin modificar tablas ni consumir `IDENTITY`; el `CATCH` queda como red de seguridad.
4. **Proceso reversible y completo.** El ciclo comercial queda cubierto: registrar (uno o varios productos) y cancelar con trazabilidad, sin eliminar datos ni calcular el stock a mano.
5. **Aislamiento demostrado.** Con `UPDLOCK`, dos sesiones no pueden cancelar la misma venta ni devolver el stock dos veces (caso 25).
6. **Limitaciones y mejoras posibles.**
   - Cada venta registra un único pago por el total, aunque `VENTA_PAGO` admite varios.
   - Al cancelar, el pago queda como historial: no se registra una devolución de dinero.
   - Ante un error posterior al `INSERT` en `VENTA`, el número del `IDENTITY` se pierde y pueden quedar saltos en los `id`.
   - Se permite cancelar ventas `Entregado` y `Pendiente`; se puede restringir si el negocio lo requiere.

---
