# Funciones Almacenadas (User-Defined Functions)

El presente documento desarrolla la investigación, implementación y validación de las **Funciones Almacenadas** en SQL Server Express aplicadas al sistema de gestión de ventas del equipo, abarcando tanto funciones escalares como funciones con valores de tabla.

---

## 1. Definición y Objetivo

Las **Funciones Almacenadas** (*User-Defined Functions* o UDF) son rutinas programadas en T-SQL que se almacenan en la base de datos, reciben parámetros de entrada, procesan cálculos o consultas de lectura y **devuelven obligatoriamente un resultado** (ya sea un único valor escalar o una tabla).

### Objetivos dentro del sistema:
* **Encapsular cálculos comerciales y financieros:** Determinar porcentajes de descuento e importes netos a cobrar según el método de pago seleccionado sin repetir fórmulas en las consultas.
* **Estandarizar diagnósticos operativos:** Evaluar en tiempo real el estado y nivel de inventario de los artículos del catálogo para emitir alertas de reposición.
* **Simplificar consultas complejas mediante funciones tabulares:** Consolidar el historial de compras válidas de un cliente específico en una estructura reutilizable como si fuera una vista parametrizada.

---

## 2. Ventajas y Aplicaciones

1. **Reutilización de lógica de negocio:** Permiten que una función invoque a otra (por ejemplo, `dbo.fn_CalcularImporteConDescuento` reutiliza internamente el resultado de `dbo.fn_PorcentajeDescuentoMetodoPago`), evitando duplicar reglas comerciales.
2. **Reducción de código repetido:** Las reglas de descuento, diagnóstico de stock y resumen de compras se escriben una única vez en el motor de base de datos.
3. **Mejora de la mantenibilidad:** Si la empresa modifica los porcentajes de beneficio por medio de pago o el umbral de stock crítico, el cambio se realiza únicamente dentro de la función sin alterar las consultas ni la aplicación cliente.
4. **Integración directa en consultas `SELECT`:** A diferencia de los procedimientos almacenados, las funciones pueden invocarse directamente en las cláusulas `SELECT`, `WHERE` o `FROM` (en el caso de funciones con valores de tabla).
5. **Seguridad sobre los datos:** Permiten exponer resultados calculados o resúmenes filtrados a los usuarios otorgando permisos sobre la función sin necesidad de exponer la lógica interna.

---

## 3. Implementación en SQL Server Express

### Descuento por Método de Pago (`dbo.fn_PorcentajeDescuentoMetodoPago`)
Recibe el identificador del método de pago y retorna el porcentaje de descuento aplicable.

```sql
CREATE FUNCTION dbo.fn_PorcentajeDescuentoMetodoPago
(
    @id_metodo_pago INT
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @porcentaje DECIMAL(5,2);

    SET @porcentaje = CASE @id_metodo_pago
        WHEN 1 THEN 15.00  -- Efectivo: 15%
        WHEN 4 THEN 10.00  -- Mercado Pago: 10%
        WHEN 5 THEN 10.00  -- MODO: 10%
        WHEN 2 THEN 5.00   -- Tarjeta de Débito: 5%
        ELSE 0.00          -- Tarjeta de Crédito (3), Cheque (6) u otros: 0%
    END;

    RETURN @porcentaje;
END;

```

###  Importe Total por Método de Pago (`dbo.fn_CalcularImporteConDescuento`)
Recibe un importe bruto y el identificador del medio de pago, reutiliza la función `dbo.fn_PorcentajeDescuentoMetodoPago` y devuelve el monto final neto con el descuento aplicado.

```sql
CREATE FUNCTION dbo.fn_CalcularImporteConDescuento
(
    @importe_bruto DECIMAL(10,2),
    @id_metodo_pago INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @porcentaje_descuento DECIMAL(5,2);
    DECLARE @importe_final DECIMAL(10,2);

    -- Se obtiene el porcentaje reutilizando la Función 1
    SET @porcentaje_descuento = dbo.fn_PorcentajeDescuentoMetodoPago(@id_metodo_pago);

    -- Se calcula el importe final restando el descuento
    SET @importe_final = ROUND(@importe_bruto * (1 - (@porcentaje_descuento / 100.00)), 2);

    RETURN @importe_final;
END;

```

