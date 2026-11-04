CREATE TYPE dbo.tipo_item_venta AS TABLE
(
    id_producto INT NOT NULL,
    cantidad INT NOT NULL
);
GO

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
GO

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
GO
