# Etapa IV – Consulta 1: Factura / Comprobante de venta

## 1. Caso de uso

| Campo | Descripción |
|---|---|
| **Código** | CU-01 |
| **Nombre** | Emitir comprobante de venta |
| **Actor** | Administrador / Cliente |
| **Objetivo** | Obtener el comprobante completo de una venta, con sus datos de cabecera y el detalle de productos. |
| **Precondición** | La venta existe en la base de datos. |
| **Parámetro de entrada** | `id_venta` (en el ejemplo, la venta `1`). |
| **Resultado** | Una fila por producto vendido, con subtotal por renglón y el total acumulado de la venta. |
| **Script asociado** | `sql/consultas/comprobante_venta.sql` |

---

## 2. Necesidad de información

Cuando se concreta una venta, el cliente y el administrador necesitan un comprobante que consolide, en un solo resultado:

- **Encabezado:** número de venta, fecha, estado, datos del cliente y domicilio de entrega.
- **Detalle:** qué productos se vendieron, en qué cantidad y a qué precio.
- **Importes:** subtotal de cada renglón y total general de la venta.

Esta información está repartida en cuatro tablas (`VENTA`, `USUARIO`, `VENTA_DETALLE` y `PRODUCTO`), por lo que se necesita una consulta que las unifique.

---

## 3. Estrategia SQL

### Tablas involucradas

| Tabla | Alias | Aporta |
|---|---|---|
| `VENTA` | `v` | Número de venta, fecha, estado y domicilio de entrega. |
| `USUARIO` | `u` | Apellido, nombre y DNI del cliente. |
| `VENTA_DETALLE` | `vd` | Cantidad y precio unitario de cada renglón. |
| `PRODUCTO` | `p` | Nombre del producto. |

### Relaciones utilizadas

```
USUARIO (1) ────< VENTA (1) ────< VENTA_DETALLE >──── (1) PRODUCTO
   id_usuario        id_venta          id_producto
```

- Un usuario realiza muchas ventas (1:N).
- Una venta tiene muchos renglones de detalle (1:N).
- Un producto aparece en muchos renglones de detalle (1:N).

### Pasos de la consulta

1. Se parte de `VENTA`, filtrando la venta deseada con `WHERE`.
2. Se une con `USUARIO` para mostrar el nombre del cliente en lugar de su `id_usuario`.
3. Se une con `VENTA_DETALLE` para obtener los renglones de la venta.
4. Se une con `PRODUCTO` para mostrar el nombre del producto en lugar de su `id_producto`.
5. Se calcula el subtotal de cada renglón (`cantidad * precio_unitario`).
6. Se calcula el total de la venta con una función de ventana, sin perder el detalle de cada renglón.
7. Se ordenan los renglones según su orden de carga.

---

## 4. Código SQL

```sql
SELECT v.id_venta,
       v.fecha_venta,
       v.estado,
       u.apellido + ', ' + u.nombre AS cliente,
       u.dni,
       v.domicilio_entrega,
       p.nombre AS producto,
       vd.cantidad,
       vd.precio_unitario,
       vd.cantidad * vd.precio_unitario AS subtotal_renglon,
       SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY v.id_venta) AS total_acumulado
FROM VENTA v
INNER JOIN USUARIO u        ON u.id_usuario  = v.id_usuario
INNER JOIN VENTA_DETALLE vd ON vd.id_venta   = v.id_venta
INNER JOIN PRODUCTO p       ON p.id_producto = vd.id_producto
WHERE v.id_venta = 1
ORDER BY vd.id_venta_detalle;
```

> Para consultar otro comprobante, basta con cambiar el valor del `WHERE` (por ejemplo, `v.id_venta = 2`).

---

## 5. Explicación de los elementos utilizados

### 5.1 `INNER JOIN`

Combina filas de dos tablas cuando se cumple la condición indicada en `ON`. Solo devuelve las filas que tienen correspondencia en ambas tablas.

| Unión | Condición | Para qué se usa |
|---|---|---|
| `VENTA` → `USUARIO` | `u.id_usuario = v.id_usuario` | Obtener los datos del cliente que realizó la compra. |
| `VENTA` → `VENTA_DETALLE` | `vd.id_venta = v.id_venta` | Obtener los renglones que componen la venta. |
| `VENTA_DETALLE` → `PRODUCTO` | `p.id_producto = vd.id_producto` | Obtener el nombre del producto de cada renglón. |

Se usa `INNER JOIN` porque todas las claves foráneas son `NOT NULL`: una venta siempre tiene cliente, y cada renglón siempre tiene producto y venta. No hay filas huérfanas que se puedan perder.

### 5.2 Alias de tablas (`v`, `u`, `vd`, `p`)

Nombres cortos para las tablas. Hacen la consulta más legible y evitan ambigüedades, ya que `id_venta` existe tanto en `VENTA` como en `VENTA_DETALLE`.

### 5.3 Alias de columnas (`AS`)

Asigna un nombre descriptivo a una columna calculada o combinada: `cliente`, `producto`, `subtotal_renglon` y `total_acumulado`.

### 5.4 Concatenación con `+`

