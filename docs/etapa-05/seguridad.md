 # Seguridad: roles, permisos y control de acceso en SQL Server

> Etapa V · Tema técnico: Seguridad · Sistema de ventas · SQL Server Express

---

## 1. Definición y objetivo

### Qué es

La seguridad de una base de datos define **quién puede acceder a la información y qué operaciones puede realizar**. En SQL Server se administra con tres elementos:

- **Usuarios:** identidades dentro de la base de datos.
- **Roles:** grupos de permisos reutilizables. Cada usuario hereda los permisos de los roles a los que pertenece.
- **Permisos:**
  - `GRANT`: otorga un permiso.
  - `DENY`: lo prohíbe de forma explícita y tiene prioridad sobre cualquier `GRANT`.
  - `REVOKE`: retira un permiso otorgado o denegado.

Se aplica el **principio de mínimo privilegio**: cada actor recibe únicamente los permisos que necesita para su tarea.

### Objetivo en el sistema de ventas

1. Que ningún usuario modifique las tablas directamente, y que toda escritura pase por procedimientos almacenados que validan las reglas de negocio.
2. Que cada operación quede asociada a la persona que la realiza, sin depender de un dato que el usuario pueda falsear.
3. Contar con dos perfiles, **cliente** y **administrador**, a los que se puedan asignar permisos de forma independiente.
4. Demostrar el funcionamiento con pruebas que muestren operaciones permitidas y operaciones rechazadas.

---

## 2. Ventajas y aplicaciones

### Ventajas

- **Integridad de los datos:** las reglas de negocio (stock suficiente, producto activo, venta pendiente, propietario de la venta) se aplican siempre, porque no existe otro camino para escribir en las tablas.
- **Menor superficie de ataque:** los usuarios no ejecutan `INSERT`, `UPDATE` ni `DELETE` propios. Los procedimientos reciben parámetros tipados, lo que dificulta la inyección SQL.
- **Administración simple:** los permisos se definen una vez por rol. Incorporar o quitar a una persona es una sola instrucción.
- **Trazabilidad:** cada venta queda asociada al usuario identificado en la sesión.
- **Prevención de errores:** un usuario no puede borrar o modificar datos por accidente.

### Aplicaciones en el sistema

| Situación | Cómo la resuelve la seguridad |
|---|---|
| Un cliente quiere comprar | Ejecuta `sp_RegistrarVenta`; no puede escribir en `VENTA` |
| Un cliente quiere anular su compra | Ejecuta `sp_CancelarVenta`; solo puede cancelar ventas propias y pendientes |
| Alguien intenta modificar una venta con un `INSERT` o `UPDATE` directo | SQL Server rechaza la operación por permiso denegado |
| Un administrador necesita operar sobre las ventas | Usa los mismos procedimientos; tampoco accede directamente a las tablas |

### Consideraciones

- El mantenimiento de permisos requiere disciplina: un `DENY` olvidado puede bloquear accesos legítimos.
- La cadena de propiedad (ver 3.4) se rompe si un procedimiento usa SQL dinámico.
- La identificación del usuario depende de que la aplicación guarde correctamente el dato de sesión (ver 6).

---

## 3. Implementación en SQL Server Express

Todos los mecanismos utilizados están disponibles en SQL Server Express. `SESSION_CONTEXT` requiere SQL Server 2016 o superior.

### 3.1 Roles

Se crean dos roles de base de datos, uno por perfil:

```sql
CREATE ROLE rol_administrador;
CREATE ROLE rol_cliente;
```

Los scripts comprueban antes si el rol existe, de modo que pueden ejecutarse más de una vez sin errores.

### 3.2 Usuarios de demostración

```sql
CREATE USER usuario_demo_administrador WITHOUT LOGIN;
CREATE USER usuario_demo_cliente       WITHOUT LOGIN;
```

`WITHOUT LOGIN` crea un usuario que existe solo dentro de la base y **no puede conectarse al servidor**. Se usa junto con `EXECUTE AS USER` para simular a cada actor sin necesidad de contraseñas ni de habilitar la autenticación mixta, que SQL Server Express no trae activada por defecto.

