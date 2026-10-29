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

        SELECT @stock_actual = stock, @precio_unitario = precio
        FROM PRODUCTO 
        WHERE id_producto = @id_producto;

        
        IF @stock_actual < @cantidad
        BEGIN
            
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Stock insuficiente para el producto solicitado.';
            RETURN; 
        END


        SET @total = @cantidad * @precio_unitario;

        INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
        VALUES ('Entregado', @domicilio_entrega, @total, GETDATE(), @id_usuario);

        
        SET @id_venta_nueva = SCOPE_IDENTITY();

       
        INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        VALUES (@cantidad, @precio_unitario, @total, @id_producto, @id_venta_nueva);

    
        INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
        VALUES (@total, @id_venta_nueva, @id_metodo_pago);

    
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
