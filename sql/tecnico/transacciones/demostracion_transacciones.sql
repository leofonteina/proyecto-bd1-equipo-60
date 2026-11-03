-- =======================================================================================
-- 0. SITUACIÓN INICIAL
-- =======================================================================================
PRINT '--- SITUACION INICIAL ---';

SELECT id_producto, nombre, stock 
FROM PRODUCTO 
WHERE id_producto IN (1, 3);

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
GO


-- =======================================================================================
-- PARTE A: REGISTRAR UNA VENTA (sp_RegistrarVentaTransaccional)
-- =======================================================================================

-- CASO 1: Venta correcta (stock suficiente)
-- Esperado: ÉXITO | venta 11 por 440000.00 | stock del producto 1: 14 -> 12
PRINT '--- CASO 1: VENTA CORRECTA ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba', 
    @id_producto = 1,       -- Ryzen 5 5600
    @cantidad = 2, 
    @id_metodo_pago = 1;    -- Efectivo

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 2: Stock insuficiente
-- Esperado: OPERACIÓN CANCELADA | no cambia nada | stock del producto 3 sigue en 4
PRINT '--- CASO 2: STOCK INSUFICIENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 3, 
    @domicilio_entrega = 'Sarmiento 789, Rosario', 
    @id_producto = 3,       -- RTX 3060 (stock 4)
    @cantidad = 10, 
    @id_metodo_pago = 2;    -- Tarjeta de Débito

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 3;
GO

-- CASO 3: Cantidad igual al stock (caso límite)
-- Esperado: ÉXITO | venta 12 por 1680000.00 | stock del producto 10: 6 -> 0
PRINT '--- CASO 3: CANTIDAD IGUAL AL STOCK ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 4, 
    @domicilio_entrega = 'Av. Las Heras 101, Mendoza',
    @id_producto = 10,      -- Monitor 24 144Hz (stock 6)
    @cantidad = 6, 
    @id_metodo_pago = 3;    -- Tarjeta de Crédito

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 10;
GO

-- CASO 4: Producto sin stock
-- Esperado: OPERACIÓN CANCELADA (stock insuficiente) | la última venta sigue siendo la 12
PRINT '--- CASO 4: PRODUCTO SIN STOCK ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 4, 
    @domicilio_entrega = 'Av. Las Heras 101, Mendoza',
    @id_producto = 10,      -- stock 0 tras el caso 3
    @cantidad = 1, 
    @id_metodo_pago = 3;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 10;
GO

-- CASO 5: Usuario inexistente
-- Esperado: OPERACIÓN CANCELADA: El usuario no existe.
PRINT '--- CASO 5: USUARIO INEXISTENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 999,      -- no existe
    @domicilio_entrega = 'Calle Falsa 123',
    @id_producto = 1, 
    @cantidad = 1, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 6: Usuario dado de baja
-- Esperado: OPERACIÓN CANCELADA: El usuario está dado de baja.
PRINT '--- CASO 6: USUARIO DADO DE BAJA ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 6,        -- Maria Sosa (estado 0)
    @domicilio_entrega = 'Güemes 303, Salta',
    @id_producto = 1, 
    @cantidad = 1, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 7: Producto inexistente
-- Esperado: OPERACIÓN CANCELADA: El producto no existe.
PRINT '--- CASO 7: PRODUCTO INEXISTENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_producto = 999,     -- no existe
    @cantidad = 1, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
GO

-- CASO 8: Producto discontinuado
-- Esperado: OPERACIÓN CANCELADA: El producto está discontinuado. | stock del producto 8 sigue en 27
PRINT '--- CASO 8: PRODUCTO DISCONTINUADO ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_producto = 8,       -- Mouse G203 (estado 0)
    @cantidad = 1, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock, estado FROM PRODUCTO WHERE id_producto = 8;
GO

-- CASO 9: Método de pago inexistente
-- Esperado: OPERACIÓN CANCELADA: El método de pago no existe.
PRINT '--- CASO 9: METODO DE PAGO INEXISTENTE ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_producto = 1, 
    @cantidad = 1, 
    @id_metodo_pago = 99;   -- no existe

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 10: Cantidad inválida (0 y negativa)
-- Esperado (las dos llamadas): OPERACIÓN CANCELADA: La cantidad debe ser mayor a 0.
PRINT '--- CASO 10: CANTIDAD INVALIDA ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_producto = 1, @cantidad = 0, @id_metodo_pago = 1;

EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_producto = 1, @cantidad = -3, @id_metodo_pago = 1;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 11: Domicilio de entrega vacío
-- Esperado: OPERACIÓN CANCELADA: El domicilio de entrega es obligatorio.
PRINT '--- CASO 11: DOMICILIO VACIO ---';
EXEC sp_RegistrarVentaTransaccional 
    @id_usuario = 2, 
    @domicilio_entrega = '   ',
    @id_producto = 1, 
    @cantidad = 1, 
    @id_metodo_pago = 1;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