Cada usuario se asigna a su rol: `usuario_demo_administrador` a `rol_administrador` y `usuario_demo_cliente` a `rol_cliente`.

### 3.3 Matriz de permisos

| Objeto | `rol_cliente` | `rol_administrador` |
|---|---|---|
| Procedimiento `sp_RegistrarVenta` | `EXECUTE` | `EXECUTE` |
| Procedimiento `sp_CancelarVenta` | `EXECUTE` | `EXECUTE` |
| Tipo tabla `tipo_item_venta` | `EXECUTE`, `REFERENCES` | `EXECUTE`, `REFERENCES` |
| Tablas `USUARIO`, `METODO_PAGO`, `PRODUCTO`, `VENTA`, `VENTA_DETALLE`, `VENTA_PAGO` | `DENY` de `SELECT`, `INSERT`, `UPDATE` y `DELETE` | `DENY` de `SELECT`, `INSERT`, `UPDATE` y `DELETE` |

- El tipo `tipo_item_venta` es el "carrito" que recibe `sp_RegistrarVenta` como parámetro (lista de productos y cantidades). Para usarlo hay que tener permiso sobre el tipo, además del permiso sobre el procedimiento.
- Ningún rol accede a las tablas de forma directa: toda modificación de ventas pasa por los procedimientos. Los roles se mantienen separados para poder asignarles permisos distintos a medida que el sistema crece.

### 3.4 Los procedimientos como barrera de seguridad

Los usuarios no tienen permiso sobre las tablas, pero sí sobre los procedimientos. Esto funciona por el **encadenamiento de propiedad**: como el procedimiento y las tablas pertenecen al mismo propietario (`dbo`), SQL Server verifica únicamente el permiso `EXECUTE` sobre el procedimiento y **no revisa los permisos (ni los `DENY`) sobre las tablas** que este utiliza.

```
Cliente ── EXECUTE ──► sp_RegistrarVenta ──► VENTA, VENTA_DETALLE, VENTA_PAGO, PRODUCTO   (permitido)
Cliente ── INSERT directo ───────────────► VENTA                                           (rechazado)
```

### 3.5 Identificación del usuario con `SESSION_CONTEXT`

Los procedimientos no reciben el `id_usuario` como parámetro. Lo leen del contexto de la sesión:

```sql
SET @id_usuario = TRY_CONVERT(INT, SESSION_CONTEXT(N'id_usuario'));
```

La aplicación, una vez autenticada la persona, guarda su identificador con `sp_set_session_context`. Si el dato no está, el procedimiento lanza un error y no opera.

Frente a otras opciones:

- **Pasar el `id_usuario` como parámetro:** cualquiera podría indicar un identificador ajeno.
- **Usar `USER_NAME()` o `SUSER_SNAME()`:** exigiría un usuario de base de datos por cada cliente real, lo cual es inviable.

### 3.6 Reglas de seguridad dentro de los procedimientos

| Procedimiento | Controles |
|---|---|
| `sp_RegistrarVenta` | Usuario identificado, existente y activo. Domicilio obligatorio. Al menos un producto con cantidad positiva. Método de pago existente. Productos existentes, activos y con stock suficiente. |
| `sp_CancelarVenta` | Usuario identificado. Venta existente. **Solo el propietario** de la venta puede cancelarla. Solo si está `Pendiente`; se rechaza si ya está cancelada. |

Ambos procedimientos usan una transacción con `SET XACT_ABORT ON` y `TRY...CATCH`: si una validación falla, se deshace todo y no queda ninguna operación a medias. Además bloquean las filas con `UPDLOCK, ROWLOCK` para evitar que dos operaciones simultáneas vendan el mismo stock.

### 3.7 Alternativas consideradas

