SELECT 
    u.nombre, 
    u.apellido, 
    p.nomb_prov AS provincia,
    COUNT(v.id_venta) AS cantidad_compras,
    SUM(v.total) AS gasto_total
FROM USUARIO u
INNER JOIN DIRECCION d ON u.id_direccion = d.id_direccion
INNER JOIN CIUDAD c ON d.id_ciudad = c.id_ciudad
INNER JOIN PROVINCIA p ON c.id_provincia = p.id_provincia
INNER JOIN VENTA v ON u.id_usuario = v.id_usuario
-- 1. Filtra a nivel de fila individual antes de agrupar solo ventas con estado "Entregado"
WHERE v.estado = 'Entregado'
GROUP BY 
    u.id_usuario, 
    u.nombre, 
    u.apellido, 
    p.nomb_prov
-- 2. HAVING con Subconsulta: Filtra el grupo completo evaluando una metrica agregada
HAVING SUM(v.total) > (
    -- Subconsulta para obtener el promedio de ventas exitosas
    SELECT AVG(total) 
    FROM VENTA 
    WHERE estado = 'Entregado'
)
ORDER BY gasto_total DESC;
