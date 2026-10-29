--PRUEBA DE METODO DE PAGO E IMPORTE:
SELECT 
    id_metodo_pago,
    descripcion AS Metodo_Pago,
    dbo.fn_PorcentajeDescuentoMetodoPago(id_metodo_pago) AS Porcentaje_Descuento,
    CAST(100000.00 AS DECIMAL(10,2)) AS Monto_Bruto,
    dbo.fn_CalcularImporteConDescuento(100000.00, id_metodo_pago) AS Monto_Final_Con_Descuento
FROM dbo.METODO_PAGO;


--PRUEBA DISPONIBILIDAD DE STOCK:
SELECT 
    id_producto,
    nombre,
    stock,
    estado,
    dbo.fn_EstadoStockProducto(id_producto) AS Diagnostico_Stock
FROM dbo.PRODUCTO;

--PRUEBA DE HISTORIAL DE COMPRA POR USUARIO:
SELECT * FROM dbo.fn_HistorialComprasCliente(2);