| Alternativa | Por qué no se eligió |
|---|---|
| Permisos asignados directamente a cada usuario | No escala: cada alta o baja exige repetir los permisos |
| Roles fijos (`db_datareader`, `db_datawriter`, `db_owner`) | Demasiado amplios. Permiten leer o modificar todo, incluidos datos personales |
| Roles propios con `INSERT`/`UPDATE` sobre las tablas | Se pueden saltear las reglas de negocio (stock, estados, propietario) |
| **Roles propios + procedimientos + `DENY` sobre las tablas (elegida)** | Las reglas se aplican siempre, el acceso es mínimo y se administra por perfil |

---

## 4. Caso concreto aplicado al sistema de ventas

### Actores

- **Cliente:** compra productos y puede cancelar sus compras pendientes. No accede a las tablas.
- **Administrador:** perfil de gestión del sistema. En esta versión opera, igual que el cliente, solo mediante los procedimientos y no accede directamente a las tablas.

### Flujo de una compra

1. La aplicación autentica a la persona y guarda su identificador en el contexto de la sesión.
2. El cliente arma el carrito (`tipo_item_venta`) y ejecuta `sp_RegistrarVenta`.
3. El procedimiento identifica al usuario, valida la operación y, dentro de una transacción, registra la venta, su detalle y su pago, y descuenta el stock.
4. Si el cliente se arrepiente, ejecuta `sp_CancelarVenta`. El procedimiento verifica que la venta sea suya y esté pendiente, la marca como `Cancelado` y devuelve el stock.

### Qué impide el sistema

- Que un cliente registre una compra a nombre de otro: el usuario sale de la sesión y no de un parámetro.
- Que un cliente cancele la compra de otra persona.
- Que se escriba en `VENTA` con un `INSERT` directo.
- Que un usuario ajeno a los roles ejecute los procedimientos, porque el permiso `EXECUTE` se otorga únicamente a los roles.

### Cumplimiento de las reglas de negocio

Los procedimientos y permisos de esta sección hacen cumplir, total o parcialmente, las siguientes reglas definidas en la Etapa I (Requerimientos y Dominio del Negocio):

| Regla | Descripción resumida | Estado | Cómo se cumple |
|---|---|---|---|
| **RN.01** | No se vende un producto sin stock suficiente | Cumple | `sp_RegistrarVenta` compara el stock con la cantidad pedida (sumando las líneas repetidas de un mismo producto) y rechaza la operación con `Stock insuficiente para uno o mas productos.` Las filas de `PRODUCTO` se bloquean durante la transacción, para que dos ventas simultáneas no se lleven el mismo stock. |
| **RN.02** | Cada venta reduce de inmediato el stock | Cumple | El descuento se hace en la misma transacción que registra la venta. Si una venta pendiente se cancela, `sp_CancelarVenta` repone las unidades. |
| **RN.05** | El detalle guarda el precio vigente al momento de la venta | Cumple | `sp_RegistrarVenta` toma el precio de `PRODUCTO` en ese momento y lo guarda en `VENTA_DETALLE.precio_unitario`. Un cambio posterior de precio no altera ventas ya registradas. |
| **RN.08** | Los productos con ventas no se borran; quedan inactivos | Cumple | La clave foránea de `VENTA_DETALLE` hacia `PRODUCTO` no tiene borrado en cascada, y los roles tienen `DENY` de `DELETE` sobre las tablas. Además, `sp_RegistrarVenta` rechaza productos inactivos (`discontinuados`). |
| **RN.10** | Toda venta se asocia a un usuario registrado | Parcial | El procedimiento valida que el usuario de la sesión exista y esté activo, y lo guarda en `VENTA.id_usuario`. El modelo tiene un único usuario por venta, por lo que no distingue entre el cliente y un vendedor responsable de la operación. |
| **RN.06** | Se registra el método de pago, y se pueden combinar varios en una venta | Parcial | `sp_RegistrarVenta` valida el método de pago y registra el pago en `VENTA_PAGO`. El procedimiento recibe un único método por venta; el modelo admite varios, pero todavía no se implementa en el procedimiento. |
| **RN.03** | Se notifica al responsable de compras cuando el stock llega al mínimo | Parcial | Después de registrar la venta, el procedimiento devuelve la lista de productos que quedaron con stock crítico o sin stock (según `fn_EstadoStockProducto`). No hay una notificación automática al responsable. |