### 3.Disponibilidad de Stock (`dbo.fn_EstadoStockProducto`)
Recibe el identificador de un producto, evalúa su vigencia (`estado`) y cantidad disponible (`stock`), y retorna una etiqueta diagnóstica.

```sql
CREATE FUNCTION dbo.fn_EstadoStockProducto
(
    @id_producto INT
)
RETURNS VARCHAR(30)
AS
BEGIN
    DECLARE @stock INT;
    DECLARE @estado INT;
    DECLARE @resultado VARCHAR(30);

    SELECT 
        @stock = stock, 
        @estado = estado
    FROM dbo.PRODUCTO
    WHERE id_producto = @id_producto;

    IF @stock IS NULL
        SET @resultado = 'Producto Inexistente';
    ELSE IF @estado = 0
        SET @resultado = 'Discontinuado / Inactivo';
    ELSE IF @stock = 0
        SET @resultado = 'Sin Stock';
    ELSE IF @stock <= 5
        SET @resultado = 'Stock Crítico (Reponer)';
    ELSE
        SET @resultado = 'Stock Disponible';

    RETURN @resultado;
END;

```

### 3.4. Función con Valores de Tabla: Historial de Compras (`dbo.fn_HistorialComprasCliente`)
Recibe el identificador de un usuario y retorna una tabla con todas sus compras válidas (`estado <> 'Cancelado'`), sumando el total de unidades adquiridas en cada operación.

```sql
CREATE FUNCTION dbo.fn_HistorialComprasCliente
(
    @id_usuario INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        v.id_venta,
        v.fecha_venta,
        v.estado,
        SUM(vd.cantidad) AS total_unidades,
        v.total AS monto_facturado
    FROM dbo.VENTA v
    INNER JOIN dbo.VENTA_DETALLE vd ON v.id_venta = vd.id_venta
    WHERE v.id_usuario = @id_usuario
      AND v.estado <> 'Cancelado'
    GROUP BY v.id_venta, v.fecha_venta, v.estado, v.total
);



## 4. Caso Concreto Aplicado al Sistema de Ventas del Equipo

### Caso A: Política de beneficios y cálculo de importes según el medio de pago
* **Problema de negocio:** El comercio aplica promociones diferenciadas según el método de pago elegido en la tabla `METODO_PAGO` para incentivar los cobros inmediatos.
* **Lógica implementada:**
  * Pago en **Efectivo (`id_metodo_pago = 1`)** $\rightarrow 15\%$ de descuento.
  * Pago con billeteras virtuales **Mercado Pago (`4`)** o **MODO (`5`)** $\rightarrow 10\%$ de descuento.
  * Pago con **Tarjeta de Débito (`2`)** $\rightarrow 5\%$ de descuento.
  * Pago con **Tarjeta de Crédito (`3`)** o **Cheque (`6`)** $\rightarrow 0\%$ de descuento.
* **Aplicación:** `dbo.fn_PorcentajeDescuentoMetodoPago` informa el porcentaje de beneficio y `dbo.fn_CalcularImporteConDescuento` calcula automáticamente el monto neto aplicando la fórmula $\text{Importe Final} = \text{Importe Bruto} \times (1 - \frac{\text{Porcentaje}}{100})$.

### Caso B: Control de inventario y alerta temprana de stock crítico (RN.03)
* **Problema de negocio:** El área de compras necesita identificar rápidamente qué componentes informáticos están dados de baja (`estado = 0`), agotados (`stock = 0`) o en nivel crítico de reposición ($\text{stock} \le 5$).
* **Aplicación:** `dbo.fn_EstadoStockProducto` centraliza esta regla y clasifica cada registro de la tabla `PRODUCTO` sin necesidad de escribir estructuras condicionales en cada reporte de inventario.

### Caso C: Consulta rápida de operaciones válidas por cliente
* **Problema de negocio:** Para atención al cliente y auditoría comercial se requiere consultar el historial de compras de un usuario determinado, excluyendo ventas anuladas (`estado = 'Cancelado'`) y consolidando la cantidad de unidades por factura.
* **Aplicación:** `dbo.fn_HistorialComprasCliente(@id_usuario)` devuelve directamente el conjunto de filas filtrado y agrupado, listo para ser consultado con un simple `SELECT * FROM`.

---

## 5. Script de Demostración y Resultados Obtenidos

### 5.1. Prueba de Funciones de Descuento e Importe Final por Método de Pago
Se simula una operación por un monto bruto de $\$100.000,00$ evaluando todos los registros de la tabla `METODO_PAGO`:

```sql
SELECT 
    id_metodo_pago,
    descripcion AS Metodo_Pago,
    dbo.fn_PorcentajeDescuentoMetodoPago(id_metodo_pago) AS Porcentaje_Descuento,
    CAST(100000.00 AS DECIMAL(10,2)) AS Monto_Bruto,
    dbo.fn_CalcularImporteConDescuento(100000.00, id_metodo_pago) AS Monto_Final_Con_Descuento
