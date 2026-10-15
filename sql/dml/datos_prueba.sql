INSERT INTO ROL (descripcion) VALUES
  ('Administrador'),
  ('Cliente');

INSERT INTO PROVINCIA (nomb_prov)
VALUES 
('Buenos Aires'), ('Córdoba'), ('Santa Fe'), ('Mendoza'), ('Tucuman'), 
('Salta'), ('Entre Ríos'), ('Corrientes'), ('Misiones'), ('Chaco');

INSERT INTO CIUDAD (nomb_ciudad, cod_postal, id_provincia)
VALUES 
('La Plata', 1900, 1),           
('Cordoba Capital', 5000, 2),    
('Rosario', 2000, 3),            
('Godoy Cruz', 5501, 4),         
('San Miguel', 4000, 5),         
('Cafayate', 4427, 6),           
('Paraná', 3100, 7),             
('Corrientes Capital', 3400, 8), 
('Posadas', 3300, 9),            
('Resistencia', 3500, 10);       

INSERT INTO Direccion (calle, altura, estado, id_ciudad)
VALUES 
('Av. San Martín', 123, 1, 1), ('Belgrano', 456, 1, 2), 
('Sarmiento', 789, 1, 3), ('Av. Las Heras', 101, 1, 4), 
('25 de Mayo', 202, 1, 5), ('Güemes', 303, 1, 6), 
('Urquiza', 404, 1, 7), ('Junín', 505, 1, 8), 
('Av. Mitre', 606, 1, 9), ('Illia', 707, 1, 10);

INSERT INTO USUARIO (dni, apellido, nombre, email, nro_telefono, estado, id_rol, id_direccion)
VALUES 
(11111111, 'Gomez', 'Martin', 'admin@tech.com', '3794111111', 1, 1, 1), 
(22222222, 'Perez', 'Laura', 'laura@mail.com', '3794222222', 1, 2, 2), 
(33333333, 'Lopez', 'Carlos', 'carlos@mail.com', '3794333333', 1, 2, 3),
(44444444, 'Diaz', 'Ana', 'ana@mail.com', '3794444444', 1, 2, 4),
(55555555, 'Ruiz', 'Jorge', 'jorge@mail.com', '3794555555', 1, 2, 5),
(66666666, 'Sosa', 'Maria', 'maria@mail.com', '3794666666', 1, 2, 6),
(77777777, 'Silva', 'Diego', 'diego@mail.com', '3794777777', 1, 2, 7),
(88888888, 'Luna', 'Sofia', 'sofia@mail.com', '3794888888', 1, 2, 8),
(99999999, 'Vega', 'Pablo', 'pablo@mail.com', '3794999999', 1, 2, 9),
(10101010, 'Cruz', 'Lucia', 'lucia@mail.com', '3794000000', 1, 2, 10);

INSERT INTO MARCA (descripcion)
VALUES 
('AMD'), ('Intel'), ('ASUS'), ('MSI'), ('Gigabyte'),
('Corsair'), ('Kingston'), ('Logitech'), ('Samsung'), ('Redragon');

INSERT INTO CATEGORIA (descripcion)
VALUES 
('Procesadores'), ('Placas de Video'), ('Motherboards'), ('Memoria RAM'),
('Almacenamiento SSD'), ('Fuentes de Poder'), ('Gabinetes'),
('Mouse'), ('Teclados'), ('Monitores');


INSERT INTO PRODUCTO (nombre, precio, stock, descripcion, id_marca, id_categoria, id_usuario)
VALUES 
('Ryzen 5 5600', 220000.00, 15, 'Procesador 6 núcleos', 1, 1, 1),
('Core i5 12400F', 230000.00, 10, 'Procesador 6 núcleos', 2, 1, 1),
('RTX 3060 12GB', 450000.00, 5, 'Placa de video Nvidia', 3, 2, 1),
('B550 Tomahawk', 180000.00, 8, 'Motherboard AM4', 4, 3, 1),
('Vengeance 16GB', 65000.00, 20, 'RAM DDR4 3200MHz', 6, 4, 1),
('SSD 1TB NVMe', 90000.00, 25, 'Disco Sólido M.2', 7, 5, 1),
('Fuente 650W 80+', 110000.00, 12, 'Fuente Certificada', 5, 6, 1),
('Mouse G203', 35000.00, 30, 'Mouse Gamer RGB', 8, 8, 1),
('Teclado Kumara', 45000.00, 18, 'Teclado Mecánico', 10, 9, 1),
('Monitor 24 144Hz', 280000.00, 7, 'Monitor Gamer IPS', 9, 10, 1);


