--ESTADO INICIAL
PRINT '--- SITUACION INICIAL ---';

SELECT id_producto, nombre, stock 
FROM PRODUCTO 
WHERE id_producto IN (1, 3);

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
GO


-- CASO 1: Venta correcta (un producto, stock suficiente)
-- Esperado: 'Venta registrada correctamente.' | venta 11 en estado Pendiente | stock del producto 1: 14 -> 12
PRINT '--- CASO 1: VENTA CORRECTA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 2);   -- Ryzen 5 5600

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,    -- Efectivo
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 2: Stock insuficiente
-- Esperado: error 50011 | no cambia nada | stock del producto 3 sigue en 4
PRINT '--- CASO 2: STOCK INSUFICIENTE ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (3, 10);   -- RTX 3060 (stock 4)

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Sarmiento 789, Rosario',
    @id_metodo_pago = 2,    -- Tarjeta de Débito
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 3;
GO

-- CASO 3: Sesión sin usuario identificado
-- Esperado: error 50001
PRINT '--- CASO 3: SESION SIN USUARIO ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = NULL;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 1);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

-- CASO 4: Usuario dado de baja
-- Esperado: error 50006
PRINT '--- CASO 4: USUARIO DADO DE BAJA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 6;   -- Maria Sosa (estado 0)

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 1);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Güemes 303, Salta',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

-- CASO 5: Producto discontinuado
-- Esperado: error 50010
PRINT '--- CASO 5: PRODUCTO DISCONTINUADO ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (8, 1);   -- Mouse G203 (estado 0)

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

-- CASO 6: Cantidad inválida (cero)
-- Esperado: error 50004
PRINT '--- CASO 6: CANTIDAD INVALIDA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 0);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

-- Verificación de los casos 3 a 6: no se modificó nada
-- Esperado: la última venta sigue siendo la 11 | stock P1 = 12 | stock P8 = 27
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 8);
GO



-- CASO 7: Venta con 3 productos
-- Esperado: 'Venta registrada correctamente.' con cantidad_productos = 3 | venta 12 | 3 detalles
--           (subtotales 220000, 130000 y 90000) | un pago igual al total
--           stock: P1 12 -> 11, P5 12 -> 10, P6 23 -> 22
PRINT '--- CASO 7: VENTA CON 3 PRODUCTOS ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (1, 1), (5, 2), (6, 1);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Sarmiento 789, Rosario',
    @id_metodo_pago = 4,    -- Mercado Pago
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
GO

-- CASO 8: Un producto sin stock en la lista (se revierte TODO, también el producto válido)
-- Esperado: error 50011 | la última venta sigue siendo la 12 | stock de P6 sigue en 22
PRINT '--- CASO 8: UN PRODUCTO SIN STOCK EN LA LISTA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (6, 1), (3, 10);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (3, 6);
GO

-- CASO 9: Producto repetido en la lista (se consolida en una sola línea)
-- Esperado: 'Venta registrada correctamente.' con cantidad_productos = 1 | venta 13 (subtotal 270000)
--           1 detalle con cantidad 3 | stock de P6: 22 -> 19
PRINT '--- CASO 9: PRODUCTO REPETIDO ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;

DECLARE @items dbo.tipo_item_venta;
DECLARE @id_nueva INT;
INSERT INTO @items (id_producto, cantidad) VALUES (6, 1), (6, 2);

EXEC dbo.sp_RegistrarVenta 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items,
    @id_venta = @id_nueva OUTPUT;
GO

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 6;
GO


-- CASO 10: Cancelar una venta con varios productos (venta 12 del usuario 3: P1 x1, P5 x2, P6 x1)
-- Esperado: 'Venta cancelada y stock repuesto correctamente.' | venta 12 pasa a Cancelado
--           stock: P1 11 -> 12, P5 10 -> 12, P6 19 -> 20
PRINT '--- CASO 10: CANCELAR VENTA CON VARIOS PRODUCTOS ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;
EXEC dbo.sp_CancelarVenta @id_venta = 12;
GO

SELECT id_venta, estado, id_usuario FROM VENTA WHERE id_venta = 12;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
GO

-- CASO 11: Cancelar una venta ya cancelada
-- Esperado: error 50023 | el stock no cambia (P1=12, P5=12, P6=20)
PRINT '--- CASO 11: CANCELAR VENTA YA CANCELADA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 3;
EXEC dbo.sp_CancelarVenta @id_venta = 12;
GO

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
GO

-- CASO 12: Cancelar una venta de otro usuario (la venta 10 es del usuario 2)
-- Esperado: error 50022 | la venta 10 sigue Pendiente
PRINT '--- CASO 12: CANCELAR VENTA DE OTRO USUARIO ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 4;
EXEC dbo.sp_CancelarVenta @id_venta = 10;
GO

SELECT id_venta, estado, id_usuario FROM VENTA WHERE id_venta = 10;
GO

