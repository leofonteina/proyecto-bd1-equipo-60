## Justificación de Decisiones de Diseño del DER

### 1. Generalización de Entidades (Jerarquía de Usuarios)

**Decisión:** Decidimos implementar una generalización disjunta ("d") desde la entidad fuerte `Usuario` hacia los subtipos `Cliente` y `Administrador`.

**Justificación:** Con esta estructura optimizamos el modelo al centralizar todos los datos comunes de las personas que interactúan con nuestro sistema. Atributos como `dni`, `nombre`, `apellido`, `email`, `contraseña`, `nro_telefono` y la dirección compuesta (`calle`, `altura`, `codigo_postal`) los almacenamos una sola vez en la superclase `Usuario`. De esta manera, evitamos la redundancia de datos, simplificamos el proceso de autenticación centralizada y facilitamos el mantenimiento de la base de datos a futuro.

---

### 2. Resolución de la Relación Venta - Producto (Entidad Débil)

**Decisión:** Tomamos la decisión de modelar `Venta_Detalle` como una entidad débil dependiente existencialmente de `Venta` mediante la relación `Posee`.

**Justificación:** Hicimos esto porque representa con exactitud la dependencia lógica de nuestro negocio: un detalle de compra no puede existir en la base de datos sin un comprobante de venta que lo respalde. Además, resolvimos la relación de muchos a muchos con `Producto` alojando atributos de intersección vitales como la `cantidad` y el `precio_unitario`. Al registrar el `precio_unitario` directamente en el detalle, garantizamos la inmutabilidad histórica, si el atributo `precio` de la entidad `Producto` se actualiza más adelante, los importes de las ventas que ya registramos no sufrirán alteraciones. También decidimos incorporar estratégicamente el `domicilio_entrega` de forma directa en el detalle.

---

### 3. Implementación de Baja Lógica (Atributo "estado")

**Decisión:** Decidimos incorporar de forma sistemática el atributo `estado` en las entidades principales de nuestro modelo.

**Justificación:** Como evidenciamos en el diagrama, agregamos el atributo `estado` en `Usuario`, `Marca`, `Producto`, `Categoria`, `Venta` y `Metodo_Pago`. Tomamos esta decisión arquitectónica para dar soporte directo a la retención histórica por motivos de auditoría y facturación. En lugar de eliminar físicamente los registros (un borrado en cascada que destruiría nuestro historial de ventas), el sistema podrá realizar "bajas lógicas" simplemente cambiando el estado del registro a inactivo.

---

### 4. Uso de Atributos Derivados

**Decisión:** Decidimos modelar `total` en la entidad `Venta` y `subtotal` en `Venta_Detalle` como atributos derivados, los cuales representamos con línea punteada.

**Justificación:** Hicimos esto para indicar que estos valores no deben persistirse de forma estática pura, sino que son el resultado de un cálculo dinámico (por ejemplo, multiplicando la `cantidad` por el `precio_unitario` para obtener el `subtotal`). Con esto prevenimos anomalías de actualización y nos aseguramos de que los totales reflejen siempre la sumatoria exacta de los montos involucrados en la operación.

---

### 5. Normalización de Imágenes (Entidad Débil)

**Decisión:** Elegimos separar las imágenes de los productos, creando para ello la entidad débil `Imagen` dependiente de `Producto` mediante la relación `Contiene`.

**Justificación:** Esta decisión nos permite que un único producto esté asociado a múltiples rutas de archivo fotográfico (`ruta_archivo`) sin necesidad de desnormalizar la tabla `Producto` agregando múltiples columnas estáticas. Al diseñarla como una entidad débil, nos aseguramos de que el ciclo de vida de las imágenes quede estrictamente atado al del producto al que pertenecen.
