# Implementación Física

## Introducción a SQL Server
Para la implementación física de este proyecto, seleccionamos **Microsoft SQL Server**. Es un sistema de gestión de bases de datos relacionales (RDBMS) de nivel empresarial, altamente reconocido por su robustez y excelente manejo del procesamiento de transacciones. Utiliza el lenguaje T-SQL (Transact-SQL) y resulta ideal para sistemas de e-commerce y facturación, ya que garantiza de forma estricta que los datos financieros y de inventario se mantengan consistentes, precisos y protegidos a nivel estructural.

## 1. Construcción del Script DDL (Data Definition Language)
Para diseñar y programar la estructura física de la base de datos, seguimos una metodología basada en las buenas prácticas del modelo relacional, aplicando múltiples capas de seguridad a los datos:

*   **Orden jerárquico de creación:** Estructuramos el script creando primero las "tablas fuertes" o de catálogo (como `PROVINCIA`, `ROL`, `MARCA`, `CATEGORIA` y `METODO_PAGO`) que no dependen de otras. Luego, avanzamos gradualmente hacia las tablas transaccionales y entidades débiles (como `VENTA`, `VENTA_DETALLE` o `VENTA_PAGO`), garantizando que al definir una Clave Foránea, la tabla de referencia ya exista previamente en el motor.
*   **Diseño de Claves y Tipos de Datos:** 
    *   Implementamos **claves artificiales autonuméricas** (`IDENTITY`) en todas las tablas principales. Esto incluye un `id_usuario` interno, lo cual fortalece la privacidad y permite definir al `dni` como un `VARCHAR` para admitir documentos con formatos internacionales.
    *   Para los atributos financieros (`precio`, `total`, `precio_unitario`, `subtotal`, `monto`), implementamos estrictamente el tipo de dato `DECIMAL(10,2)` para garantizar precisión contable exacta y evitar errores aritméticos.
*   **Integridad de Dominio (Restricciones CHECK y DEFAULT):** Blindamos las columnas para que el motor rechace datos ilógicos antes de que se guarden.
    *   Aplicamos restricciones `CHECK` para garantizar que los valores financieros sean siempre mayores a cero, que el `stock` nunca sea negativo, y que los estados se limiten a valores permitidos (ej: `0` o `1` para el borrado lógico, y `'Pendiente'`, `'Cancelado'`, `'Entregado'` para el seguimiento de ventas).
    *   Configuramos cláusulas `DEFAULT` para agilizar la inserción, asumiendo el estado `1` (Activo) al registrar nuevas entidades, el estado `'Pendiente'` al iniciar una venta, y capturando la fecha actual del servidor (`GETDATE()`) automáticamente en las transacciones.
*   **Integridad Referencial y Restricciones Únicas:** 
    *   Aplicamos la restricción `UNIQUE` para campos que jamás deben duplicarse en el sistema (el DNI y el correo electrónico del usuario).
    *   Dado que el negocio gestiona su historial mediante "Borrado Lógico", aplicamos la regla física `ON DELETE NO ACTION` en la inmensa mayoría de las relaciones para bloquear borrados accidentales desde el motor.
    *   Limitamos el uso de `ON DELETE CASCADE` de forma exclusiva a entidades cuya existencia depende 100% de la tabla principal (como las imágenes de un producto, las líneas de detalle de una orden o los registros de cobro). Finalmente, configuramos `ON UPDATE CASCADE` de forma global para que cualquier actualización de IDs se propague sin romper el esquema.

## 2. Construcción del Script DML (Data Manipulation Language)
Para el poblado inicial de la base de datos, preparamos un lote de pruebas con 10 registros por tabla siguiendo estos criterios:

*   **Respeto por la secuencia de inserción:** Al igual que en el DDL, las sentencias `INSERT INTO` se ejecutaron respetando la jerarquía estructural para no violar las restricciones de las claves foráneas (ej: instanciando primero las provincias para luego poder cargar las ciudades, o creando primero los productos para luego poder incluirlos en el carrito de compras).
*   **Coherencia y realismo de los datos:** Nos aseguramos de que el conjunto de pruebas tenga sentido analítico para un local de hardware. Los productos están vinculados a marcas y categorías correspondientes, las direcciones tienen coherencia geográfica, y los montos en las tablas de ventas reflejan cálculos matemáticos exactos en base a las cantidades adquiridas.
*   **Delegación de procesos al motor:** Durante la carga de datos, omitimos deliberadamente definir valores en las columnas configuradas con la propiedad `IDENTITY`, delegando en SQL Server la responsabilidad de auto-incrementar dichos identificadores. Asimismo, nos apoyamos en los valores `DEFAULT` para reducir el volumen de código necesario en las inserciones (como la fecha de venta). La única excepción a la regla de autogeneración fue la tabla intermedia `VENTA_PAGO`, donde se insertaron manualmente los IDs foráneos al tratarse de una clave primaria compuesta.
