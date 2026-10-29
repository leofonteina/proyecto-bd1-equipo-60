--CASO 1
PRINT '--- EJECUTANDO PRUEBA 1: STOCK SUFICIENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba', 
    @id_producto = 1, 
    @cantidad = 2, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;

SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;

SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;

--CASO 2
PRINT '--- EJECUTANDO PRUEBA 2: STOCK INSUFICIENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 3, 
    @domicilio_entrega = 'Sarmiento 789, Rosario', 
    @id_producto = 3, 
    @cantidad = 10, 
    @id_metodo_pago = 2; 

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;

SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 3;