FROM dbo.METODO_PAGO;
```

#### Resultado obtenido:


<img width="508" height="161" alt="image" src="https://github.com/user-attachments/assets/1464dd2c-0a02-4aa6-82b8-3d98d1dfbbe3" />

---

### 5.2. Prueba de la Función de Disponibilidad de Stock
Se ejecuta la función sobre el catálogo completo de la tabla `PRODUCTO` (considerando las actualizaciones de stock y bajas lógicas del script DML):

```sql
SELECT 
    id_producto,
    nombre,
    stock,
    estado,
    dbo.fn_EstadoStockProducto(id_producto) AS Diagnostico_Stock
FROM dbo.PRODUCTO;
```

#### Resultado obtenido:

<img width="434" height="221" alt="image" src="https://github.com/user-attachments/assets/8ad5cc84-dfce-4588-b91d-1adab11029e4" />


> **Observación:** El producto `3` (*RTX 3060 12GB*) quedó con $4$ unidades tras las ventas registradas ($\le 5$), por lo que la función dispara el diagnóstico `Stock Crítico (Reponer)`. Por su parte, los productos `4` y `8` fueron dados de baja en el DML (`estado = 0`), reflejando `Discontinuado / Inactivo`.

---

### 5.3. Prueba de la Función con Valores de Tabla: Historial de Compras por Cliente
Se consulta el historial de compras válidas de la cliente **Laura Perez (`id_usuario = 2`)**:

```sql
SELECT * FROM dbo.fn_HistorialComprasCliente(2);
```

#### Resultado obtenido:
<img width="491" height="177" alt="image" src="https://github.com/user-attachments/assets/4565232b-c8c5-46c0-b915-3546becf3d53" />


> **Observación:** La función consolida los $3$ renglones de la venta `1` ($1 + 1 + 2 = 4$ unidades por $\$530.000,00$) y los $2$ renglones de la venta `10` ($1 + 2 = 3$ unidades por $\$360.000,00$).


---

# Procedimientos Almacenados (Stored Procedures)

El presente apartado desarrolla la investigación, implementación y validación de los **Procedimientos Almacenados** en SQL Server Express aplicados al sistema de gestión de ventas del equipo, tomando como caso central el registro de una venta completa de forma atómica.

---
## 1. Definición y Objetivo

Los **Procedimientos Almacenados** (*Stored Procedures* o SP) son rutinas programadas en T-SQL que se almacenan en la base de datos, reciben parámetros de entrada, ejecutan un conjunto de instrucciones (consultas, inserciones, actualizaciones, control de flujo y transacciones) y se invocan mediante `EXEC`. A diferencia de las funciones, **pueden modificar datos** y no están obligados a devolver un valor.

### Objetivos dentro del sistema:
* **Centralizar el registro de ventas:** Encapsular en una única operación la inserción en `VENTA`, `VENTA_DETALLE` y `VENTA_PAGO`, junto con el descuento de stock en `PRODUCTO`.
* **Permitir ventas de varios productos:** Recibir el carrito completo en un único parámetro de tipo tabla y consolidar los productos repetidos.
* **Garantizar la integridad de los datos:** Utilizar una transacción para que la venta se registre completa o no se registre en absoluto.
* **Aplicar las reglas de negocio en el motor:** Validar domicilio, cantidades, usuario, método de pago, estado del producto y stock disponible antes de modificar cualquier tabla.
* **Permitir cancelar ventas:** Revertir una venta pendiente y reponer el stock en una única operación atómica.
* **Reutilizar las funciones almacenadas:** Integrar el cálculo de descuentos y el diagnóstico de stock desarrollados como funciones.

---

## 2. Ventajas y Aplicaciones

1. **Atomicidad mediante transacciones:** Si falta stock o alguna validación falla, no se inserta ni se modifica nada. Solo se confirma (`COMMIT`) cuando todas las operaciones se completaron, y ante cualquier error se deshace todo (`ROLLBACK`).
2. **Reducción de código repetido:** La lógica de venta se escribe una sola vez y se invoca con un simple `EXEC`, en lugar de repetir cuatro sentencias en cada aplicación.
3. **Mejora de la mantenibilidad:** Si cambia una regla (por ejemplo, el umbral de stock crítico o un porcentaje de descuento), se modifica en la función correspondiente sin tocar el procedimiento ni la aplicación cliente.
4. **Validaciones centralizadas:** Los datos inválidos se rechazan con errores numerados y mensajes claros (`THROW`) antes de llegar a las tablas.
5. **Control de concurrencia:** Los bloqueos `UPDLOCK` sobre las filas de `PRODUCTO` y `VENTA` evitan que dos operaciones simultáneas vendan o cancelen sobre el mismo stock.
6. **Seguridad:** Se puede otorgar permiso de ejecución sobre el procedimiento sin dar acceso directo de escritura a las tablas. Además, el usuario se toma de la sesión (`SESSION_CONTEXT`) y no de un parámetro, por lo que no se puede vender ni cancelar a nombre de otra persona.
7. **Menor tráfico entre aplicación y servidor:** Una sola llamada reemplaza múltiples consultas y escrituras.

---

## 3. Implementación en SQL Server Express

### Tipo de tabla para los ítems de la venta (`dbo.tipo_item_venta`)
Permite enviar al procedimiento varios productos en un único parámetro:

```sql
CREATE TYPE dbo.tipo_item_venta AS TABLE
(
    id_producto INT NOT NULL,
    cantidad INT NOT NULL
);
```

### Registro de Venta (`dbo.sp_RegistrarVenta`)
Recibe el domicilio de entrega, el método de pago y los productos a vender. El usuario se obtiene de la sesión. Valida los datos, consolida los productos repetidos, calcula el importe con descuento y registra la venta, su detalle, su pago y el descuento de stock dentro de una transacción.

**Parámetros:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@domicilio_entrega` | VARCHAR(150) | Domicilio de entrega de la venta |
| `@id_metodo_pago` | INT | Método de pago elegido |
| `@items` | `dbo.tipo_item_venta` (READONLY) | Productos y cantidades a vender |
| `@id_venta` | INT (OUTPUT) | Id de la venta generada (`NULL` si hubo error) |

