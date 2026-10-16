SELECT c.descripcion AS Categoria, COUNT(DISTINCT v.id_venta) AS Ventas, SUM(vd.cantidad) AS Unidades, SUM(vd.subtotal) AS Total
FROM Venta v
JOIN venta_detalle vd ON vd.id_venta = v.id_venta 
JOIN producto p ON vd.id_producto = p.id_producto
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE v.fecha_venta BETWEEN '2026-09-10' and '2026-10-12' AND v.estado <> 'Cancelado'
GROUP BY c.descripcion;
