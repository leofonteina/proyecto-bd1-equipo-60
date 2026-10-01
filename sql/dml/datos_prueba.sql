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