> **Usuario de la sesión:** el procedimiento lee el usuario con `SESSION_CONTEXT(N'id_usuario')`, que la aplicación (o la prueba) fija previamente con `EXEC sp_set_session_context @key = N'id_usuario', @value = 2;`.

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

        -- GROUP BY consolida los productos repetidos en una sola linea
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
```

### Funcionamiento paso a paso (`sp_RegistrarVenta`)

1. **Identificación del usuario:** se lee el `id_usuario` desde `SESSION_CONTEXT`. Si la sesión no lo tiene, se rechaza la operación.
2. **Validaciones previas:** domicilio no vacío, al menos un producto, cantidades mayores a cero, usuario existente y activo, y método de pago existente. Cada falla lanza un `THROW` con su número de error.
3. **Consolidación de productos:** los ítems se agrupan por producto (`GROUP BY`), de modo que un producto repetido queda en una sola línea con la cantidad sumada. Se controla que la suma no desborde el tipo `INT`.
4. **Lectura y bloqueo de productos:** se obtienen precio, stock y estado de cada producto con `UPDLOCK`, para que nadie más modifique ese stock hasta terminar la transacción.
5. **Validación de productos:** se rechazan productos inexistentes, discontinuados o con stock insuficiente.
6. **Cálculo del importe:** el total bruto es la suma de `precio × cantidad` y el importe final se obtiene con `dbo.fn_CalcularImporteConDescuento`.
7. **Escritura:** se insertan la venta, el detalle (una fila por producto) y el pago, se descuenta el stock y se confirma con `COMMIT`.
8. **Resultado y aviso de reposición:** se devuelve el id, el total y la cantidad de productos, y una segunda tabla con los productos que quedaron en estado crítico o sin stock.
9. **Manejo de errores:** si algo falla en cualquier punto, el `CATCH` deshace la transacción (`ROLLBACK`), deja `@id_venta` en `NULL` y vuelve a lanzar el error original.

### Cancelación de Venta (`dbo.sp_CancelarVenta`)
Cancela una venta pendiente del usuario de la sesión y repone el stock de sus productos.

**Parámetros:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@id_venta` | INT | Venta a cancelar |

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
```

### Funcionamiento paso a paso (`sp_CancelarVenta`)

1. **Identificación del usuario:** se lee el usuario de la sesión, igual que en el registro.
2. **Bloqueo y lectura de la venta:** se obtienen el propietario y el estado de la venta con `UPDLOCK`.
3. **Validaciones:** la venta debe existir, pertenecer al usuario de la sesión y estar en estado `Pendiente`.
4. **Reposición de stock:** se suman las cantidades vendidas por producto y se devuelven a `PRODUCTO`.
5. **Cambio de estado:** la venta pasa a `Cancelado` y se confirma con `COMMIT`. Ante cualquier error se hace `ROLLBACK` y se relanza el error.

### Integración con las funciones almacenadas

El procedimiento reutiliza las funciones de la sección anterior en forma encadenada:

`sp_RegistrarVenta` → `fn_CalcularImporteConDescuento` → `fn_PorcentajeDescuentoMetodoPago`

`sp_RegistrarVenta` → `fn_EstadoStockProducto`

De esta forma el procedimiento no conoce los porcentajes de descuento ni el umbral de stock crítico: esas reglas viven únicamente en las funciones.

---

## 4. Caso Concreto Aplicado al Sistema de Ventas del Equipo

### Caso A: Registro atómico de una venta con descuento según el medio de pago
* **Problema de negocio:** Registrar una venta implica escribir en cuatro tablas (`VENTA`, `VENTA_DETALLE`, `VENTA_PAGO` y `PRODUCTO`). Si una de las escrituras falla o no hay stock, no deben quedar datos parciales.
* **Aplicación:** `dbo.sp_RegistrarVenta` ejecuta todas las operaciones dentro de una transacción, consolida los productos repetidos, aplica el descuento del método de pago y descuenta el stock en la misma operación.
* **Decisión de diseño:** `VENTA.total` y `VENTA_PAGO.monto` almacenan el importe **con descuento** (lo que realmente paga el cliente), mientras que `VENTA_DETALLE` conserva el precio unitario y el subtotal **bruto**. Esto respeta la restricción `CK_VENTA_DETALLE_calculo` (`subtotal = cantidad * precio_unitario`) de la tabla de detalle.

### Caso B: Validación de reglas de negocio antes de operar
* **Problema de negocio:** Evitar ventas a clientes dados de baja, con productos discontinuados, inexistentes o sin stock suficiente, y con datos inválidos como domicilios vacíos o cantidades nulas o negativas.
* **Aplicación:** El procedimiento valida cada condición antes de modificar las tablas y lanza un error numerado con un mensaje específico por cada caso:

| Error | Condición | Mensaje |
|---|---|---|
| 50001 | Usuario sin identificar en la sesión | No se pudo identificar al usuario de la sesion. |
| 50002 | Domicilio vacío | El domicilio de entrega es obligatorio. |
| 50003 | Venta sin productos | La venta debe incluir al menos un producto. |
| 50004 | Cantidad menor o igual a cero | Todas las cantidades deben ser mayores a cero. |
| 50005 | Usuario inexistente | El usuario no existe. |
| 50006 | Usuario dado de baja | El usuario se encuentra dado de baja. |
| 50007 | Método de pago inexistente | El metodo de pago no existe. |
| 50008 | Cantidad total que desborda el límite | La cantidad total de un producto supera el limite permitido. |
| 50009 | Producto inexistente | Uno o mas productos no existen. |
| 50010 | Producto discontinuado | Uno o mas productos se encuentran discontinuados. |
| 50011 | Cantidad mayor al stock | Stock insuficiente para uno o mas productos. |

### Caso C: Alerta de reposición posterior a la venta (RN.03)
* **Problema de negocio:** El área de compras necesita enterarse en el momento en que un producto queda en nivel crítico de reposición.
* **Aplicación:** Luego del `COMMIT`, el procedimiento consulta `dbo.fn_EstadoStockProducto` para cada producto vendido y devuelve como segundo resultado los que quedaron en `Stock Crítico (Reponer)` o `Sin Stock`.

### Caso D: Cancelación de una venta con reposición de stock
* **Problema de negocio:** Un cliente puede arrepentirse de una compra pendiente. Al cancelarla, el stock debe volver al inventario y nadie más que el dueño de la venta debe poder cancelarla.
* **Aplicación:** `dbo.sp_CancelarVenta` verifica propietario y estado, repone el stock de cada producto del detalle y marca la venta como `Cancelado`, todo dentro de una transacción.

| Error | Condición | Mensaje |
|---|---|---|
| 50020 | Usuario sin identificar en la sesión | No se pudo identificar al usuario de la sesion. |
| 50021 | Venta inexistente | La venta indicada no existe. |
| 50022 | Venta de otro usuario | No tiene permisos para cancelar esta venta. |
| 50023 | Venta ya cancelada | La venta ya se encuentra cancelada. |
| 50024 | Venta no pendiente (por ejemplo, entregada) | Solo se pueden cancelar ventas pendientes. |

---

## 5. Script de Demostración y Resultados Obtenidos

### 5.1. Estado inicial de la base de datos
Antes de ejecutar el procedimiento se consulta el diagnóstico de stock del catálogo y los descuentos por método de pago:

```sql
SELECT id_producto, nombre, stock, estado,
       dbo.fn_EstadoStockProducto(id_producto) AS Diagnostico_Stock
