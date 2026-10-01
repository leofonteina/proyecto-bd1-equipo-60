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
