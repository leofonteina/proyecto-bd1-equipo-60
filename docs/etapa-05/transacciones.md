# Etapa V – Manejo de transacciones

## 1. Definición y objetivo

### ¿Qué es una transacción?

Una **transacción** es un conjunto de operaciones SQL que el motor ejecuta como **una sola unidad de trabajo**: o se realizan **todas**, o no se realiza **ninguna**. Si algo falla a mitad de camino, la base de datos vuelve al estado que tenía antes de empezar.

### Sentencias de control de transacciones en SQL Server

| Sentencia | Qué hace |
|---|---|
| `BEGIN TRANSACTION` | Inicia la transacción. Desde acá los cambios son provisorios. |
| `COMMIT TRANSACTION` | **Confirma** la transacción: los cambios se guardan de forma permanente. |
| `ROLLBACK TRANSACTION` | **Deshace** todos los cambios realizados desde el `BEGIN TRANSACTION`. |
| `BEGIN TRY ... BEGIN CATCH` | Captura errores de ejecución y permite reaccionar (por ejemplo, haciendo `ROLLBACK`). |

### Propiedades ACID

| Propiedad | Significado | Cómo se cumple en este proyecto |
|---|---|---|
| **A**tomicidad | Todo o nada. | Si falta stock o hay un error, el `ROLLBACK` deshace lo hecho. |
| **C**onsistencia | La base pasa de un estado válido a otro válido. | Se respetan los `CHECK`, `FOREIGN KEY` y `UNIQUE`; el stock nunca queda negativo. |
| **A**islamiento | Una transacción no interfiere con otra en curso. | Nivel por defecto de SQL Server (`READ COMMITTED`). |
| **D**urabilidad | Lo confirmado no se pierde. | `COMMIT TRANSACTION` guarda los cambios de forma permanente. |

### Objetivo en este proyecto

1. **Registrar una venta completa** (encabezado, detalle, pago y descuento de stock) como una operación indivisible.
2. **Cancelar toda la operación** si no hay stock suficiente (regla de negocio RN.01), sin dejar datos parciales.
3. **Deshacer todo ante cualquier error inesperado** (violación de clave foránea, tipo de dato incorrecto, restricción `CHECK`).

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aprovecha en el sistema |
|---|---|
| **Integridad:** evita datos a medias. | Nunca queda una venta sin detalle ni un detalle sin pago. |
| **Consistencia del stock:** el inventario siempre coincide con lo vendido. | El stock se descuenta en la misma transacción que registra la venta. |
| **Recuperación ante errores:** el sistema vuelve al estado anterior. | El bloque `CATCH` hace `ROLLBACK` automáticamente ante cualquier falla. |
| **Reglas de negocio centralizadas:** la validación vive en la base. | La regla RN.01 se aplica sin importar desde qué aplicación se registre la venta. |
| **Operación única:** una sola llamada hace todo el proceso. | El procedimiento almacenado recibe los datos y resuelve los cuatro pasos. |

**Aplicaciones habituales:** ventas y facturación, transferencias bancarias, reservas, movimientos de inventario y cualquier proceso que modifique varias tablas a la vez.

---

## 3. Implementación en SQL Server

Script asociado:

| Script | Contenido |
|---|---|
| [`sql/tecnico/transacciones/implementacion_transacciones.sql`](../../sql/tecnico/transacciones/implementacion_transacciones.sql) | Procedimiento almacenado con la transacción y casos de prueba. |
| [`sql/tecnico/transacciones/demostracion_transacciones.sql`](../../sql/tecnico/transacciones/demostracion_transacciones.sql) | Casos de Prueba. |

### Objetos creados

| Objeto | Tipo | Función |
|---|---|---|
| `sp_RegistrarVentaTransaccional` | Procedimiento almacenado | Registra una venta completa dentro de una transacción. |

### Reglas de negocio implementadas

| Código | Regla | Dónde se aplica |
|---|---|---|
| **RN.01** | No se puede vender más cantidad que el stock disponible. | `IF @stock_actual < @cantidad` |
| **RN.02** | Al registrar una venta se descuenta el stock del producto. | Paso E: `UPDATE PRODUCTO SET stock = stock - @cantidad` |

### 3.1 Procedimiento almacenado

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

        DECLARE @stock_actual INT;
        DECLARE @precio_unitario DECIMAL(10,2);
        DECLARE @total DECIMAL(10,2);
        DECLARE @id_venta_nueva INT;

        -- Paso A: obtener datos del producto
        SELECT @stock_actual = stock, @precio_unitario = precio
        FROM PRODUCTO 
        WHERE id_producto = @id_producto;

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

