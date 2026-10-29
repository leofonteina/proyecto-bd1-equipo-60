--Prueba de registro de una venta con distintos metodos de pago
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 1;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 2;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 3;
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 4;

SELECT TOP 4 v.id_venta, v.total, vd.subtotal AS subtotal_bruto, vp.monto
FROM VENTA v
JOIN VENTA_DETALLE vd ON vd.id_venta = v.id_venta
JOIN VENTA_PAGO vp ON vp.id_venta = v.id_venta
ORDER BY v.id_venta DESC;

--Prueba de errores
--Producto inactivo
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 4, 1, 1;
--Producto inexistente
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 99, 1, 1;
--Cantidad invalida
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 0, 1;
--Usuario inactivo
EXEC dbo.sp_RegistrarVenta 6, 'Güemes 303, Salta', 1, 1, 1;
--Metodo de pago inexistente
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 1, 1, 99;
--Stock insuficiente
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 3, 50, 1;

--Prueba de mensaje de stock critico
EXEC dbo.sp_RegistrarVenta 2, 'Belgrano 456, Córdoba', 3, 1, 1;
