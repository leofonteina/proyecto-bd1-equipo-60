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

        IF @estado_stock IN ('Stock Critico (Reponer)', 'Sin Stock')
            PRINT 'Atencion: el producto quedo con estado "' + @estado_stock + '".';
    END
END;
GO