```sql
u.apellido + ', ' + u.nombre AS cliente
```

En SQL Server, el operador `+` une cadenas de texto. Genera un único campo con el formato `Apellido, Nombre`.

### 5.5 Operador aritmético `*`

```sql
vd.cantidad * vd.precio_unitario AS subtotal_renglon
```

Calcula el subtotal de cada renglón. Se usa `vd.precio_unitario` (el precio registrado en el momento de la venta) y **no** el precio actual de `PRODUCTO.precio`. Así el comprobante no cambia si el producto se reprecia más adelante, cumpliendo la regla de negocio de *historial de precios*.

### 5.6 `SUM() OVER (PARTITION BY ...)` – función de ventana

```sql
SUM(vd.cantidad * vd.precio_unitario) OVER (PARTITION BY v.id_venta) AS total_acumulado
```

| Parte | Significado |
|---|---|
| `SUM(...)` | Operación de agregación: suma los subtotales. |
| `OVER` | Indica que se calcula como función de ventana, es decir, **sin colapsar las filas**. |
| `PARTITION BY v.id_venta` | Divide las filas en grupos (uno por venta); la suma se calcula dentro de cada grupo. |

En palabras: *"para cada fila, sumá los subtotales de todas las filas que pertenezcan a la misma venta"*.

**Diferencia con `GROUP BY`:** `GROUP BY` fusiona las filas del grupo en una sola y se pierde el detalle por producto. Con `OVER (PARTITION BY ...)` se conserva cada renglón y el total se agrega como una columna adicional, repetido en todas las filas de la venta.

### 5.7 `WHERE`

```sql
WHERE v.id_venta = 1
```

Filtra la consulta para que devuelva únicamente el comprobante de la venta indicada. Sin este filtro se mezclarían todas las ventas.

### 5.8 `ORDER BY`

```sql
ORDER BY vd.id_venta_detalle
```

Ordena los renglones según el orden en que se cargaron en la venta (`id_venta_detalle` es autoincremental).

---

## 6. Resultado esperado

Datos de la venta 1 según el script `datos_prueba.sql`:

- Cliente: usuario `2` (Laura Pérez).
- Estado: `Entregado` (se actualiza a ese estado en el script de datos).
- Pagos registrados: $130.000 en efectivo + $400.000 con tarjeta de débito = $530.000.

### Resultado de la consulta

| id_venta | fecha_venta | estado | cliente | dni | domicilio_entrega | producto | cantidad | precio_unitario | subtotal_renglon | total_acumulado |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | *(fecha de carga)* | Entregado | Perez, Laura | 22222222 | Belgrano 456, Córdoba | Ryzen 5 5600 | 1 | 220000.00 | 220000.00 | 530000.00 |
| 1 | *(fecha de carga)* | Entregado | Perez, Laura | 22222222 | Belgrano 456, Córdoba | B550 Tomahawk | 1 | 180000.00 | 180000.00 | 530000.00 |
| 1 | *(fecha de carga)* | Entregado | Perez, Laura | 22222222 | Belgrano 456, Córdoba | Vengeance 16GB | 2 | 65000.00 | 130000.00 | 530000.00 |

> La columna `fecha_venta` toma el valor de `GETDATE()` en el momento en que se ejecutó el script de datos, por lo que variará según cuándo se haya cargado la base.

### Vista tipo comprobante

```
COMPROBANTE DE VENTA N° 1
------------------------------------------------------------
Cliente:    Perez, Laura            DNI: 22222222
Domicilio:  Belgrano 456, Córdoba
Estado:     Entregado
------------------------------------------------------------
Producto          Cant.   P. Unitario     Subtotal
Ryzen 5 5600        1     $220.000,00    $220.000,00
B550 Tomahawk       1     $180.000,00    $180.000,00
Vengeance 16GB      2      $65.000,00    $130.000,00
------------------------------------------------------------
                                  TOTAL: $530.000,00
```

---

## 7. Verificación del resultado

| Control | Resultado |
|---|---|
| Cantidad de filas devueltas | 3 (coincide con los renglones de la venta 1 en `VENTA_DETALLE`). |
| Suma de subtotales | 220.000 + 180.000 + 130.000 = **530.000**. |
| `total_acumulado` vs. `VENTA.total` | 530.000 = 530.000 ✔ |
| `total_acumulado` vs. suma de `VENTA_PAGO` | 530.000 = 530.000 ✔ |

---

## 8. Observaciones

- **Precio histórico:** el subtotal se calcula con `VENTA_DETALLE.precio_unitario`, no con `PRODUCTO.precio`, para evitar cambios retroactivos si el precio del producto se modifica.
- **Domicilio de entrega:** `VENTA.domicilio_entrega` guarda el domicilio tal como fue informado al momento de la compra, de manera que el comprobante no se altera si el cliente cambia su dirección.
- **Encabezado repetido:** los datos de cabecera (cliente, fecha, domicilio) aparecen en cada fila. Es el comportamiento esperado al combinar encabezado y detalle en un único `SELECT`.
- **Reutilización:** esta consulta puede convertirse en un procedimiento almacenado con `@id_venta` como parámetro (ver Etapa V).