FROM dbo.PRODUCTO;

SELECT id_metodo_pago, descripcion,
       dbo.fn_PorcentajeDescuentoMetodoPago(id_metodo_pago) AS Porcentaje_Descuento,
       dbo.fn_CalcularImporteConDescuento(100000.00, id_metodo_pago) AS Monto_Final
FROM dbo.METODO_PAGO;
```

#### Resultado obtenido:

<img width="415" height="419" alt="image" src="https://github.com/user-attachments/assets/bba08381-b9ca-47ab-8e06-d45321c514f3" />


> **Observación:** El estado inicial coincide con el DML: los productos `4` y `8` figuran como `Discontinuado / Inactivo`, el producto `3` como `Stock Crítico (Reponer)` y el resto como `Stock Disponible`.

---

### 5.2. Prueba de venta correcta con productos repetidos y descuento
El procedimiento lee el usuario de la sesión, por lo que antes de cada prueba se fija `id_usuario = 2` (cliente Laura Perez). Se envía el producto `5` dos veces y el producto `6` una vez, pagando con el método `2` (Tarjeta de Débito):

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_venta INT;

INSERT INTO @items (id_producto, cantidad) VALUES (5, 1), (6, 1), (5, 1);

EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 2, @items = @items, @id_venta = @id_venta OUTPUT;

SELECT v.id_venta, v.total, vd.id_producto, vd.cantidad, vd.subtotal, vp.monto
FROM VENTA v
JOIN VENTA_DETALLE vd ON vd.id_venta = v.id_venta
JOIN VENTA_PAGO vp ON vp.id_venta = v.id_venta
WHERE v.id_venta = @id_venta;
```

