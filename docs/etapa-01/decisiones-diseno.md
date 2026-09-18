Decisiones de Diseño del Sistema
En este documento se detallan las decisiones arquitectónicas y de diseño de base de datos tomadas para dar cumplimiento a los requerimientos y reglas de negocio del sistema de ventas de componentes de computadora.
1. Catálogo de Productos y Precios
Baja Lógica (Soft Delete): Para cumplir con la regla de auditoría y facturación que prohíbe eliminar productos que posean un historial de ventas asociado (RN.08), se implementará un atributo booleano de estado (activo) en la tabla de productos. De este modo, los productos descontinuados no se borran físicamente de la base de datos, preservando la integridad referencial con las ventas históricas.
Clasificación y Atributos Condicionales: La categoría del producto (hardware, periférico o accesorio) se modelará mediante una restricción estricta. El campo correspondiente al período de garantía del fabricante admitirá valores nulos (NULL) para aquellos accesorios que no posean cobertura de garantía (RN.09).
2. Historial de Ventas y Precios Históricos
Desnormalización del Precio Unitario: La relación entre las ventas y los productos se resolverá a través de una tabla intermedia (detalle o ítem de venta). Esta tabla almacenará obligatoriamente el precio unitario vigente al momento exacto de la operación. Esta decisión de diseño garantiza que futuras actualizaciones de precios en el catálogo general no alteren de manera retroactiva los montos de las ventas ya concretadas (RN.05).
3. Control de Inventario y Stock
Atributos de Control: Cada producto contará con campos específicos para el stock actual y el stock mínimo establecido.
Validación Transaccional y Disparadores: Se establecerá lógica a nivel de base de datos o aplicación para verificar que la cantidad solicitada por el cliente no supere la disponible antes de confirmar cualquier venta (RN.01). Asimismo, se implementarán mecanismos automáticos (triggers o procedimientos) para descontar el inventario de forma inmediata tras cada venta confirmada (RN.02) y emitir alertas al responsable de compras cuando el stock alcance o caiga por debajo del umbral mínimo (RN.03).
4. Gestión de Clientes y Proveedores
Integridad y Unicidad: La tabla de clientes contará con una restricción de unicidad (UNIQUE) sobre el número de documento (DNI o CUIT) para prevenir registros duplicados. Los campos de identificación y al menos un canal de contacto serán obligatorios (RN.04).
Proveedores: Se dispondrá de una entidad orientada al registro básico de proveedores para la reposición de mercadería y control de stock.
5. Métodos de Pago y Financiación
Asociación Múltiple (Muchos a Muchos): Dado que una venta puede abonarse combinando distintos medios de pago (efectivo, tarjeta de débito, crédito o transferencia), se estructurará una tabla intermedia de pagos que relacione la venta con los métodos utilizados (RN.06).
Control de Cuotas: La estructura de pagos incluirá un campo para registrar la cantidad de cuotas acordadas, el cual será obligatorio exclusivamente cuando se seleccione tarjeta de crédito como medio de pago (RN.07).
6. Trazabilidad Operativa
Claves Foráneas Obligatorias: La tabla de cabecera de ventas incluirá claves foráneas estrictas (NOT NULL) que asociarán cada operación de manera unívoca a un cliente registrado y al usuario o vendedor responsable de haber concretado la transacción (RN.10).
