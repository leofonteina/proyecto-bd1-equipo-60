# Pruebas y Validación de Restricciones

El presente documento detalla los casos de prueba (operaciones DML) diseñados para validar que las restricciones de integridad estructurales definidas en la base de datos (Primary Keys, Foreign Keys, Unique, Not Null) funcionan correctamente y hacen cumplir las reglas de negocio estáticas.

## 1. Validación de Unicidad (Regla de Negocio 04)

**Objetivo:** Comprobar que el sistema rechaza el registro de dos usuarios con el mismo DNI o correo electrónico (`UNIQUE`).

* **Caso de Éxito (Camino feliz):**
  ```sql
  INSERT INTO USUARIO (dni, apellido, nombre, email, nro_telefono, estado, id_rol, id_direccion) 
  VALUES ('46512761', 'Acuña', 'Alejo', 'alejo@email.com', '3794123456', 1, 1, 1);
  ```
  *Resultado esperado:* La fila se inserta correctamente.

* **Caso de Falla (Violación de restricción `UQ_dni`):**
  ```sql
  -- Se intenta insertar otro usuario con distinto email pero mismo DNI
  INSERT INTO USUARIO (dni, apellido, nombre, email, nro_telefono, estado, id_rol, id_direccion) 
  VALUES ('46512761', 'Gomez', 'Agustin', 'agustin@email.com', '3794654321', 1, 1, 1);
  ```
  *Resultado esperado:* El motor de base de datos **RECHAZA** la operación lanzando un error de violación de la restricción `UNIQUE (dni)`.

## 2. Validación de Obligatoriedad e Historial de Precios (Regla de Negocio 05)

**Objetivo:** Asegurar que no se pueda registrar un detalle de venta sin especificar el precio unitario exacto vigente al momento de la operación (`NOT NULL`).

* **Caso de Falla (Violación de restricción `NOT NULL`):**
  ```sql
  -- Se intenta registrar un detalle de venta omitiendo el precio unitario
  INSERT INTO VENTA_DETALLE (cantidad, precio_unitario, subtotal, id_producto, id_venta) 
  VALUES (2, NULL, 50000.00, 1, 100);
  ```
  *Resultado esperado:* La transacción es bloqueada por el SGBD indicando que la columna `precio_unitario` no admite valores nulos.

## 3. Validación de Protección de Historial (Regla de Negocio 08)

**Objetivo:** Verificar que un producto que ya ha sido vendido (posee registros en `VENTA_DETALLE`) no pueda ser eliminado físicamente de la base de datos, protegiendo las auditorías.

* **Contexto:** El producto con `id_producto = 5` ya está asociado a la venta `id_venta = 100` a través de la tabla `VENTA_DETALLE`.

* **Caso de Falla (Violación de restricción `FOREIGN KEY`):**
  ```sql
  -- Se intenta eliminar físicamente el producto
  DELETE FROM PRODUCTO WHERE id_producto = 5;
  ```
  *Resultado esperado:* Falla la eliminación. La restricción configurada con `ON DELETE NO ACTION` impide borrar el producto porque dejaría registros "huérfanos" en el detalle de ventas.

## 4. Validación de Integridad Referencial de Categorías (Regla de Negocio 09)

**Objetivo:** Demostrar que no se puede crear un producto asignándole una categoría que no existe en el sistema.

* **Caso de Falla (Violación de restricción `FOREIGN KEY`):**
  ```sql
  -- Se intenta crear un producto con id_categoria = 999 (Inexistente)
  INSERT INTO PRODUCTO (nombre, precio, stock, descripcion, estado, id_marca, id_categoria, id_usuario) 
  VALUES ('Teclado', 45000.00, 15, 'Teclado RGB', 1, 1, 999, 1);
  ```
  *Resultado esperado:* El SGBD aborta la inserción por violación de la restricción FK, ya que el valor `999` no se encuentra en la tabla padre `CATEGORIA`.

## 5. Validación de Métodos de Pago Combinados (Regla de Negocio 06)

**Objetivo:** Comprobar que la estructura N:M permite asignar más de un método de pago a una misma venta, pero impide duplicar el *mismo* método exacto para la misma venta (gracias a la PK compuesta).

* **Caso de Éxito (Múltiples pagos distintos en una venta):**
  ```sql
  -- El cliente paga una parte en Efectivo (id=1) y otra con Tarjeta (id=2)
  INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago) VALUES (10000.00, 10, 1);
  INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago) VALUES (40000.00, 10, 2);
  ```
  *Resultado esperado:* Ambas inserciones son exitosas, validando la RN.06.

* **Caso de Falla (Violación de PK Compuesta):**
  ```sql
  -- Se intenta volver a registrar Efectivo (id=1) para la misma venta (id=10)
  INSERT INTO VENTA_PAGO (monto, id_venta, id_metodo_pago) VALUES (5000.00, 10, 1);
  ```
  *Resultado esperado:* El sistema rechaza la operación por violación de la `PRIMARY KEY (id_venta, id_metodo_pago)`.

## 6. Aclaración sobre Pruebas Transaccionales (RN.01, RN.02, RN.03)

Las reglas de negocio relacionadas con la validación de stock disponible antes de vender (RN.01), el descuento automático de stock (RN.02) y las alertas de stock mínimo (RN.03) requieren lógica dinámica. 
Dado que el motor relacional no puede resolverlas únicamente con restricciones DDL (Data Definition Language), los casos de prueba para estas reglas se documentarán y validarán en la **Etapa 05**, una vez que se hayan implementado los *Triggers* y *Procedimientos Almacenados* correspondientes.