#### Resultado obtenido:

<img width="1389" height="730" alt="image" src="https://github.com/user-attachments/assets/760b0360-48ab-452b-a846-3e698a97cb20" />


> **Observación:** El procedimiento informa `Venta registrada correctamente.` con `cantidad_productos = 2`, aunque se enviaron tres ítems: el producto `5` repetido se consolidó en una sola línea de cantidad 2 (subtotal $\$130.000,00$), junto con el producto `6` (subtotal $\$90.000,00$). El subtotal bruto suma $\$220.000,00$, pero el total y el monto pagado son $\$209.000,00$, es decir, un 5% de descuento por pagar con Tarjeta de Débito. La segunda tabla de resultados (`estado_stock`) sale vacía porque ningún producto quedó en estado crítico.

---

### 5.3. Prueba de cancelación con reposición de stock
Se vende y se cancela una venta, consultando el stock del producto `5` antes de vender, después de vender y después de cancelar:

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_venta INT;

INSERT INTO @items (id_producto, cantidad) VALUES (5, 2);

SELECT stock AS stock_inicial FROM PRODUCTO WHERE id_producto = 5;
EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
SELECT stock AS stock_luego_de_vender FROM PRODUCTO WHERE id_producto = 5;
EXEC dbo.sp_CancelarVenta @id_venta = @id_venta;
SELECT stock AS stock_luego_de_cancelar FROM PRODUCTO WHERE id_producto = 5;
```

#### Resultado obtenido:

<img width="806" height="725" alt="image" src="https://github.com/user-attachments/assets/c113d498-e599-4b03-aba2-d3fc56e6d3b8" />


> **Observación:** Al vender, el stock del producto `5` baja en 2 unidades y, al cancelar, vuelve exactamente al valor inicial. El procedimiento informa `Venta cancelada y stock repuesto correctamente.` <!-- COMPLETAR con los valores de stock que muestra tu captura (inicial, luego de vender y luego de cancelar) -->

---

### 5.4. Prueba de validaciones y rechazo de operaciones inválidas en el registro
Se ejecuta el procedimiento con datos que deben ser rechazados. Cada llamada va dentro de un `TRY/CATCH` para mostrar el número y el mensaje del error:

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_venta INT;

-- Venta sin productos (50003)
BEGIN TRY
    EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;

-- Producto inactivo (50010)
INSERT INTO @items (id_producto, cantidad) VALUES (4, 1);
BEGIN TRY
    EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;

-- Stock insuficiente (50011)
DELETE FROM @items;
INSERT INTO @items (id_producto, cantidad) VALUES (3, 50);
BEGIN TRY
    EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;

-- Usuario inactivo (50006)
EXEC sp_set_session_context @key = N'id_usuario', @value = 6;
BEGIN TRY
    EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Güemes 303, Salta', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;
```

