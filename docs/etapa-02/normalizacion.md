 Reglas de Normalización Aplicadas al DER
 Primera Forma Normal (1FN)
Regla:Una tabla está en 1FN si todos sus atributos son atómicos (indivisibles) y no
existen grupos repetidos o atributos multivaluados.
Ejemplo en el DER: Se observa en la entidad Usuario el atributo compuesto
(Dirección). Para cumplir con la 1FN al pasar al modelo relacional, este atributo no se
guarda como un bloque de texto único, sino que se descompone en sus atributos
atómicos: calle, altura y codigo_postal. De esta manera, cada columna de la tabla
contendrá un único valor indivisible.
Segunda Forma Normal (2FN)
Regla: Una tabla está en 2FN si ya se encuentra en 1FN y todos los atributos que
no forman parte de la clave principal dependen funcionalmente por completo de dicha
clave. Esto aplica especialmente a tablas con claves primarias compuestas.
Ejemplo en el DER: La entidad Venta_Detalle (que surge de la relación muchos a
muchos entre Venta y Producto). Lógicamente, atributos como cantidad,
precio_unitario y subtotal dependen íntegramente de la combinación de la Venta
específica y el Producto específico. No dependen solo de la Venta (porque una venta
tiene varios productos) ni solo del Producto (porque un producto se vende en muchas
ventas). El DER asigna una clave subrogada id_venta_detalle, lo cual garantiza
estructuralmente la 2FN, pero conceptualmente respeta que los datos del detalle
dependan de la transacción completa.
Tercera Forma Normal (3FN)
Regla: Una tabla está en 3FN si está en 2FN y no existen dependencias
transitivas. Es decir, ningún atributo no clave debe depender de otro atributo no clave;
todos deben depender únicamente de la clave primaria.
Ejemplo en el DER: El modelado de las ubicaciones geográficas y las
características de los productos. En lugar de incluir los nombres de la ciudad y la
provincia directamente como atributos dentro de la entidad Usuario (lo cual generaría
una dependencia transitiva Usuario →; Ciudad →; Provincia), el diagrama las separa
en entidades independientes Ciudad y Provincia. El Usuario se relaciona con la
Ciudad ("Reside"), y la Ciudad con la Provincia ("Pertenece";).
Otro ejemplo claro en el DER es la entidad Producto, que en lugar de almacenar el
nombre de la marca o la categoría como texto, se relaciona con las entidades
independientes Marca y Categoria. Esto evita la redundancia de datos y las
anomalías de actualización.
