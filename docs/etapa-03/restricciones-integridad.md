# Restricciones de Integridad de la Base de Datos

El presente documento detalla las restricciones de integridad implementadas en el modelo físico de la base de datos (DDL), garantizando la consistencia, validez y fiabilidad de los datos, así como el cumplimiento de las reglas de negocio establecidas.

## 1. Integridad de Entidad (Claves Primarias)

Para garantizar que cada registro sea único y no nulo, se implementaron restricciones `PRIMARY KEY` en todas las tablas del sistema. En su mayoría, se optó por claves subrogadas autoincrementales (`IDENTITY`) para optimizar el rendimiento y evitar problemas ante cambios en datos naturales.

**Ejemplos en el esquema:**
* `CONSTRAINT PK_id_producto PRIMARY KEY (id_producto)` en la tabla `PRODUCTO`.
* `CONSTRAINT PK_id_usuario PRIMARY KEY (id_usuario)` en la tabla `USUARIO`.
* Clave primaria compuesta en tablas asociativas: `CONSTRAINT PK_id_venta_id_metodo_pago PRIMARY KEY (id_venta, id_metodo_pago)` en `VENTA_PAGO` para resolver la cardinalidad N:M.

## 2. Integridad Referencial (Claves Foráneas)

Las restricciones `FOREIGN KEY` aseguran que las relaciones entre tablas sean válidas y evitan la existencia de registros "huérfanos". Se definieron comportamientos específicos (`ON DELETE` y `ON UPDATE`) según las necesidades del negocio:

* **Protección de Historial (RN.08):** La restricción `FK_VENTA_DETALLE_id_producto` se configuró con `ON DELETE NO ACTION`. Esto garantiza matemáticamente la **RN.08**, ya que el motor de base de datos impedirá eliminar un producto si este ya se encuentra referenciado en el detalle de una venta.
* **Eliminación en Cascada:** En la tabla `IMAGEN`, la clave foránea `FK_IMAGEN_id_producto` tiene `ON DELETE CASCADE`. Si por algún motivo se elimina un producto (que no tiene ventas), sus imágenes asociadas se eliminán automáticamente.
* **Actualizaciones en Cascada:** Casi todas las FK poseen `ON UPDATE CASCADE` para que, si el ID de un registro padre llegara a cambiar, las tablas hijas se actualicen automáticamente sin romper la relación.

## 3. Integridad de Dominio y Unicidad

Se utilizaron restricciones de columna para asegurar que los datos ingresados tengan el formato y la obligatoriedad correctos.

* **Restricción de No Nulidad (`NOT NULL`):** Aplicada a columnas críticas. Por ejemplo, en la tabla `VENTA_DETALLE`, el campo `precio_unitario DECIMAL(10,2) NOT NULL` asegura estructuralmente el cumplimiento de la **RN.05** (Historial de precios).
* **Restricciones de Unicidad (`UNIQUE` - RN.04):** Para cumplir con la **RN.04** (Registro de Clientes), se aplicaron las restricciones `CONSTRAINT UQ_dni UNIQUE (dni)` y `CONSTRAINT UQ_email UNIQUE (email)` en la tabla `USUARIO`. 

## 4. Mapeo de Reglas de Negocio a Restricciones Estructurales

| Regla de Negocio | Implementación en la Base de Datos | Tipo de Restricción | 
| ----- | ----- | ----- | 
| **RN.04:** No registrar dos clientes con el mismo documento. | `CONSTRAINT UQ_dni UNIQUE (dni)` en tabla `USUARIO`. | Estructural DDL (`UNIQUE`) | 
| **RN.05:** Historial de precios invariable. | Atributo `precio_unitario DECIMAL(10,2) NOT NULL` en `VENTA_DETALLE`. | Estructural DDL (`NOT NULL`) | 
| **RN.06:** Múltiples métodos de pago por venta. | Creación de la tabla asociativa `VENTA_PAGO` con PK compuesta. | Estructural DDL (PK / FK) | 
| **RN.08:** No borrar productos con historial de ventas. | `FK_VENTA_DETALLE_id_producto` con `ON DELETE NO ACTION`. | Referencial (`FOREIGN KEY`) | 
| **RN.09:** Producto con categoría obligatoria. | `id_categoria INT NOT NULL` referenciando a `CATEGORIA`. | Referencial y Dominio | 
| **RN.10:** Venta asociada a usuario responsable. | `id_usuario INT NOT NULL` en la tabla `VENTA`. | Referencial y Dominio | 

## 5. Restricciones a implementar vía Lógica Transaccional (Triggers)

El motor relacional (DDL) no puede resolver reglas de negocio dinámicas por sí solo. Las siguientes reglas se implementarán en la Etapa 05 mediante programación en el SGBD (Triggers):

* **RN.01:** Controlar que la `cantidad` en `VENTA_DETALLE` sea `<=` al `stock` actual en `PRODUCTO`. 
* **RN.02:** Reducir automáticamente el `stock` de `PRODUCTO` tras confirmar una venta. 

## 6. Ajustes DDL Propuestos (Mejoras Estructurales)

Para dar cumplimiento íntegro a las reglas de negocio detectadas en la Etapa 1 que requerían atributos adicionales no presentes en la primera versión del esquema lógico, se recomienda ejecutar las siguientes sentencias `ALTER TABLE`:

```sql
-- Para cumplir con la RN.03 (Alertas de stock mínimo)
-- Se requiere un límite contra el cual el Trigger pueda comparar el stock actual.
ALTER TABLE PRODUCTO 
ADD stock_minimo INT NOT NULL DEFAULT 0;

-- Para cumplir con la RN.07 (Fraccionamiento en cuotas con tarjeta)
-- Se requiere registrar en cuántas cuotas se procesó el pago de esa venta en particular.
ALTER TABLE VENTA_PAGO 
ADD cuotas INT NOT NULL DEFAULT 1;

-- Para complementar la RN.09 (Período de garantía ofrecido por el fabricante)
-- Se necesita guardar los meses de garantía (permite nulos por si un accesorio no tiene).
ALTER TABLE PRODUCTO 
ADD meses_garantia INT NULL;
```
Al aplicar estas modificaciones, la estructura física de la base de datos queda completamente alineada con los requerimientos del dominio del negocio documentados.
