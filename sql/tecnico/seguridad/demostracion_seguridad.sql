SET NOCOUNT ON;

DECLARE @id_usuario1 INT;
DECLARE @id_usuario2 INT;
DECLARE @id_metodo_pago INT;
DECLARE @id_producto INT;
DECLARE @stock_inicial INT;

DECLARE @id_venta1 INT;
DECLARE @id_venta2 INT;

DECLARE @items dbo.tipo_item_venta;


-- DATOS DE PRUEBA
SELECT TOP (1)
    @id_usuario1 = id_usuario
FROM dbo.USUARIO
WHERE estado = 1
ORDER BY id_usuario;


SELECT TOP (1)
    @id_usuario2 = id_usuario
FROM dbo.USUARIO
WHERE estado = 1
  AND id_usuario <> @id_usuario1
ORDER BY id_usuario;


SELECT TOP (1)
    @id_metodo_pago = id_metodo_pago
FROM dbo.METODO_PAGO
ORDER BY id_metodo_pago;


SELECT TOP (1)
    @id_producto = id_producto,
    @stock_inicial = stock
FROM dbo.PRODUCTO
WHERE estado = 1
  AND stock >= 2
ORDER BY id_producto;


IF @id_usuario1 IS NULL
   OR @id_usuario2 IS NULL
   OR @id_metodo_pago IS NULL
   OR @id_producto IS NULL
BEGIN
    THROW 51000,
        'No hay suficientes datos para ejecutar la demostracion.',
        1;
END;


INSERT INTO @items (id_producto, cantidad)
VALUES (@id_producto, 1);


PRINT '=============================================';
PRINT 'DATOS DE PRUEBA SELECCIONADOS';
PRINT '=============================================';

SELECT
    @id_usuario1 AS usuario_1,
    @id_usuario2 AS usuario_2,
    @id_metodo_pago AS metodo_pago,
    @id_producto AS producto,
    @stock_inicial AS stock_inicial;


-- PRUEBA: REGISTRAR SIN IDENTIDAD DE USUARIO
PRINT ' ';
PRINT 'PRUEBA 1: REGISTRO SIN IDENTIDAD DE SESION';

EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = NULL;

SET @id_venta1 = NULL;

BEGIN TRY

    EXEC dbo.sp_RegistrarVenta
        @domicilio_entrega = 'Domicilio de prueba',
        @id_metodo_pago = @id_metodo_pago,
        @items = @items,
        @id_venta = @id_venta1 OUTPUT;

    PRINT 'ERROR: se permitio registrar una venta sin identidad.';

END TRY
BEGIN CATCH

    PRINT 'CORRECTO: la venta fue rechazada.';
    PRINT 'Motivo: ' + ERROR_MESSAGE();

END CATCH;


-- PRUEBA: REGISTRAR VENTA DEL USUARIO 1
PRINT ' ';
PRINT 'PRUEBA 2: REGISTRAR VENTA DEL USUARIO 1';

EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = @id_usuario1;

SET @id_venta1 = NULL;

EXEC dbo.sp_RegistrarVenta
    @domicilio_entrega = 'Domicilio de prueba usuario 1',
    @id_metodo_pago = @id_metodo_pago,
    @items = @items,
    @id_venta = @id_venta1 OUTPUT;


IF @id_venta1 IS NULL
BEGIN
    THROW 51001,
        'No se pudo obtener el ID de la primera venta.',
        1;
END;


PRINT 'CORRECTO: venta registrada.';
SELECT @id_venta1 AS id_venta_usuario_1;


-- PRUEBA: REGISTRAR VENTA DEL USUARIO 2
PRINT ' ';
PRINT 'PRUEBA 3: REGISTRAR VENTA DEL USUARIO 2';

EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = @id_usuario2;

SET @id_venta2 = NULL;

EXEC dbo.sp_RegistrarVenta
    @domicilio_entrega = 'Domicilio de prueba usuario 2',
    @id_metodo_pago = @id_metodo_pago,
    @items = @items,
    @id_venta = @id_venta2 OUTPUT;


IF @id_venta2 IS NULL
BEGIN
    THROW 51002,
        'No se pudo obtener el ID de la segunda venta.',
        1;
END;


PRINT 'CORRECTO: venta registrada.';
SELECT @id_venta2 AS id_venta_usuario_2;


-- PRUEBA: CANCELAR UNA VENTA AJENA

PRINT ' ';
PRINT 'PRUEBA 4: INTENTO DE CANCELAR UNA VENTA AJENA';

-- Simulamos que el usuario 1 esta autenticado
EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = @id_usuario1;

BEGIN TRY

    -- La venta pertenece al usuario 2
    EXEC dbo.sp_CancelarVenta
        @id_venta = @id_venta2;

    PRINT 'ERROR: se permitio cancelar una venta ajena.';

END TRY
BEGIN CATCH

    PRINT 'CORRECTO: no se permitio cancelar la venta ajena.';
    PRINT 'Motivo: ' + ERROR_MESSAGE();

END CATCH;


-- PRUEBA: CANCELAR UNA VENTA PROPIA
PRINT ' ';
PRINT 'PRUEBA 5: CANCELAR UNA VENTA PROPIA';

-- Volvemos a identificar al usuario 1
EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = @id_usuario1;

-- Verificacion antes de cancelar
SELECT
    @id_venta1 AS venta_a_cancelar,
    @id_usuario1 AS usuario_actual;

SELECT
    id_venta,
    id_usuario,
    estado
FROM dbo.VENTA
WHERE id_venta = @id_venta1;


EXEC dbo.sp_CancelarVenta
    @id_venta = @id_venta1;

PRINT 'CORRECTO: la venta propia fue cancelada.';


-- PRUEBA DE SEGURIDAD: ACCESO DIRECTO A TABLA
PRINT ' ';
PRINT 'PRUEBA 6: INTENTO DE ACCESO DIRECTO A VENTA';

BEGIN TRY

    EXECUTE AS USER = 'usuario_demo_cliente';

    INSERT INTO dbo.VENTA
    (
        domicilio_entrega,
        total,
        id_usuario
    )
    VALUES
    (
        'Intento no autorizado',
        100,
        @id_usuario1
    );

    PRINT 'ERROR: se permitio el INSERT directo.';

    REVERT;

END TRY
BEGIN CATCH

    PRINT 'CORRECTO: acceso directo rechazado.';
    PRINT 'Motivo: ' + ERROR_MESSAGE();

    IF USER_NAME() = 'usuario_demo_cliente'
        REVERT;

END CATCH;


-- LIMPIEZA: CANCELAR LA SEGUNDA VENTA
PRINT ' ';
PRINT 'LIMPIEZA: CANCELAR SEGUNDA VENTA';

-- Ahora identificamos correctamente al propietario
EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = @id_usuario2;

EXEC dbo.sp_CancelarVenta
    @id_venta = @id_venta2;

PRINT 'Segunda venta cancelada y stock repuesto.';


-- RESULTADOS FINALES
PRINT ' ';
PRINT 'RESULTADO FINAL';

SELECT
    id_venta,
    id_usuario,
    estado,
    total
FROM dbo.VENTA
WHERE id_venta IN (@id_venta1, @id_venta2);


SELECT
    id_producto,
    nombre,
    stock
FROM dbo.PRODUCTO
WHERE id_producto = @id_producto;



EXEC sys.sp_set_session_context
    @key = N'id_usuario',
    @value = NULL;

PRINT 'DEMOSTRACION FINALIZADA.';
GO