GO


-- =======================================================================================
-- PARTE B: CANCELAR UNA VENTA (sp_CancelarVentaTransaccional)
-- =======================================================================================

-- CASO 12: Cancelar una venta pendiente (venta 3: 4 unidades del producto 5)
-- Esperado: ÉXITO | venta 3 pasa a Cancelado | stock del producto 5: 12 -> 16
PRINT '--- CASO 12: CANCELAR VENTA PENDIENTE ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 3;

SELECT id_venta, estado, total FROM VENTA WHERE id_venta = 3;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 5;
GO

-- CASO 13: Cancelar una venta ya cancelada
-- Esperado: OPERACIÓN CANCELADA: La venta ya estaba cancelada. | stock del producto 5 sigue en 16
PRINT '--- CASO 13: CANCELAR VENTA YA CANCELADA ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 3;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 5;
GO

-- CASO 14: Cancelar una venta inexistente
-- Esperado: OPERACIÓN CANCELADA: La venta no existe.
PRINT '--- CASO 14: CANCELAR VENTA INEXISTENTE ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 999;
GO

-- CASO 15: Cancelar una venta con varios productos (venta 1: P1 x1, P4 x1, P5 x2)
-- Esperado: ÉXITO | venta 1 pasa a Cancelado | stock: P1 12 -> 13, P4 5 -> 6, P5 16 -> 18
PRINT '--- CASO 15: CANCELAR VENTA CON VARIOS PRODUCTOS ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 1;

SELECT id_venta, estado FROM VENTA WHERE id_venta = 1;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 4, 5);
GO

-- CASO 16: Ciclo completo: cancelar la venta 11 creada en el caso 1 (2 unidades del producto 1)
-- Esperado: ÉXITO | venta 11 pasa a Cancelado | stock del producto 1: 13 -> 15
PRINT '--- CASO 16: CICLO VENDER Y CANCELAR ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 11;

SELECT id_venta, estado FROM VENTA WHERE id_venta = 11;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 1;
GO

-- CASO 17: Cancelar la venta 5, que ya figuraba como cancelada en los datos de prueba
-- Esperado: OPERACIÓN CANCELADA: La venta ya estaba cancelada. | stock de P8 y P9 siguen en 27 y 15
PRINT '--- CASO 17: VENTA YA CANCELADA EN LOS DATOS DE PRUEBA ---';
EXEC sp_CancelarVentaTransaccional @id_venta = 5;

SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (8, 9);
GO


-- =======================================================================================
-- PARTE C: VENTA CON VARIOS PRODUCTOS (sp_RegistrarVentaMultipleTransaccional)
-- =======================================================================================

-- CASO 18: Venta con 3 productos
-- Esperado: ÉXITO | venta 13 por 440000.00 con 3 detalles | pago de 440000.00 (Mercado Pago)
--           stock: P1 15 -> 14, P5 18 -> 16, P6 23 -> 22
PRINT '--- CASO 18: VENTA CON 3 PRODUCTOS ---';
DECLARE @items_caso18 dbo.tipo_item_venta;
INSERT INTO @items_caso18 (id_producto, cantidad) VALUES (1, 1), (5, 2), (6, 1);

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 3,
    @domicilio_entrega = 'Sarmiento 789, Rosario',
    @id_metodo_pago = 4,    -- Mercado Pago
    @items = @items_caso18;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT TOP 1 * FROM VENTA_PAGO ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (1, 5, 6);
GO

-- CASO 19: Venta con un producto sin stock (se revierte TODO, también el producto válido)
-- Esperado: OPERACIÓN CANCELADA: Stock insuficiente en al menos un producto.
--           la última venta sigue siendo la 13 | stock de P6 sigue en 22
PRINT '--- CASO 19: UN PRODUCTO SIN STOCK EN LA LISTA ---';
DECLARE @items_caso19 dbo.tipo_item_venta;
INSERT INTO @items_caso19 (id_producto, cantidad) VALUES (6, 1), (3, 10);

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 2,
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items_caso19;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (3, 6);
GO

-- CASO 20: Venta con un producto discontinuado en la lista
-- Esperado: OPERACIÓN CANCELADA: Alguno de los productos está discontinuado. | no cambia nada
PRINT '--- CASO 20: PRODUCTO DISCONTINUADO EN LA LISTA ---';
DECLARE @items_caso20 dbo.tipo_item_venta;
INSERT INTO @items_caso20 (id_producto, cantidad) VALUES (6, 1), (4, 1);

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 2,
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items_caso20;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (4, 6);
GO