Las reglas **RN.04** (registro de clientes), **RN.07** (cuotas con tarjeta de crédito) y **RN.09** (categoría y garantía del producto) corresponden al modelo de datos y quedan fuera del alcance de esta sección.

---

## 5. Script de demostración y resultados

### Archivos y orden de ejecución

1. Tablas y datos de prueba (DDL y DML).
2. Funciones y procedimientos (`sql/funciones`, `sql/procedimientos`).
3. `sql/seguridad`: script de seguridad (roles, usuarios, permisos).
4. `sql/seguridad`: script de demostración.

### Cómo funciona la demostración

El script de demostración se ejecuta **de una sola vez**, en un único lote. Primero elige datos de prueba que ya existen (dos usuarios activos, un método de pago y un producto con stock) y luego realiza seis pruebas seguidas. Cada una imprime con `PRINT` si el resultado fue el esperado.

- **Pruebas 1 a 5:** se ejecutan con el usuario de conexión del script. La identidad de cada cliente se simula con `sp_set_session_context`, que es lo que haría la aplicación luego de autenticar a la persona. Verifican las reglas de autorización de los procedimientos: identificación de la sesión y propiedad de la venta.
- **Prueba 6:** usa `EXECUTE AS USER = 'usuario_demo_cliente'` para actuar como un usuario con el rol cliente y comprobar que no puede escribir directamente en las tablas. Después vuelve al usuario original con `REVERT`.
- Las pruebas que se espera que fallen están dentro de `TRY...CATCH`.
- Al final, el script cancela la segunda venta para devolver el stock, muestra el estado final y limpia el contexto de sesión.

### Pruebas realizadas

| N° | Prueba | Cómo se ejecuta | Resultado esperado | Salida esperada | Resultado obtenido |
|---|---|---|---|---|---|
| 1 | Registrar una venta sin identidad de sesión | `id_usuario` en `NULL` | Rechazado | `CORRECTO: la venta fue rechazada.` Motivo: `No se pudo identificar al usuario de la sesion.` | |
| 2 | Registrar la venta del usuario 1 | Sesión con el `id_usuario` del usuario 1 | Permitido | `CORRECTO: venta registrada.` y el `id_venta` generado. El stock del producto baja 1 | |
| 3 | Registrar la venta del usuario 2 | Sesión con el `id_usuario` del usuario 2 | Permitido | `CORRECTO: venta registrada.` y el `id_venta` generado | |
| 4 | El usuario 1 intenta cancelar la venta del usuario 2 | Sesión con el `id_usuario` del usuario 1 | Rechazado | `CORRECTO: no se permitio cancelar la venta ajena.` Motivo: `No tiene permisos para cancelar esta venta.` | |
| 5 | El usuario 1 cancela su propia venta pendiente | Sesión con el `id_usuario` del usuario 1 | Permitido | Muestra la venta en estado `Pendiente`, luego `Venta cancelada y stock repuesto correctamente.` y `CORRECTO: la venta propia fue cancelada.` | |
| 6 | `INSERT` directo en `VENTA` | `EXECUTE AS USER = 'usuario_demo_cliente'` | Rechazado | `CORRECTO: acceso directo rechazado.` Motivo: `The INSERT permission was denied on the object 'VENTA', database 'nombre_bd', schema 'dbo'.` | |

El texto exacto de los mensajes de SQL Server depende del idioma de la instalación.

### Verificación final

Al terminar, el script consulta el estado de las dos ventas creadas y el stock del producto utilizado:

| Verificación | Valor esperado | Valor obtenido |
|---|---|---|
| Venta del usuario 1 | `Cancelado` | |
| Venta del usuario 2 | `Cancelado` | |
| Stock final del producto | Igual al `stock_inicial` mostrado al comienzo | |

