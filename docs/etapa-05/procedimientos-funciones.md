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
* **Garantizar la integridad de los datos:** Utilizar una transacción para que la venta se registre completa o no se registre en absoluto.
* **Aplicar las reglas de negocio en el motor:** Validar cantidad, usuario, método de pago, estado del producto y stock disponible antes de modificar cualquier tabla.
* **Reutilizar las funciones almacenadas:** Integrar el cálculo de descuentos y el diagnóstico de stock desarrollados como funciones.

---

## 2. Ventajas y Aplicaciones

1. **Atomicidad mediante transacciones:** Si falta stock o alguna validación falla, no se inserta ni se modifica nada. Solo se confirma (`COMMIT`) cuando todas las operaciones se completaron.
2. **Reducción de código repetido:** La lógica de venta se escribe una sola vez y se invoca con un simple `EXEC`, en lugar de repetir cuatro sentencias en cada aplicación.
3. **Mejora de la mantenibilidad:** Si cambia una regla (por ejemplo, el umbral de stock crítico o un porcentaje de descuento), se modifica en la función correspondiente sin tocar el procedimiento ni la aplicación cliente.
4. **Validaciones centralizadas:** Los datos inválidos se rechazan con mensajes claros (`RAISERROR`) antes de llegar a las tablas.
5. **Seguridad:** Se puede otorgar permiso de ejecución sobre el procedimiento sin dar acceso directo de escritura a las tablas.
6. **Menor tráfico entre aplicación y servidor:** Una sola llamada reemplaza múltiples consultas y escrituras.

---

## 3. Implementación en SQL Server Express

### Registro de Venta (`dbo.sp_RegistrarVenta`)
Recibe el usuario, el domicilio de entrega, el producto, la cantidad y el método de pago. Valida los datos, calcula el importe con descuento y registra la venta, su detalle, su pago y el descuento de stock dentro de una transacción.

**Parámetros de entrada:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `@id_usuario` | INT | Cliente que realiza la compra |
| `@domicilio_entrega` | VARCHAR(150) | Domicilio de entrega de la venta |
| `@id_producto` | INT | Producto a vender |
| `@cantidad` | INT | Unidades solicitadas |
| `@id_metodo_pago` | INT | Método de pago elegido |

```sql
CREATE PROCEDURE dbo.sp_RegistrarVenta
    @id_usuario INT,
    @domicilio_entrega VARCHAR(150),
    @id_producto INT,
    @cantidad INT,
    @id_metodo_pago INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @stock_actual INT;
    DECLARE @precio_unitario DECIMAL(10,2);
    DECLARE @subtotal DECIMAL(10,2);
    DECLARE @importe_final DECIMAL(10,2);
    DECLARE @id_venta_generada INT;
    DECLARE @estado_stock VARCHAR(30);

    IF @cantidad IS NULL OR @cantidad <= 0
    BEGIN
        RAISERROR('La cantidad debe ser mayor a cero.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.USUARIO WHERE id_usuario = @id_usuario AND estado = 1)
    BEGIN
        RAISERROR('El usuario no existe o esta inactivo.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.METODO_PAGO WHERE id_metodo_pago = @id_metodo_pago)
    BEGIN
        RAISERROR('El metodo de pago no existe.', 16, 1);
        RETURN;
    END

    SET @estado_stock = dbo.fn_EstadoStockProducto(@id_producto);

    IF @estado_stock = 'Producto Inexistente'
    BEGIN
        RAISERROR('El producto no existe.', 16, 1);
        RETURN;
    END

    IF @estado_stock = 'Discontinuado / Inactivo'
    BEGIN
        RAISERROR('El producto se encuentra inactivo.', 16, 1);
        RETURN;
    END

    IF @estado_stock = 'Sin Stock'
    BEGIN
        RAISERROR('El producto no tiene stock disponible.', 16, 1);
        RETURN;
    END

    SELECT 
       @stock_actual = stock,
       @precio_unitario = precio
    FROM dbo.PRODUCTO
    WHERE id_producto = @id_producto AND estado = 1;

    SET @subtotal = @precio_unitario * @cantidad;
    SET @importe_final = dbo.fn_CalcularImporteConDescuento(@subtotal, @id_metodo_pago);

    BEGIN TRANSACTION;

    IF @stock_actual < @cantidad
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('Stock insuficiente para realizar la venta.', 16, 1);
    END
    ELSE
    BEGIN
        INSERT INTO dbo.VENTA (domicilio_entrega, total, fecha_venta, estado, id_usuario)
        VALUES (@domicilio_entrega, @importe_final, GETDATE(), 'Pendiente', @id_usuario);

        SET @id_venta_generada = SCOPE_IDENTITY();

        INSERT INTO dbo.VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        VALUES (@cantidad, @precio_unitario, @subtotal, @id_producto, @id_venta_generada);

        INSERT INTO dbo.VENTA_PAGO (id_venta, id_metodo_pago, monto)
        VALUES (@id_venta_generada, @id_metodo_pago, @importe_final);

        UPDATE dbo.PRODUCTO
        SET stock = stock - @cantidad
        WHERE id_producto = @id_producto;

        COMMIT TRANSACTION;

        SET @estado_stock = dbo.fn_EstadoStockProducto(@id_producto);

        IF @estado_stock IN ('Stock Crítico (Reponer)', 'Sin Stock')
            PRINT 'Atención: el producto quedó con estado "' + @estado_stock + '".';
    END
END;
```

