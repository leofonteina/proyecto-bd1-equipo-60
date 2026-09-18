# Reglas de negocio
## RN-01: No se podrá registrar la venta de un producto cuya cantidad disponible en stock sea menor a la cantidad solicitada por el cliente.
### RN-02: Cada venta confirmada reduce de forma inmediata la cantidad de unidades disponibles en el inventario del producto correspondiente.
### RN-03: El responsable de compras debe ser notificado apenas el stock de un producto alcance o caiga por debajo de su nivel mínimo establecido.
### RN-04: Todo cliente debe registrarse con, al menos, nombre y apellido, número de DNI o CUIT y un dato de contacto (teléfono y/o correo electrónico), no permitiéndose el registro de dos clientes con el mismo número de documento.
### RN-05: El detalle de cada compra debe almacenar el precio unitario vigente del producto en el momento exacto de la venta, de modo que las modificaciones posteriores al precio de un producto no alteren retroactivamente el importe de ventas ya registradas.
### RN-06: El sistema debe permitir registrar el o los métodos de pago utilizados en cada venta (efectivo, tarjeta de débito, tarjeta de crédito o transferencia bancaria), admitiendo la combinación de más de un método en una misma operación.
### RN-06: Las ventas abonadas con tarjeta de crédito pueden fraccionarse en cuotas, por lo que es obligatorio registrar la cantidad de cuotas acordadas con el cliente.
### RN-07: Los productos que posean un historial de ventas asociado no pueden ser borrados de los registros; deben ser conservados en estado inactivo por motivos de auditoría y facturación.
### RN-08: Todo producto debe registrarse indicando obligatoriamente su categoría (hardware, periférico o accesorio) y, cuando corresponda, el período de garantía ofrecido por el fabricante.
### RN-09: Toda venta debe quedar asociada a un cliente registrado y a un usuario/vendedor responsable de haber concretado la operación.
