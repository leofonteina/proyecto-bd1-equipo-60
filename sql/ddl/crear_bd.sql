CREATE TABLE MARCA
(
  id_marca INT IDENTITY NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  estado INT NOT NULL,
  CONSTRAINT PK_id_marca PRIMARY KEY (id_marca)
);

CREATE TABLE CATEGORIA
(
  descripcion VARCHAR(50) NOT NULL,
  id_categoria INT IDENTITY NOT NULL,
  estado INT NOT NULL,
  CONSTRAINT PK_id_categoria PRIMARY KEY (id_categoria)
);

CREATE TABLE ROL
(
  id_rol INT IDENTITY NOT NULL,
  descripcion VARCHAR(50) NOT NULL,
  CONSTRAINT PK_id_rol PRIMARY KEY (id_rol)
);
