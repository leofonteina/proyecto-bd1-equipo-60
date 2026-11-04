-- IMPORTANTE: antes de ejecutar, realizar los siguientes pasos en SSMS:
-- 1. Ctrl + M para activar el plan de ejecucion de cada escenario
-- 2. Descartar los resultados para que el tiempo no incluya el dibujo
--      de ~49.000 filas en la grilla:
--      Query > Query Options > Results > Grid >
--      marcar "Discard results after execution"

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- Estado inicial y filas que devuelve la consulta
SELECT i.type_desc AS tipo_de_estructura
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('VENTA_HISTORICA');

SELECT COUNT(*) AS filas_del_periodo
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
GO
  
-- ESCENARIO 1: Sin indice
CHECKPOINT;
DBCC DROPCLEANBUFFERS;   -- Vacia la cache de datos para que sea mas preciso el tiempo de ejecucion
GO

SELECT id_venta, fecha_venta, total
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
GO

-- ESCENARIO 2: Indice agrupado sobre fecha_venta
CREATE CLUSTERED INDEX IX_VentaHistorica_Fecha
ON VENTA_HISTORICA (fecha_venta);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS;
GO

SELECT id_venta, fecha_venta, total
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
GO

-- Eliminacion del indice agrupado para que la tabla vuelva a ser un HEAP
DROP INDEX IX_VentaHistorica_Fecha ON VENTA_HISTORICA;
GO
  
-- ESCENARIO 3: Indice sobre fecha_venta con columnas incluidas
CREATE NONCLUSTERED INDEX IX_VentaHistorica_Fecha_Cobertura
ON VENTA_HISTORICA (fecha_venta)
INCLUDE (id_venta, total);
GO

CHECKPOINT;
DBCC DROPCLEANBUFFERS;
GO

SELECT id_venta, fecha_venta, total
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
GO

-- Conclusiones en docs/etapa-05/indices-optimizacion.md