#### Resultado obtenido:

<img width="739" height="733" alt="image" src="https://github.com/user-attachments/assets/7c28aa7e-77ca-47e8-89b5-b6a6e1db288e" />

> **Observación:** Cada llamada es rechazada con su error específico: venta sin productos (`50003`), producto `4` inactivo (`50010`), pedido de 50 unidades del producto `3` (`50011`, stock insuficiente) y usuario `6` dado de baja (`50006`). En ningún caso se insertó ni se modificó nada, ya que el `CATCH` deshace la transacción.

---

### 5.5. Prueba de validaciones en la cancelación
Con el usuario `2` en sesión, se intenta cancelar una venta de otro usuario y una venta que ya fue entregada:

```sql
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

-- Venta de otro usuario (50022)
BEGIN TRY
    EXEC dbo.sp_CancelarVenta @id_venta = 2;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;

-- Venta que no esta pendiente (50024)
BEGIN TRY
    EXEC dbo.sp_CancelarVenta @id_venta = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje_error;
END CATCH;
```

#### Resultado obtenido:

<img width="953" height="735" alt="image" src="https://github.com/user-attachments/assets/2ed00e8d-904e-48a8-9639-5608a8f9b19e" />


> **Observación:** La venta `2`, que pertenece a otro usuario, es rechazada con el error `50022` (sin permisos), y la venta `1`, que ya fue entregada, con el error `50024` (solo se pueden cancelar ventas pendientes). En ambos casos el stock y el estado de las ventas permanecen sin cambios.
