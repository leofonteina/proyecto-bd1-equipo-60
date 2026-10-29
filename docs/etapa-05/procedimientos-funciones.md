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