Las cancelaciones devuelven el stock descontado por las ventas, por eso el producto termina con el mismo stock con el que empezó.

### Capturas de la demostración

Como el script se ejecuta de una sola vez, la evidencia es una única corrida capturada en tramos.

Recomendaciones:

- En SSMS, antes de ejecutar, activar **Results to Text** (`Ctrl + T`). Así los `PRINT`, los errores y las tablas de resultado aparecen en orden en un mismo panel, y la corrida se lee de arriba hacia abajo.
- Ejecutar el script completo y capturar el panel desplazándolo, tramo por tramo.
- Que los mensajes de error se vean completos.

#### Preparación: roles y miembros

Qué se ve: la grilla final del script de seguridad (columnas `rol` y `usuario`).

#### Tramo 1: datos de prueba y pruebas 1 y 2

Qué se ve: los datos seleccionados (usuarios, método de pago, producto y `stock_inicial`), el rechazo de la prueba 1 con su motivo y la venta registrada en la prueba 2.

#### Tramo 2: pruebas 3 y 4

Qué se ve: la venta registrada del usuario 2 y el rechazo al intentar cancelar una venta ajena, con su motivo.

#### Tramo 3: pruebas 5 y 6

Qué se ve: la venta propia antes de cancelar, la cancelación correcta y el rechazo del `INSERT` directo con el mensaje de permiso denegado.

#### Tramo 4: limpieza y resultado final

Qué se ve: la cancelación de la segunda venta, el estado final de las dos ventas (`Cancelado`) y el stock final del producto.


### Limpieza opcional

Las ventas de prueba quedan registradas como canceladas. Si se desea dejar la base limpia, se pueden eliminar con una consulta como esta, ejecutada con un usuario administrador de la base (el borrado en `VENTA` elimina también sus detalles y pagos por la regla `ON DELETE CASCADE`):

```sql
DELETE FROM dbo.VENTA WHERE domicilio_entrega LIKE 'Domicilio de prueba%';
```

<img width="599" height="778" alt="Prueba definitiva" src="https://github.com/user-attachments/assets/c0c60c71-8d24-47c8-8c6e-12fc2e5f342e" />
<img width="710" height="565" alt="Resultados" src="https://github.com/user-attachments/assets/5758c110-7427-40cc-8dbb-6741274a8f1c" />


---

## 6. Limitaciones y posibles mejoras

- **El contexto de sesión lo establece la aplicación.** Si el valor de `id_usuario` se guarda sin protección, una sesión podría modificarlo. En un sistema real la aplicación debe fijarlo al abrir la conexión con el parámetro `@read_only = 1` de `sp_set_session_context`, para que no pueda cambiarse durante la sesión.
- **Los usuarios `WITHOUT LOGIN` son solo para la demostración.** En producción cada actor se conectaría con un login real, con política de contraseñas, asociado a su rol.
- **Las pruebas 1 a 5 se ejecutan con el usuario de conexión del script**, no con un usuario del rol cliente. Verifican la lógica de autorización de los procedimientos; la prueba 6 es la que verifica los permisos del rol. Una mejora posible es ejecutar también las pruebas 2, 3 y 5 con `EXECUTE AS USER`, para comprobar además el permiso `EXECUTE` del rol.
- **Ambos roles tienen hoy el mismo conjunto de permisos** (solo procedimientos). Se mantienen separados para poder diferenciarlos más adelante, por ejemplo con consultas de reportes para el administrador.
- **Un `DENY` tiene prioridad sobre cualquier `GRANT`.** Un usuario que pertenezca a un rol con `DENY` no podrá recuperar ese permiso por otro rol.
- **Este trabajo no cubre cifrado ni enmascaramiento de datos personales** (por ejemplo `dni` o `email`), que serían mejoras posibles.
- **La auditoría de cambios** (quién modificó qué) se resuelve con los triggers de auditoría del tema siguiente.