### Funcionamiento paso a paso

1. **Validaciones previas (antes de abrir la transacción):** cantidad mayor a cero, usuario existente y activo (`estado = 1`) y método de pago existente. Si alguna falla, se informa con `RAISERROR` y se corta con `RETURN`.
2. **Diagnóstico del producto:** se invoca `dbo.fn_EstadoStockProducto` para rechazar productos inexistentes, discontinuados o sin stock.
3. **Obtención de datos:** se leen el stock y el precio vigente del producto activo.
4. **Cálculo del importe:** el subtotal bruto es `precio × cantidad` y el importe final se obtiene con `dbo.fn_CalcularImporteConDescuento`.
5. **Transacción:** se verifica que el stock alcance. Si no alcanza, `ROLLBACK` y error. Si alcanza, se insertan la venta, el detalle y el pago, se descuenta el stock y se confirma con `COMMIT`.
6. **Aviso de reposición:** una vez confirmada la venta, se vuelve a consultar el diagnóstico y, si el stock quedó crítico o en cero, se informa con `PRINT`.

### Integración con las funciones almacenadas

El procedimiento reutiliza las funciones de la sección anterior en forma encadenada:

`sp_RegistrarVenta` → `fn_CalcularImporteConDescuento` → `fn_PorcentajeDescuentoMetodoPago`

`sp_RegistrarVenta` → `fn_EstadoStockProducto`

De esta forma el procedimiento no conoce los porcentajes de descuento ni el umbral de stock crítico: esas reglas viven únicamente en las funciones.

---

## 4. Caso Concreto Aplicado al Sistema de Ventas del Equipo

### Caso A: Registro atómico de una venta con descuento según el medio de pago
* **Problema de negocio:** Registrar una venta implica escribir en cuatro tablas (`VENTA`, `VENTA_DETALLE`, `VENTA_PAGO` y `PRODUCTO`). Si una de las escrituras falla o no hay stock, no deben quedar datos parciales.
* **Aplicación:** `dbo.sp_RegistrarVenta` ejecuta todas las operaciones dentro de una transacción, aplica el descuento del método de pago y descuenta el stock en la misma operación.
* **Decisión de diseño:** `VENTA.total` y `VENTA_PAGO.monto` almacenan el importe **con descuento** (lo que realmente paga el cliente), mientras que `VENTA_DETALLE` conserva el precio unitario y el subtotal **bruto**. Esto respeta la restricción `CK_VENTA_DETALLE_calculo` (`subtotal = cantidad * precio_unitario`) de la tabla de detalle.

### Caso B: Validación de reglas de negocio antes de operar
* **Problema de negocio:** Evitar ventas a clientes dados de baja, con productos discontinuados, inexistentes o sin stock suficiente, y con datos inválidos como cantidades nulas o negativas.
* **Aplicación:** El procedimiento valida cada condición antes de abrir la transacción y devuelve un mensaje específico por cada caso:

| Condición | Mensaje |
|---|---|
| Cantidad menor o igual a cero | La cantidad debe ser mayor a cero. |
| Usuario inexistente o inactivo | El usuario no existe o esta inactivo. |
| Método de pago inexistente | El metodo de pago no existe. |
| Producto inexistente | El producto no existe. |
| Producto discontinuado | El producto se encuentra inactivo. |
| Producto agotado | El producto no tiene stock disponible. |
| Cantidad mayor al stock | Stock insuficiente para realizar la venta. |

### Caso C: Alerta de reposición posterior a la venta (RN.03)
* **Problema de negocio:** El área de compras necesita enterarse en el momento en que un producto queda en nivel crítico de reposición.
* **Aplicación:** Luego del `COMMIT`, el procedimiento consulta `dbo.fn_EstadoStockProducto` y, si el producto quedó con stock menor o igual a 5, emite el aviso `Atención: el producto quedó con estado "Stock Crítico (Reponer)".`

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

### 5.2. Prueba de ventas exitosas con distintos métodos de pago
Se vende una unidad del producto `1` (*Ryzen 5 5600*, $\$220.000,00$) a la cliente Laura Perez (`id_usuario = 2`) con los cuatro métodos de pago que tienen distinto descuento:

```sql
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 1;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 2;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 3;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 4;
```

#### Resultado obtenido:

<img width="602" height="85" alt="image" src="https://github.com/user-attachments/assets/3e84740c-f491-46fc-a4f6-ed58f7c106ef" />


Se verifica lo registrado en las tablas:

```sql
SELECT TOP 4 v.id_venta, v.total, vd.subtotal AS subtotal_bruto, vp.monto
FROM VENTA v
JOIN VENTA_DETALLE vd ON vd.id_venta = v.id_venta
JOIN VENTA_PAGO vp ON vp.id_venta = v.id_venta
ORDER BY v.id_venta DESC;
```

<img width="314" height="101" alt="image" src="https://github.com/user-attachments/assets/a2369e26-e4e9-4cda-be29-90b3fc6ff354" />


> **Observación:** El subtotal bruto es siempre $\$220.000,00$, pero el total y el monto pagado varían según el método de pago: $\$187.000,00$ en Efectivo (15%), $\$209.000,00$ en Tarjeta de Débito (5%), $\$220.000,00$ en Tarjeta de Crédito (0%) y $\$198.000,00$ en Mercado Pago (10%). Además, el stock del producto `1` pasó de 14 a 10 unidades.

---

### 5.3. Prueba de validaciones y rechazo de operaciones inválidas
Se ejecuta el procedimiento con datos que deben ser rechazados:

```sql
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 4, 1, 1;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 99, 1, 1;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 0, 1;
EXEC dbo.sp_RegistrarVenta 6, 'Güemes 303, Salta', 1, 1, 1;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 99;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 3, 50, 1;
```

#### Resultado obtenido:

<img width="984" height="239" alt="image" src="https://github.com/user-attachments/assets/030b3072-4c76-40be-afa7-da2248cd7e4a" />

> **Observación:** Cada llamada es rechazada con su mensaje específico: producto `4` inactivo, producto `99` inexistente, cantidad `0`, usuario `6` dado de baja, método de pago `99` inexistente y pedido de 50 unidades del producto `3` (stock insuficiente). En ningún caso se insertó ni se modificó nada.

---

### 5.4. Prueba del aviso de stock crítico
El producto `3` (*RTX 3060 12GB*) tiene 4 unidades. Se vende una y el procedimiento informa la necesidad de reposición:

```sql
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 3, 1, 1;

SELECT id_producto, nombre, stock, estado,
       dbo.fn_EstadoStockProducto(id_producto) AS Diagnostico_Stock
FROM dbo.PRODUCTO
WHERE id_producto = 3;
```

#### Resultado obtenido:

<img width="449" height="51" alt="image" src="https://github.com/user-attachments/assets/31dc6633-abd4-4f09-91c3-7e38cbb50c5c" />

> **Observación:** La venta se registra correctamente, el stock del producto `3` baja de 4 a 3 unidades y el procedimiento emite el aviso `Atención: el producto quedó con estado "Stock Crítico (Reponer)".`
