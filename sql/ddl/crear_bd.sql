CREATE TABLE MARCA
(
  id_marca INT IDENTITY NOT NULL,
  descripci贸n VARCHAR(50) NOT NULL,
  estado INT NOT NULL,
  CONSTRAINT PK_id_marca PRIMARY KEY (id_marca)
);

CREATE TABLE CATEGORIA
(
  descripci贸n VARCHAR(50) NOT NULL,
  id_categoria INT IDENTITY NOT NULL,
  estado INT NOT NULL,
  CONSTRAINT PK_id_categoria PRIMARY KEY (id_categoria)
);


