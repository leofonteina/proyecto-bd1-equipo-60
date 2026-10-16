SELECT v.id_venta,
       v.fecha_venta,
       v.estado,
       u.apellido + ', ' + u.nombre AS cliente,
       u.dni,
       v.domicilio_entrega,
       p.nombre AS producto,
       vd.cantidad,
       vd.precio_unitario,
       vd.cantidad * vd.precio_unitario AS subtotal_renglon,
       SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY v.id_venta) AS total_acumulado
FROM VENTA v
INNER JOIN USUARIO u        ON u.id_usuario  = v.id_usuario
INNER JOIN VENTA_DETALLE vd ON vd.id_venta   = v.id_venta
INNER JOIN PRODUCTO p       ON p.id_producto = vd.id_producto
WHERE v.id_venta = 1
ORDER BY vd.id_venta_detalle;