-- CASO 21: Producto repetido en la lista (se consolida en una sola línea)
-- Esperado: ÉXITO con 1 producto | venta 14 por 270000.00 | 1 detalle: cantidad 3
--           stock de P6: 22 -> 19
PRINT '--- CASO 21: PRODUCTO REPETIDO ---';
DECLARE @items_caso21 dbo.tipo_item_venta;
INSERT INTO @items_caso21 (id_producto, cantidad) VALUES (6, 1), (6, 2);

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 2,
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items_caso21;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
SELECT * FROM VENTA_DETALLE WHERE id_venta = (SELECT MAX(id_venta) FROM VENTA);
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 6;
GO

-- CASO 22: Lista de productos vacía
-- Esperado: OPERACIÓN CANCELADA: La venta debe incluir al menos un producto.
PRINT '--- CASO 22: LISTA VACIA ---';
DECLARE @items_caso22 dbo.tipo_item_venta;

EXEC sp_RegistrarVentaMultipleTransaccional 
    @id_usuario = 2,
    @domicilio_entrega = 'Belgrano 456, Córdoba',
    @id_metodo_pago = 1,
    @items = @items_caso22;

SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;
GO


-- =======================================================================================
-- PARTE D: DEMOSTRACIÓN DE LAS PROPIEDADES ACID
-- =======================================================================================

-- CASO 23: ROLLBACK y COMMIT manuales
-- Esperado: dentro de la transacción el stock de P2 baja a 4; tras el ROLLBACK vuelve a 7;
--           tras el COMMIT queda en 6 de forma permanente.
PRINT '--- CASO 23: ROLLBACK Y COMMIT MANUALES ---';

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

-- CASO 24: Falla real en el último paso de la transacción (Atomicidad)
-- Se repiten a mano los pasos de una venta, pero el pago usa un método inexistente.
-- Esperado: el CATCH muestra el error de clave foránea y hace ROLLBACK:
--           no queda ninguna venta ni detalle de 'PRUEBA ATOMICIDAD' y el stock de P5 sigue en 16.
PRINT '--- CASO 24: FALLA EN EL ULTIMO PASO ---';
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
SELECT TOP 1 * FROM VENTA ORDER BY id_venta DESC;                                                -- sigue la 14
SELECT TOP 1 * FROM VENTA_DETALLE ORDER BY id_venta_detalle DESC;                                -- sigue el de la venta 14
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto = 5;                          -- 16
GO


-- CASO 25: Aislamiento (Isolation) con dos sesiones
-- Este caso NO se ejecuta en una sola ventana: abrir DOS pestañas de consulta en SSMS
-- (cada pestaña es una sesión distinta). No ejecutar este bloque completo: seguir los pasos.
/*
-- ---------- SESIÓN 1 (pestaña 1) ----------
BEGIN TRANSACTION;
EXEC sp_CancelarVentaTransaccional @id_venta = 8;    -- ÉXITO (venta 8: P9 x2 y P8 x2)
SELECT id_venta, estado FROM VENTA WHERE id_venta = 8;   -- Cancelado (dentro de su transacción)
SELECT @@TRANCOUNT AS transacciones_abiertas;            -- 1
-- NO ejecutar COMMIT todavía.

-- ---------- SESIÓN 2 (pestaña 2) ----------
EXEC sp_CancelarVentaTransaccional @id_venta = 8;
-- La ejecución queda en "Ejecutando consulta..." esperando a que la sesión 1 termine.

-- ---------- SESIÓN 3 (pestaña 3, opcional) ----------
SELECT session_id, blocking_session_id, wait_type, wait_time
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

-- ---------- SESIÓN 1 (volver a la pestaña 1) ----------
COMMIT TRANSACTION;
-- La sesión 2 se libera y muestra: OPERACIÓN CANCELADA: La venta ya estaba cancelada.

-- ---------- VERIFICACIÓN (cualquier pestaña) ----------
SELECT id_venta, estado FROM VENTA WHERE id_venta = 8;                 -- Cancelado
SELECT id_producto, nombre, stock FROM PRODUCTO WHERE id_producto IN (8, 9);   -- 29 y 17 (se devolvió una sola vez)
*/
GO


-- =======================================================================================
-- RESUMEN DEL ESTADO FINAL (después de ejecutar los 25 casos)
-- =======================================================================================
PRINT '--- ESTADO FINAL ---';

SELECT id_producto, nombre, stock FROM PRODUCTO ORDER BY id_producto;
-- Esperado: P1=14, P2=6, P3=4, P4=6, P5=16, P6=19, P7=10, P8=29, P9=17, P10=0

SELECT estado, COUNT(*) AS cantidad FROM VENTA GROUP BY estado;
-- Esperado: Cancelado=5, Entregado=8, Pendiente=1
GO
