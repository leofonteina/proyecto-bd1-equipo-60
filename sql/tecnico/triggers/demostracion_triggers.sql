-- =====================================================================
-- Etapa V - Triggers de auditoría
-- Script de demostración (casos de prueba)
--
-- Requisito: haber ejecutado antes implementacion_triggers.sql
--
-- Las pruebas se hacen sobre ventas de prueba creadas por este script
-- (domicilio 'PRUEBA AUDITORIA ...') para no alterar las ventas 1 a 10,
-- de las que dependen las consultas de la Etapa IV.
--
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.0 PREPARACIÓN
-- ---------------------------------------------------------------------

-- Verificación de los triggers creados
SELECT t.name                    AS trigger_nombre,
       OBJECT_NAME(t.parent_id)  AS tabla,
       CASE WHEN t.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS tipo,
       t.is_disabled             AS deshabilitado
FROM sys.triggers t
WHERE t.name IN ('t_update_venta', 't_delete_venta', 't_bloquear_delete_producto');
GO

-- Ventas de prueba (los INSERT no disparan los triggers de auditoría)
INSERT INTO VENTA (domicilio_entrega, total, id_usuario)
VALUES ('PRUEBA AUDITORIA 1', 1000.00, 2),
       ('PRUEBA AUDITORIA 2', 2000.00, 3),
       ('PRUEBA AUDITORIA 3', 3000.00, 4);
GO

SELECT id_venta, estado, domicilio_entrega, total
FROM VENTA
WHERE domicilio_entrega LIKE 'PRUEBA AUDITORIA%';

SELECT COUNT(*) AS filas_auditoria FROM AUDITORIA_VENTA;
GO

-- ---------------------------------------------------------------------
-- CASO 1: UPDATE de una columna (cambio de estado)
-- ---------------------------------------------------------------------
UPDATE VENTA
SET estado = 'Entregado'
WHERE domicilio_entrega = 'PRUEBA AUDITORIA 1';

SELECT TOP (1) id_auditoria, accion, id_venta,
       estado_anterior, estado_nuevo, total_anterior, total_nuevo,
       domicilio_anterior, domicilio_nuevo, fecha_modificacion, usuario_bd
FROM AUDITORIA_VENTA
ORDER BY id_auditoria DESC;
GO

-- ---------------------------------------------------------------------
-- CASO 2: DELETE de una venta
-- ---------------------------------------------------------------------
DELETE FROM VENTA
WHERE domicilio_entrega = 'PRUEBA AUDITORIA 3';

SELECT TOP (1) id_auditoria, accion, id_venta,
       estado_anterior, estado_nuevo, total_anterior, total_nuevo,
       domicilio_anterior, domicilio_nuevo, fecha_modificacion, usuario_bd
FROM AUDITORIA_VENTA
ORDER BY id_auditoria DESC;
GO

-- ---------------------------------------------------------------------
-- CASO 3: Intento de DELETE sobre PRODUCTO (bloqueado)
--         Ver el mensaje en la pestaña "Mensajes"
-- ---------------------------------------------------------------------
DELETE FROM PRODUCTO WHERE id_producto = 8;
GO

-- Verificación: no se borró nada y el intento quedó registrado
SELECT COUNT(*) AS cantidad_productos FROM PRODUCTO;

SELECT id_intento, tabla, accion, id_registro, fecha, usuario_bd
FROM AUDITORIA_INTENTOS_BORRADO;
GO

-- ---------------------------------------------------------------------
-- Elimina las ventas de prueba que quedaron en VENTA (11 y 12). Es
-- necesario para que no se alteren los resultados de la consulta 
-- avanzada de la Etapa IV.
-- Los DELETE también quedan registrados en AUDITORIA_VENTA.
-- ---------------------------------------------------------------------
DELETE FROM VENTA
WHERE domicilio_entrega LIKE 'PRUEBA AUDITORIA%';
GO

-- Control: deben quedar las 10 ventas originales
SELECT COUNT(*) AS cantidad_ventas FROM VENTA;
GO