INSERT INTO IMAGEN (ruta_archivo, id_producto)
VALUES 
('/images/ryzen5.jpg', 1), ('/images/corei5.jpg', 2), ('/images/rtx3060.jpg', 3),
('/images/b550.jpg', 4), ('/images/ram16.jpg', 5), ('/images/ssd1tb.jpg', 6),
('/images/fuente650.jpg', 7), ('/images/g203.jpg', 8), ('/images/kumara.jpg', 9),
('/images/monitor24.jpg', 10);

INSERT INTO METODO_PAGO (descripcion)
VALUES 
('Efectivo'), ('Tarjeta de Débito'), 
('Tarjeta de Crédito'), 
('Mercado Pago'), ('MODO'), ('Cheque');


INSERT INTO VENTA (domicilio_entrega, total, id_usuario)
VALUES
('Belgrano 456, Córdoba', 530000.00, 2),     
('Sarmiento 789, Rosario', 560000.00, 3),  
('Av. Las Heras 101, Mendoza', 260000.00, 4), 
('25 de Mayo 202, Tucumán', 260000.00, 5), 
('Güemes 303, Salta', 240000.00, 6),    
('Urquiza 404, Paraná', 280000.00, 7),  
('Junín 505, Corrientes', 820000.00, 8), 
('Av. Mitre 606, Posadas', 160000.00, 9),  
('Illia 707, Resistencia', 110000.00, 10), 
('Belgrano 456, Córdoba', 360000.00, 2);  

INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
VALUES
(1, 220000.00, 1 * 220000.00, 1, 1),
(1, 180000.00, 1 * 180000.00, 4, 1),
(2,  65000.00, 2 *  65000.00, 5, 1),
(1, 450000.00, 1 * 450000.00, 3, 2),
(1, 110000.00, 1 * 110000.00, 7, 2),
(4,  65000.00, 4 *  65000.00, 5, 3),
(2,  90000.00, 2 *  90000.00, 6, 4),
(1,  35000.00, 1 *  35000.00, 8, 4),
(1,  45000.00, 1 *  45000.00, 9, 4),
(3,  35000.00, 3 *  35000.00, 8, 5),
(3,  45000.00, 3 *  45000.00, 9, 5),
(1, 280000.00, 1 * 280000.00, 10, 6),
(2, 180000.00, 2 * 180000.00, 4, 7),
(2, 230000.00, 2 * 230000.00, 2, 7),
(2,  45000.00, 2 *  45000.00, 9, 8),
(2,  35000.00, 2 *  35000.00, 8, 8),
(1, 110000.00, 1 * 110000.00, 7, 9),
(1, 230000.00, 1 * 230000.00, 2, 10),
(2,  65000.00, 2 *  65000.00, 5, 10);

INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago)
VALUES 
(130000.00, 1, 1),
(400000.00, 1, 2),
(560000.00, 2, 4),
(260000.00, 3, 3),
(260000.00, 4, 2), 
(240000.00, 5, 6), 
(280000.00, 6, 1),
(500000.00, 7, 3), 
(320000.00, 7, 5), 
(160000.00, 8, 2), 
(110000.00, 9, 5), 
(100000.00, 10, 1), 
(260000.00, 10, 4);

-- Descontar stock
UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 1;
UPDATE PRODUCTO SET stock = stock - 3 WHERE id_producto = 2; 
UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 3;
UPDATE PRODUCTO SET stock = stock - 3 WHERE id_producto = 4;
UPDATE PRODUCTO SET stock = stock - 8 WHERE id_producto = 5;
UPDATE PRODUCTO SET stock = stock - 2 WHERE id_producto = 6;
UPDATE PRODUCTO SET stock = stock - 2 WHERE id_producto = 7;
UPDATE PRODUCTO SET stock = stock - 6 WHERE id_producto = 8;
UPDATE PRODUCTO SET stock = stock - 6 WHERE id_producto = 9; 
UPDATE PRODUCTO SET stock = stock - 1 WHERE id_producto = 10;

-- Actualizar estado a ventas
UPDATE VENTA SET estado = 'Entregado' WHERE id_venta IN (1, 2, 4, 6, 7, 9);
UPDATE VENTA SET estado = 'Cancelado' WHERE id_venta = 5;

-- Devolver stock
UPDATE PRODUCTO SET stock = stock + 3 WHERE id_producto = 8;
UPDATE PRODUCTO SET stock = stock + 3 WHERE id_producto = 9;

-- Dar de baja a clientes
UPDATE USUARIO SET estado = 0 WHERE id_usuario IN (6, 9);

-- Discontinuar productos
UPDATE PRODUCTO SET estado = 0 WHERE id_producto IN (4, 8);
