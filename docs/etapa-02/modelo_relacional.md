--- Modelo Relacional en 'Notación Textual Estandar'

- PROVINCIA (id_provincia, nombre_prov)
  + Clave Primaria (PK): id_provincia

- CIUDAD (id_ciudad, nomb_ciudad, id_provincia)
  + Clave Primaria (PK): id_ciudad
  + Clave Foránea (FK): id_provincia referencias PROVINCIA (id_provincia)

- USUARIO (dni, apellido, nomb_usuario, email, contraseña, calle, altura, codigo_postal, nro_telefono, estado, id_ciudad)
  + Clave Primaria (PK): dni
  + Clave Única (UQ): email
  + Clave Foránea (FK): id_ciudad referencias CIUDAD (id_ciudad)

- ADMINISTRADOR (dni_admin)
  + Clave Primaria (PK): dni_admin
  + Clave Foránea (FK): dni_admin referencias USUARIO (dni)

- CLIENTE (dni_cliente)
  + Clave Primaria (PK): dni_cliente
  + Clave Foránea (FK): dni_cliente referencias USUARIO (dni)
 
- MARCA (id_marca, estado, desc_marca)
  + Clave Primaria (PK): id_marca

- CATEGORIA (id_categoria, estado, desc_categoria)
  + Clave Primaria (PK): id_categoria
 
- PRODUCTO (id_producto, nomb_producto, precio, stock, descripción, estado, dni, id_marca, id_categoria)
  + Clave Primaria (PK): id_producto
  + Claves Foráneas (FK):
	  * dni referencias ADMINISTRADOR (dni)
	  * id_marca referencias MARCA (id_marca)
	  * id_categoria referencias CATEGORIA (id_categoria)

- IMAGEN (id_imagen, ruta_archivo, id_producto)
  + Clave Primaria (PK): id_imagen
  + Clave Foránea (FK): id_producto referencias PRODUCTO (id_producto)

- VENTA_DETALLE (id_venta_detalle, cantidad, precio_unitario, domicilio_entrega, id_producto) 
  + Clave Primaria (PK): id_venta_detalle
  + Clave Foránea (FK): id_producto referencias PRODUCTO (id_producto)

- METODO_PAGO (id_metodo_pago, desc_metodo)
  + Clave Primaria (PK): id_metodo_pago

- VENTA (id_venta, estado, id_venta_detalle, dni_cliente)
  + Clave Primaria (PK): id_venta
  + Claves Foráneas (FK): 
    * id_venta_detalle referencias VENTA_DETALLE (id_venta_detalle)
    * dni_cliente referencias CLIENTE (dni_cliente)

- VENTA_PAGO (id_venta, id_metodo_pago)
  + Clave Primaria Compuesta: id_venta, id_metodo_pago
  + Claves Foráneas (FK):
	  * id_venta referencias VENTA (id_ventas)
	  * id_metodo_pago referencias METODO_PAGO (id_metodo_pago)

