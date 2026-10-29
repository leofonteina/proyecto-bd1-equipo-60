--DESCUENTO POR METODO DE PAGO
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

--IMPORTE TOTAL POR METODO DE PAGO:
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

--DISPONIBILIDAD DE STOCK
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

--HISTORIAL DE COMPRAS
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
