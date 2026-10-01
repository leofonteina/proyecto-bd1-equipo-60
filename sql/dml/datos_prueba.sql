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

INSERT INTO MARCA (descripcion, estado)
VALUES 
('AMD', 1), ('Intel', 1), ('ASUS', 1), ('MSI', 1), ('Gigabyte', 1), 
('Corsair', 1), ('Kingston', 1), ('Logitech', 1), ('Samsung', 1), ('Redragon', 1);

INSERT INTO CATEGORIA (descripcion, estado)
VALUES 
('Procesadores', 1), ('Placas de Video', 1), ('Motherboards', 1), ('Memoria RAM', 1), 
('Almacenamiento SSD', 1), ('Fuentes de Poder', 1), ('Gabinetes', 1), 
('Mouse', 1), ('Teclados', 1), ('Monitores', 1);