### Parámetros de entrada

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@id_usuario` | `INT` | Cliente que realiza la compra. |
| `@domicilio_entrega` | `VARCHAR(150)` | Dirección de entrega. |
| `@id_producto` | `INT` | Producto comprado. |
| `@cantidad` | `INT` | Unidades compradas. |
| `@id_metodo_pago` | `INT` | Método de pago utilizado. |

### Explicación de los elementos

| Elemento | Explicación |
|---|---|
| `CREATE OR ALTER PROCEDURE` | Crea el procedimiento o lo modifica si ya existe. |
| `SET NOCOUNT ON` | Evita los mensajes de "filas afectadas". |
| `BEGIN TRY ... END TRY` | Contiene el código que puede fallar. |
| `BEGIN TRANSACTION` | Abre la transacción: los cambios son provisorios hasta el `COMMIT`. |
| `DECLARE` | Declara las variables locales (stock, precio, total, id de la nueva venta). |
| `IF @stock_actual < @cantidad` | Implementa RN.01. Si no alcanza el stock, se hace `ROLLBACK` y se sale. |
| `RETURN` | Termina el procedimiento inmediatamente. |
| `SCOPE_IDENTITY()` | Devuelve el último `id` generado por `IDENTITY` en el ámbito actual (el `id_venta` nuevo), para vincular detalle y pago. |
| `GETDATE()` | Fecha y hora actual del servidor. |
| `COMMIT TRANSACTION` | Confirma todos los cambios de forma permanente. |
| `BEGIN CATCH ... END CATCH` | Se ejecuta solo si ocurre un error dentro del `TRY`. |
| `@@TRANCOUNT` | Cantidad de transacciones abiertas. Si es mayor a 0, hay algo que deshacer. |
| `ROLLBACK TRANSACTION` | Deshace todo lo hecho desde `BEGIN TRANSACTION`. |
| `ERROR_MESSAGE()` | Devuelve el texto del error capturado. |
| `PRINT` | Muestra un mensaje al usuario. |

### 3.2 Flujo de la transacción

```
INICIO
  │
  ▼
BEGIN TRANSACTION
  │
  ▼
Paso A: leer stock y precio del producto
  │
  ▼
¿stock_actual < cantidad? ── SÍ ──► ROLLBACK + mensaje + RETURN (sin cambios)
  │
  NO
  ▼
Paso B: INSERT en VENTA            (total = cantidad × precio)
  │
  ▼
Paso C: INSERT en VENTA_DETALLE    (usa SCOPE_IDENTITY)
  │
  ▼
Paso D: INSERT en VENTA_PAGO
  │
  ▼
Paso E: UPDATE de stock en PRODUCTO
  │
  ▼
COMMIT TRANSACTION ──► "ÉXITO"

Ante cualquier error SQL en los pasos B a E ──► CATCH ──► ROLLBACK + "ERROR INESPERADO"
```

---

## 4. Caso concreto aplicado al sistema de ventas

### ¿Por qué usar una transacción para registrar una venta?

Registrar una venta modifica **cuatro tablas** a la vez:

| Paso | Tabla | Operación |
|---|---|---|
| B | `VENTA` | `INSERT` del encabezado. |
| C | `VENTA_DETALLE` | `INSERT` del producto y la cantidad. |
| D | `VENTA_PAGO` | `INSERT` del pago. |
| E | `PRODUCTO` | `UPDATE` para descontar el stock. |

Sin transacción, un error en el paso D o E dejaría una venta registrada sin pago o con el stock sin descontar: datos **inconsistentes** que luego son difíciles de detectar y corregir.

### ¿Por qué se valida el stock antes de insertar?

La regla **RN.01** impide vender más de lo disponible. Se verifica **antes** de insertar nada, y si no alcanza se cancela toda la operación. Además, la tabla `PRODUCTO` tiene la restricción `CHECK (stock >= 0)` como segunda línea de defensa.

### ¿Por qué se usa `SCOPE_IDENTITY()`?

El `id_venta` se genera automáticamente (`IDENTITY`). Para insertar el detalle y el pago hay que conocer ese número, y `SCOPE_IDENTITY()` lo devuelve de forma segura sin confundirlo con identidades generadas por otros triggers o sesiones.

### ¿Por qué el `CATCH` verifica `@@TRANCOUNT`?

Para hacer `ROLLBACK` solo si hay una transacción abierta. Si el error ocurriera antes del `BEGIN TRANSACTION`, intentar un `ROLLBACK` generaría un nuevo error.

### Restricciones de la tabla que protegen la operación

| Restricción | Tabla | Qué evita |
|---|---|---|
| `CK_PRODUCTO_stock` | `PRODUCTO` | Stock negativo. |
| `CK_VENTA_total` | `VENTA` | Totales menores o iguales a 0. |
| `CK_VENTA_DETALLE_calculo` | `VENTA_DETALLE` | Subtotal distinto de `cantidad * precio_unitario`. |
| `CK_VENTA_PAGO_monto` | `VENTA_PAGO` | Pagos menores o iguales a 0. |
| `FOREIGN KEY` | Varias | Usuarios, productos o métodos de pago inexistentes. |

---

## 5. Demostración y resultados

Las pruebas usan el procedimiento con los datos de prueba cargados. Script completo: [`Transacciones.sql`](sql/tecnico/transacciones/Transacciones.sql).

> Los `id_venta` de los resultados (11) corresponden a una base recién cargada con el script de datos de prueba. Pueden variar si se insertaron ventas adicionales (por ejemplo, si antes se ejecutó la demostración de triggers). La fecha depende del momento de ejecución.

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



---

### Caso 1 – Venta correcta (stock suficiente)

```sql
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba', 
    @id_producto = 1,       -- Ryzen 5 5600
    @cantidad = 2, 
    @id_metodo_pago = 1;    -- Efectivo
