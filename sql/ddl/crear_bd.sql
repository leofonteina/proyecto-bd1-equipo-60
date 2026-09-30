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

CREATE TABLE PROVINCIA
(
  id_provincia INT IDENTITY NOT NULL,
  nomb_prov VARCHAR(50) NOT NULL,
  CONSTRAINT PK_id_provincia PRIMARY KEY (id_provincia)
);

CREATE TABLE CIUDAD
(
  id_ciudad INT IDENTITY NOT NULL,
  nomb_ciudad VARCHAR(50) NOT NULL,
  cod_postal INT NOT NULL,
  id_provincia INT NOT NULL,
  CONSTRAINT PK_id_ciudad PRIMARY KEY (id_ciudad),
  CONSTRAINT FK_CIUDAD_id_provincia FOREIGN KEY (id_provincia) REFERENCES PROVINCIA(id_provincia) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Direccion
(
  id_direccion INT IDENTITY NOT NULL,
  calle VARCHAR(50) NOT NULL,
  altura INT NOT NULL,
  estado INT NOT NULL,
  id_ciudad INT NOT NULL,
  CONSTRAINT PK_id_direccion PRIMARY KEY (id_direccion),
  CONSTRAINT FK_Direccion_id_ciudad FOREIGN KEY (id_ciudad) REFERENCES CIUDAD(id_ciudad) ON DELETE NO ACTION ON UPDATE CASCADE
);
