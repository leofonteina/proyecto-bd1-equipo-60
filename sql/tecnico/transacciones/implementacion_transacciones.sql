-- =======================================================================================
-- 1. TIPO DE TABLA PARA LA VENTA CON VARIOS PRODUCTOS
-- =======================================================================================
IF TYPE_ID(N'dbo.tipo_item_venta') IS NULL
BEGIN
    CREATE TYPE dbo.tipo_item_venta AS TABLE
    (
        id_producto INT NOT NULL,
        cantidad    INT NOT NULL
    );
END
GO


-- =======================================================================================
-- 2. REGISTRAR UNA VENTA (UN PRODUCTO)
-- =======================================================================================
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

        DECLARE @estado_usuario INT;
        DECLARE @estado_producto INT;
        DECLARE @stock_actual INT;
        DECLARE @precio_unitario DECIMAL(10,2);
        DECLARE @total DECIMAL(10,2);
        DECLARE @id_venta_nueva INT;

        -- RT.05: datos de entrada válidos
        IF @domicilio_entrega IS NULL OR LTRIM(RTRIM(@domicilio_entrega)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El domicilio de entrega es obligatorio.';
            RETURN;
        END

        IF @cantidad IS NULL OR @cantidad <= 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La cantidad debe ser mayor a 0.';
            RETURN;
        END

        -- RT.03: el usuario debe existir y estar activo
        SELECT @estado_usuario = estado
        FROM USUARIO
        WHERE id_usuario = @id_usuario;

        IF @estado_usuario IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario no existe.';
            RETURN;
        END

        IF @estado_usuario = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario está dado de baja.';
            RETURN;
        END

        -- RT.05: el método de pago debe existir
        IF NOT EXISTS (SELECT 1 FROM METODO_PAGO WHERE id_metodo_pago = @id_metodo_pago)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El método de pago no existe.';
            RETURN;
        END

        -- Paso A: obtener datos del producto (la fila queda bloqueada hasta el final de la transacción)
        SELECT @stock_actual = stock, @precio_unitario = precio, @estado_producto = estado
        FROM PRODUCTO WITH (UPDLOCK, ROWLOCK)
        WHERE id_producto = @id_producto;

        -- RT.04: el producto debe existir y estar activo
        IF @estado_producto IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El producto no existe.';
            RETURN;
        END

        IF @estado_producto = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El producto está discontinuado.';
            RETURN;
        END

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


-- =======================================================================================
-- 3. CANCELAR UNA VENTA (DEVUELVE EL STOCK)
-- =======================================================================================
CREATE OR ALTER PROCEDURE sp_CancelarVentaTransaccional
    @id_venta INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(50);

        -- Paso A: leer el estado de la venta y bloquear la fila
        SELECT @estado = estado
        FROM VENTA WITH (UPDLOCK, ROWLOCK)
        WHERE id_venta = @id_venta;

        -- La venta no existe
        IF @estado IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta no existe.';
            RETURN;
        END

        -- RT.01: no se puede cancelar dos veces
        IF @estado = 'Cancelado'
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta ya estaba cancelada.';
            RETURN;
        END

        -- Paso B: devolver el stock de todos los productos de la venta (RT.02)
        UPDATE p
        SET p.stock = p.stock + d.cantidad_total
        FROM PRODUCTO p
        INNER JOIN (SELECT id_producto, SUM(cantidad) AS cantidad_total
                    FROM VENTA_DETALLE
                    WHERE id_venta = @id_venta
                    GROUP BY id_producto) d ON d.id_producto = p.id_producto;

        -- Paso C: marcar la venta como cancelada
        UPDATE VENTA
        SET estado = 'Cancelado'
        WHERE id_venta = @id_venta;

        COMMIT TRANSACTION;
        PRINT 'ÉXITO: Venta cancelada y stock devuelto correctamente.';
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


-- =======================================================================================
-- 4. REGISTRAR UNA VENTA CON VARIOS PRODUCTOS
-- =======================================================================================
CREATE OR ALTER PROCEDURE sp_RegistrarVentaMultipleTransaccional
    @id_usuario INT,
    @domicilio_entrega VARCHAR(150),
    @id_metodo_pago INT,
    @items dbo.tipo_item_venta READONLY
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado_usuario INT;
        DECLARE @total DECIMAL(10,2);
        DECLARE @id_venta_nueva INT;
        DECLARE @cantidad_productos INT;

        -- Productos consolidados: si un producto se repite, se suman sus cantidades (RT.06)
        DECLARE @lineas TABLE
        (
            id_producto INT PRIMARY KEY,
            cantidad    INT NOT NULL,
            precio      DECIMAL(10,2) NULL,
            stock       INT NULL,
            estado      INT NULL
        );

        -- RT.06: la venta debe incluir al menos un producto
        IF NOT EXISTS (SELECT 1 FROM @items)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: La venta debe incluir al menos un producto.';
            RETURN;
        END

        -- RT.05: datos de entrada válidos
        IF EXISTS (SELECT 1 FROM @items WHERE cantidad <= 0)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Todas las cantidades deben ser mayores a 0.';
            RETURN;
        END

        IF @domicilio_entrega IS NULL OR LTRIM(RTRIM(@domicilio_entrega)) = ''
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El domicilio de entrega es obligatorio.';
            RETURN;
        END

        -- RT.03: el usuario debe existir y estar activo
        SELECT @estado_usuario = estado
        FROM USUARIO
        WHERE id_usuario = @id_usuario;

        IF @estado_usuario IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario no existe.';
            RETURN;
        END

        IF @estado_usuario = 0
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El usuario está dado de baja.';
            RETURN;
        END

        -- RT.05: el método de pago debe existir
        IF NOT EXISTS (SELECT 1 FROM METODO_PAGO WHERE id_metodo_pago = @id_metodo_pago)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: El método de pago no existe.';
            RETURN;
        END

        -- Paso A: consolidar los productos repetidos
        INSERT INTO @lineas (id_producto, cantidad)
        SELECT id_producto, SUM(cantidad)
        FROM @items
        GROUP BY id_producto;

        SELECT @cantidad_productos = COUNT(*) FROM @lineas;

        -- Paso B: traer precio, stock y estado de cada producto (las filas quedan bloqueadas)
        UPDATE l
        SET l.precio = p.precio,
            l.stock  = p.stock,
            l.estado = p.estado
        FROM @lineas l
        INNER JOIN PRODUCTO p WITH (UPDLOCK, ROWLOCK) ON p.id_producto = l.id_producto;

        -- RT.04: todos los productos deben existir y estar activos
        IF EXISTS (SELECT 1 FROM @lineas WHERE estado IS NULL)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Alguno de los productos no existe.';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM @lineas WHERE estado = 0)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Alguno de los productos está discontinuado.';
            RETURN;
        END

        -- RN.01: stock suficiente para todos los productos
        IF EXISTS (SELECT 1 FROM @lineas WHERE stock < cantidad)
        BEGIN
            ROLLBACK TRANSACTION;
            PRINT 'OPERACIÓN CANCELADA: Stock insuficiente en al menos un producto.';
            RETURN;
        END

        -- Paso C: encabezado de la venta
        SELECT @total = SUM(cantidad * precio) FROM @lineas;

        INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
        VALUES ('Entregado', @domicilio_entrega, @total, GETDATE(), @id_usuario);

        SET @id_venta_nueva = SCOPE_IDENTITY();

        -- Paso D: un detalle por cada producto
        INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        SELECT cantidad, precio, cantidad * precio, id_producto, @id_venta_nueva
        FROM @lineas;

        -- Paso E: pago por el total
        INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
        VALUES (@total, @id_venta_nueva, @id_metodo_pago);

        -- Paso F: descontar el stock de todos los productos (RN.02)
        UPDATE p
        SET p.stock = p.stock - l.cantidad
        FROM PRODUCTO p
        INNER JOIN @lineas l ON l.id_producto = p.id_producto;

        COMMIT TRANSACTION;
        PRINT 'ÉXITO: Venta registrada con ' + CAST(@cantidad_productos AS VARCHAR(10))
            + ' producto(s), pago asentado y stock actualizado correctamente.';
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