```

**Mensaje esperado (pestaña "Mensajes"):**

```
ÉXITO: Venta registrada, pago asentado y stock actualizado correctamente.
```

> **Captura 2:** mensaje de éxito.
> <img width="1204" height="413" alt="image" src="https://github.com/user-attachments/assets/59979299-65f4-472c-b6c2-451b95e6ffe3" />


**Verificación:**

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
```

**Resultado esperado:**

| Tabla | Resultado esperado |
|---|---|
| `VENTA` | Nueva fila: `id_venta = 11`, estado `Entregado`, domicilio `Belgrano 456, Córdoba`, total `440000.00`, usuario 2. |
| `VENTA_DETALLE` | Nueva fila: cantidad `2`, precio unitario `220000.00`, subtotal `440000.00`, producto 1, venta 11. |
| `VENTA_PAGO` | Nueva fila: monto `440000.00`, venta 11, método 1 (Efectivo). |
| `PRODUCTO` (id 1) | Stock baja de **14 a 12**. |

> **Captura 3:** las cuatro consultas de verificación.
> <img width="1204" height="418" alt="image" src="https://github.com/user-attachments/assets/3d125770-edc5-4b72-b8a6-c56b1af05ca1" />

**Qué demuestra:** las cuatro tablas se modificaron de forma coordinada y se confirmaron juntas con `COMMIT`. El total (`2 × 220000.00`) coincide con el pago, y el stock refleja la venta.

---

### Caso 2 – Venta incorrecta (stock insuficiente)

```sql
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 3, 
    @domicilio_entrega = 'Sarmiento 789, Rosario', 
    @id_producto = 3,       -- RTX 3060
    @cantidad = 10, 
    @id_metodo_pago = 2;    -- Tarjeta de Débito
```

**Mensaje esperado:**

```
OPERACIÓN CANCELADA: Stock insuficiente para el producto solicitado.
```

> **Captura 4:** mensaje de operación cancelada.
> <img width="1204" height="413" alt="image" src="https://github.com/user-attachments/assets/cb8bb5de-944f-43e1-bb70-afbae089bbf0" />


**Verificación:**

```sql
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 3;
```

**Resultado esperado:**

| Tabla | Resultado esperado |
|---|---|
| `VENTA` | La última venta sigue siendo la **11** (la del caso 1). No se creó ninguna nueva. |
| `VENTA_DETALLE` | El último detalle es el del caso 1. No hay un detalle suelto. |
| `VENTA_PAGO` | No se registró ningún pago nuevo. |
| `PRODUCTO` (id 3) | El stock **sigue en 4**. |

> **Captura 5:** consultas de verificación tras la prueba fallida.
> <img width="1204" height="412" alt="image" src="https://github.com/user-attachments/assets/c2525bff-f47e-4dbe-8e84-56755b486e68" />


**Qué demuestra:** la **Atomicidad**. Al no cumplirse RN.01, la operación se cancela completa y no queda ningún dato parcial.

---

## 6. Conclusiones

1. **Atomicidad comprobada.** El caso 1 modificó cuatro tablas de forma coordinada y confirmó todo junto. El caso 2 canceló la operación completa y no dejó ni una fila parcial.

2. **Consistencia del inventario.** El descuento de stock ocurre dentro de la misma transacción que el registro de la venta, por lo que el stock siempre coincide con lo vendido. La regla RN.01 impide vender más de lo disponible.

3. **Recuperación ante errores.** El bloque `TRY...CATCH` con `ROLLBACK` asegura que cualquier error (clave foránea, tipo de dato o restricción `CHECK`) deje la base como estaba, sin intervención manual.

4. **Un solo punto de entrada.** El procedimiento almacenado centraliza el proceso de venta, de modo que cualquier aplicación que lo utilice queda sujeta a las mismas reglas.

5. **Limitaciones y posibles mejoras.**
   - **Producto inexistente:** hoy lo detecta el `CATCH` de forma indirecta. Se podría validar antes con un mensaje más claro.
   - **Concurrencia:** entre leer y descontar el stock, otra sesión podría vender el mismo producto. Se podría leer con `WITH (UPDLOCK, ROWLOCK)` para bloquear la fila durante la transacción.
   - **Alcance:** cada llamada registra un solo producto y un solo pago.
   - **Identidad consumida:** ante un error posterior al `INSERT` en `VENTA`, el `ROLLBACK` deshace la fila pero el número de `IDENTITY` se pierde, y pueden quedar saltos en los `id`.

---