-- CASO 13: Cancelar una venta que no está pendiente (la venta 1 está Entregado)
-- Esperado: error 50024 | la venta 1 sigue Entregado
PRINT '--- CASO 13: CANCELAR VENTA ENTREGADA ---';
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;
EXEC dbo.sp_CancelarVenta @id_venta = 1;
GO

SELECT id_venta, estado, id_usuario FROM VENTA WHERE id_venta = 1;
GO



-- CASO 14: ROLLBACK y COMMIT manuales
-- Esperado: dentro de la transacción el stock de P2 baja a 4; tras el ROLLBACK vuelve a 7;
--           tras el COMMIT queda en 6 de forma permanente.
PRINT '--- CASO 14: ROLLBACK Y COMMIT MANUALES ---';

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;   -- 7

BEGIN TRANSACTION;
    UPDATE PRODUCTO SET stock = stock - 3 WHERE id_producto = 2;
    SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;   -- 4 (provisorio)
ROLLBACK TRANSACTION;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;   -- 7 (se deshizo)

BEGIN TRANSACTION;
    UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 2;
COMMIT TRANSACTION;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 2;   -- 6 (permanente)
GO

-- CASO 15: Falla real en el último paso de una transacción (Atomicidad)
-- Se repiten a mano los pasos de una venta, pero el pago usa un método inexistente.
-- Esperado: el CATCH muestra el error de clave foránea y hace ROLLBACK:
--           no queda ninguna venta ni detalle de 'PRUEBA ATOMICIDAD' y el stock de P5 sigue en 12.
PRINT '--- CASO 15: FALLA EN EL ULTIMO PASO ---';
BEGIN TRY
    BEGIN TRANSACTION;

        DECLARE @id_venta_prueba INT;

        INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
        VALUES ('Entregado', 'PRUEBA ATOMICIDAD', 65000.00, GETDATE(), 2);

        SET @id_venta_prueba = SCOPE_IDENTITY();

        INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
        VALUES (1, 65000.00, 65000.00, 5, @id_venta_prueba);

        -- Falla: el método de pago 99 no existe
        INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
        VALUES (65000.00, @id_venta_prueba, 99);

        UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 5;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END
    PRINT 'ERROR: Falló un paso de la transacción y se ejecutó ROLLBACK.';
    PRINT 'Detalle del error: ' + ERROR_MESSAGE();
END CATCH
GO

SELECT COUNT(*) AS ventas_de_prueba FROM VENTA WHERE domicilio_entrega = 'PRUEBA ATOMICIDAD';   -- 0
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;                                                -- sigue la 13
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;                                -- sigue el de la venta 13
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 5;                          -- 12
GO


-- CASO 16: Aislamiento con dos sesiones
-- Este caso NO se ejecuta en una sola ventana: abrir DOS pestañas de consulta en SSMS
-- (cada pestaña es una sesión distinta y debe fijar su propio usuario).
-- No ejecutar este bloque completo: seguir los pasos.
-- Venta 10: Pendiente, del usuario 2 (P2 x1 y P5 x2).
/*
PASO 1:
-- ---------- SESIÓN 1 (pestaña 1) ----------
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;
BEGIN TRANSACTION;
EXEC dbo.sp_CancelarVenta @id_venta = 10;                  -- 'Venta cancelada y stock repuesto correctamente.'
SELECT id_venta, estado FROM VENTA WHERE id_venta = 10;    -- Cancelado (dentro de su transacción)
SELECT @@TRANCOUNT AS transacciones_abiertas;              -- 1
-- NO ejecutar COMMIT todavía.

PASO 2:
-- ---------- SESIÓN 2 (pestaña 2) ----------
EXEC sp_set_session_context @key = N'id_usuario', @value = 2;
EXEC dbo.sp_CancelarVenta @id_venta = 10;
-- La ejecución queda en "Ejecutando consulta..." esperando a que la sesión 1 termine.


PASO 3:
-- ---------- SESIÓN 3 (pestaña 3, opcional; ejecutar mientras la sesión 2 espera) ----------
SELECT session_id, blocking_session_id, wait_type, wait_time
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

PASO 4:
-- ---------- SESIÓN 1 (volver a la pestaña 1) ----------
COMMIT TRANSACTION;
-- La sesión 2 se libera y termina con el error 50023: La venta ya se encuentra cancelada.

PASO 5:
OBSERVAR EL RESULTADO EN LA PENSTAÑA 2
       
PASO 6:
-- ---------- VERIFICACIÓN (cualquier pestaña) ----------
SELECT id_venta, estado FROM VENTA WHERE id_venta = 10;                       -- Cancelado
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (2, 5);  -- 7 y 14 (se devolvió una sola vez)
*/
GO


--ESTADO FINAL
PRINT '--- ESTADO FINAL ---';

SELECT id_producto, nombre, stock FROM PRODUCTO ORDER BY id_producto;
-- Esperado: P1=12, P2=7, P3=4, P4=5, P5=14, P6=20, P7=10, P8=27, P9=15, P10=6

SELECT estado, COUNT(*) AS cantidad FROM VENTA GROUP BY estado;
-- Esperado: Cancelado=3, Pendiente=4, Entregado=6
GO
