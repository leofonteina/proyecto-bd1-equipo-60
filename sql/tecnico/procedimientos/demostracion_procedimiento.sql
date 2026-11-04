--Cada prueba es un bloque independiente (separado por GO): se puede ejecutar sola, seleccionandola completa
-- 1. Venta correcta: el producto 5 repetido se consolida y se aplica el descuento del metodo de pago
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
GO

-- 2. Cancelacion: repone el stock
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_venta INT;

INSERT INTO @items (id_producto, cantidad) VALUES (5, 2);

SELECT stock AS stock_inicial FROM PRODUCTO WHERE id_producto = 5;
EXEC dbo.sp_RegistrarVenta @domicilio_entrega = 'Belgrano 456, Córdoba', @id_metodo_pago = 1, @items = @items, @id_venta = @id_venta OUTPUT;
SELECT stock AS stock_luego_de_vender FROM PRODUCTO WHERE id_producto = 5;
EXEC dbo.sp_CancelarVenta @id_venta = @id_venta;
SELECT stock AS stock_luego_de_cancelar FROM PRODUCTO WHERE id_producto = 5;
GO

-- 3. Errores en el registro
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
GO

-- 4. Errores en la cancelacion
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
GO
