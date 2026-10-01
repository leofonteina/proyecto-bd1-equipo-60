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

INSERT INTO MARCA (descripcion, estado)
VALUES 
('AMD', 1), ('Intel', 1), ('ASUS', 1), ('MSI', 1), ('Gigabyte', 1), 
('Corsair', 1), ('Kingston', 1), ('Logitech', 1), ('Samsung', 1), ('Redragon', 1);

INSERT INTO CATEGORIA (descripcion, estado)
VALUES 
('Procesadores', 1), ('Placas de Video', 1), ('Motherboards', 1), ('Memoria RAM', 1), 
('Almacenamiento SSD', 1), ('Fuentes de Poder', 1), ('Gabinetes', 1), 
('Mouse', 1), ('Teclados', 1), ('Monitores', 1);


INSERT INTO PRODUCTO (nombre, precio, stock, descripción, estado, id_marca, id_categoria, dni)
VALUES 
('Ryzen 5 5600', 220000.0, 15, 'Procesador 6 núcleos', 1, 1, 1, 11111111),       
('Core i5 12400F', 230000.0, 10, 'Procesador 6 núcleos', 1, 2, 1, 11111111),     
('RTX 3060 12GB', 450000.0, 5, 'Placa de video Nvidia', 1, 3, 2, 11111111),     
('B550 Tomahawk', 180000.0, 8, 'Motherboard AM4', 1, 4, 3, 11111111),           
('Vengeance 16GB', 65000.0, 20, 'RAM DDR4 3200MHz', 1, 6, 4, 11111111),         
('SSD 1TB NVMe', 90000.0, 25, 'Disco Solido M.2', 1, 7, 5, 11111111),           
('Fuente 650W 80+', 110000.0, 12, 'Fuente Certificada', 1, 5, 6, 11111111),      
('Mouse G203', 35000.0, 30, 'Mouse Gamer RGB', 1, 8, 8, 11111111),               
('Teclado Kumara', 45000.0, 18, 'Teclado Mecánico', 1, 10, 9, 11111111),        
('Monitor 24 144Hz', 280000.0, 7, 'Monitor Gamer IPS', 1, 9, 10, 11111111);


INSERT INTO IMAGEN (ruta_archivo, id_producto)
VALUES 
('/images/ryzen5.jpg', 1), ('/images/corei5.jpg', 2), ('/images/rtx3060.jpg', 3),
('/images/b550.jpg', 4), ('/images/ram16.jpg', 5), ('/images/ssd1tb.jpg', 6),
('/images/fuente650.jpg', 7), ('/images/g203.jpg', 8), ('/images/kumara.jpg', 9),
('/images/monitor24.jpg', 10);

INSERT INTO METODO_PAGO (descripción)
VALUES 
('Efectivo'), ('Tarjeta de Débito'), 
('Tarjeta de Crédito'), 
('Mercado Pago'), ('MODO'), ('Cheque');


INSERT INTO VENTA (estado, domicilio_entrega, total, fecha_venta, dni)
VALUES 
('Entregado', 'Belgrano 456, Córdoba', 220000, '2026-09-01', 22222222),
('Enviado', 'Sarmiento 789, Rosario', 450000, '2026-09-02', 33333333),
('Pendiente', 'Av. Las Heras 101, Mendoza', 65000, '2026-09-03', 44444444),
('Entregado', '25 de Mayo 202, Tucuman', 90000, '2026-09-04', 55555555),
('Cancelado', 'Güemes 303, Salta', 35000, '2026-09-05', 66666666),
('Enviado', 'Urquiza 404, Paraná', 280000, '2026-09-06', 77777777),
('Entregado', 'Junín 505, Corrientes', 180000, '2026-09-07', 88888888),
('Pendiente', 'Av. Mitre 606, Posadas', 45000, '2026-09-08', 99999999),
('Entregado', 'Illia 707, Resistencia', 110000, '2026-09-09', 10101010),
('Enviado', 'Belgrano 456, Córdoba', 230000, '2026-09-10', 22222222);

INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta)
VALUES 
(1, 220000.0, 220000.0, 1, 1),  
(1, 450000.0, 450000.0, 3, 2), 
(1, 65000.0, 65000.0, 5, 3),    
(1, 90000.0, 90000.0, 6, 4),   
(1, 35000.0, 35000.0, 8, 5),    
(1, 280000.0, 280000.0, 10, 6), 
(1, 180000.0, 180000.0, 4, 7),  
(1, 45000.0, 45000.0, 9, 8),    
(1, 110000.0, 110000.0, 7, 9),  
(1, 230000.0, 230000.0, 2, 10); 
