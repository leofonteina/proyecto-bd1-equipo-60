# Etapa IV – Consulta 2: Informe de ventas por categoría (Reporte agregado)

## 1. Caso de uso

| Campo | Descripción |
|---|---|
| **Código** | CU-02 |
| **Nombre** | Informe de ventas por categoría |
| **Actor** | Administrador |
| **Objetivo** | Conocer cuántas ventas, cuántas unidades y qué monto total se registraron por cada categoría de producto en un rango de fechas. |
| **Precondición** | Existen ventas no canceladas dentro del rango de fechas consultado. |
| **Parámetros de entrada** | Fecha desde y fecha hasta (en el ejemplo, del `2026-09-10` al `2026-10-12`). |
| **Resultado** | Una fila por categoría con cantidad de ventas, unidades vendidas y total vendido. |
| **Script asociado** | `sql/consultas/informe_ventas.sql` |

---

## 2. Necesidad de información

El administrador necesita saber qué categorías de productos generan más ingresos y movimiento en un período, para decidir sobre compras, reposición de stock y promociones.

> **Justificación del criterio de agrupación:** la consigna admite el reporte por vendedor o por categoría. El modelo de datos no incluye la figura del vendedor (los clientes realizan las compras y el administrador solo carga los productos), por lo que el reporte se agrupa por **categoría de producto**.

---

## 3. Estrategia SQL

### Tablas involucradas

| Tabla | Alias | Aporta |
|---|---|---|
| `VENTA` | `v` | Fecha y estado de la venta (para filtrar el período y excluir canceladas). |
| `VENTA_DETALLE` | `vd` | Cantidad y subtotal de cada renglón. |
| `PRODUCTO` | `p` | Categoría a la que pertenece cada producto. |
| `CATEGORIA` | `c` | Nombre de la categoría. |

### Relaciones utilizadas

```
VENTA (1) ────< VENTA_DETALLE >──── (1) PRODUCTO >──── (1) CATEGORIA
  id_venta          id_producto           id_categoria
```

### Pasos de la consulta

1. Se unen las cuatro tablas para llegar desde cada venta hasta la categoría de cada producto vendido.
2. Con `WHERE` se filtran las ventas del rango de fechas y se descartan las canceladas.
3. Con `GROUP BY` se agrupan los renglones por categoría.
4. Con `COUNT` y `SUM` se calculan, para cada categoría, las ventas, las unidades y el monto total.
5. Se ordena el resultado de mayor a menor monto.

---

## 4. Preparación de datos (actualización de fechas)

La columna `VENTA.fecha_venta` toma por defecto `GETDATE()`, por lo que, sin modificarla, todas las ventas de prueba tendrían la fecha en que se ejecutó el script y el filtro por rango no se podría demostrar. Para repartirlas en el tiempo se aplican las siguientes actualizaciones sobre el lote de datos de prueba:

```sql
UPDATE VENTA SET fecha_venta = '2026-09-10' WHERE id_venta IN (1, 2);
UPDATE VENTA SET fecha_venta = '2026-09-25' WHERE id_venta IN (3, 4, 5);
UPDATE VENTA SET fecha_venta = '2026-10-05' WHERE id_venta IN (6, 7);
UPDATE VENTA SET fecha_venta = '2026-10-12' WHERE id_venta IN (8, 9, 10);
```

| Fecha | Ventas |
|---|---|
| 2026-09-10 | 1, 2 |
| 2026-09-25 | 3, 4, 5 |
| 2026-10-05 | 6, 7 |
| 2026-10-12 | 8, 9, 10 |

Estados de las ventas según el script de datos:

| Estado | Ventas |
|---|---|
| Entregado | 1, 2, 4, 6, 7 y 9 |
| Pendiente | 3, 8 y 10 |
| Cancelado | 5 |

---

## 5. Código SQL

```sql
DECLARE @desde DATETIME = '2026-09-10';
DECLARE @hasta DATETIME = '2026-10-12';

SELECT c.descripcion              AS categoria,
       COUNT(DISTINCT v.id_venta) AS cantidad_ventas,
       SUM(vd.cantidad)           AS unidades_vendidas,
       SUM(vd.subtotal)           AS total_vendido
FROM VENTA v
INNER JOIN VENTA_DETALLE vd ON vd.id_venta    = v.id_venta
INNER JOIN PRODUCTO p       ON p.id_producto  = vd.id_producto
INNER JOIN CATEGORIA c      ON c.id_categoria = p.id_categoria
WHERE v.fecha_venta >= @desde
  AND v.fecha_venta <  DATEADD(DAY, 1, @hasta)
  AND v.estado <> 'Cancelado'
GROUP BY c.descripcion
ORDER BY total_vendido DESC;
```

> Para consultar otro período, basta con cambiar los valores de `@desde` y `@hasta`. Se debe ejecutar el bloque completo (con los `DECLARE`).

---

## 6. Explicación de los elementos utilizados

### 6.1 `INNER JOIN`

Une las tablas conservando solo las filas con correspondencia en ambas. Se encadenan para recorrer el camino `VENTA → VENTA_DETALLE → PRODUCTO → CATEGORIA`.

| Unión | Condición | Para qué se usa |
|---|---|---|
| `VENTA` → `VENTA_DETALLE` | `vd.id_venta = v.id_venta` | Obtener los renglones de cada venta. |
| `VENTA_DETALLE` → `PRODUCTO` | `p.id_producto = vd.id_producto` | Saber qué producto se vendió en cada renglón. |
| `PRODUCTO` → `CATEGORIA` | `c.id_categoria = p.id_categoria` | Obtener el nombre de la categoría del producto. |

Una consecuencia del `INNER JOIN` es que las categorías sin ventas en el período (por ejemplo, **Gabinetes**) no aparecen en el resultado.

### 6.2 `WHERE`

Filtra las filas **antes de agrupar**:

- `v.fecha_venta >= @desde AND v.fecha_venta < DATEADD(DAY, 1, @hasta)`: selecciona el rango de fechas. Se usa `< @hasta + 1 día` en lugar de `<= @hasta` para incluir todas las ventas del último día, aunque tengan hora (una fecha sin hora equivale a las 00:00 y dejaría afuera las ventas posteriores de ese día).
- `v.estado <> 'Cancelado'`: excluye las ventas canceladas, que no representan ingresos.

### 6.3 `GROUP BY`

```sql
GROUP BY c.descripcion
```

Agrupa las filas por categoría. Las funciones de agregación se calculan por separado dentro de cada grupo. Toda columna del `SELECT` que no sea una agregación debe figurar en el `GROUP BY`.

### 6.4 `COUNT(DISTINCT v.id_venta)`

Cuenta **ventas distintas** por categoría. Se necesita `DISTINCT` porque, al unir con el detalle, una venta con varios productos de la misma categoría aparecería repetida una vez por renglón y se contaría de más.

### 6.5 `SUM(vd.cantidad)`

Suma las unidades vendidas de cada categoría.

### 6.6 `SUM(vd.subtotal)`

Suma el monto vendido de cada categoría. Se usa `VENTA_DETALLE.subtotal` (basado en el precio registrado al momento de la venta) y **no** `PRODUCTO.precio`, de modo que el reporte no cambia si los precios se actualizan después.

### 6.7 `DECLARE` y `DATEADD`

- `DECLARE @desde ... / @hasta ...`: define los parámetros del reporte al comienzo del script.
- `DATEADD(DAY, 1, @hasta)`: suma un día a la fecha final, para armar el límite superior exclusivo del rango.

### 6.8 `ORDER BY total_vendido DESC`

Ordena las categorías de mayor a menor monto vendido.

---

## 7. Resultado esperado

Con el rango del `2026-09-10` al `2026-10-12` (que abarca todas las ventas de prueba) y excluyendo la venta 5 (cancelada):

| categoria | cantidad_ventas | unidades_vendidas | total_vendido |
|---|---:|---:|---:|
| Procesadores | 3 | 4 | 910000.00 |
| Motherboards | 2 | 3 | 540000.00 |
| Memoria RAM | 3 | 8 | 520000.00 |
| Placas de Video | 1 | 1 | 450000.00 |
| Monitores | 1 | 1 | 280000.00 |
| Fuentes de Poder | 2 | 2 | 220000.00 |
| Almacenamiento SSD | 1 | 2 | 180000.00 |
| Teclados | 2 | 3 | 135000.00 |
| Mouse | 2 | 3 | 105000.00 |

> **Resumen global del período:** 9 ventas efectivas | 27 unidades vendidas | **$3.340.000,00** recaudados.
>
> La suma de la columna `cantidad_ventas` da 17 y no 9, porque una misma venta puede incluir productos de varias categorías y se cuenta en cada una de ellas.

### Segunda prueba: período acotado (`2026-10-01` al `2026-10-31`)

Con `@desde = '2026-10-01'` y `@hasta = '2026-10-31'` solo entran las ventas 6 a 10:

| categoria | cantidad_ventas | unidades_vendidas | total_vendido |
|---|---:|---:|---:|
| Procesadores | 2 | 3 | 690000.00 |
| Motherboards | 1 | 2 | 360000.00 |
| Monitores | 1 | 1 | 280000.00 |
| Memoria RAM | 1 | 2 | 130000.00 |
| Fuentes de Poder | 1 | 1 | 110000.00 |
| Teclados | 1 | 2 | 90000.00 |
| Mouse | 1 | 2 | 70000.00 |

> Total del período: 5 ventas | 13 unidades | **$1.730.000,00**. Esta prueba demuestra que el filtro por rango de fechas funciona: cambian las categorías, las cantidades y los montos.

---

## 8. Trazabilidad: cómo se construye el reporte

La siguiente tabla muestra cada renglón de `VENTA_DETALLE` y si el motor lo incluye en el reporte. El `GROUP BY` suma los renglones incluidos que pertenecen a la misma categoría.

| Venta | Fecha | Estado | Producto | Categoría | Cant. | Subtotal | ¿Se incluye? |
|:---:|:---:|:---:|:---|:---|:---:|---:|:---|
| 1 | 2026-09-10 | Entregado | Ryzen 5 5600 | Procesadores | 1 | 220000.00 | Sí |
| 1 | 2026-09-10 | Entregado | B550 Tomahawk | Motherboards | 1 | 180000.00 | Sí |
| 1 | 2026-09-10 | Entregado | Vengeance 16GB | Memoria RAM | 2 | 130000.00 | Sí |
| 2 | 2026-09-10 | Entregado | RTX 3060 12GB | Placas de Video | 1 | 450000.00 | Sí |
| 2 | 2026-09-10 | Entregado | Fuente 650W 80+ | Fuentes de Poder | 1 | 110000.00 | Sí |
| 3 | 2026-09-25 | Pendiente | Vengeance 16GB | Memoria RAM | 4 | 260000.00 | Sí |
| 4 | 2026-09-25 | Entregado | SSD 1TB NVMe | Almacenamiento SSD | 2 | 180000.00 | Sí |
| 4 | 2026-09-25 | Entregado | Mouse G203 | Mouse | 1 | 35000.00 | Sí |
| 4 | 2026-09-25 | Entregado | Teclado Kumara | Teclados | 1 | 45000.00 | Sí |
| 5 | 2026-09-25 | **Cancelado** | Mouse G203 | Mouse | 3 | 105000.00 | **No** (`estado <> 'Cancelado'`) |
| 5 | 2026-09-25 | **Cancelado** | Teclado Kumara | Teclados | 3 | 135000.00 | **No** (`estado <> 'Cancelado'`) |
| 6 | 2026-10-05 | Entregado | Monitor 24 144Hz | Monitores | 1 | 280000.00 | Sí |
| 7 | 2026-10-05 | Entregado | B550 Tomahawk | Motherboards | 2 | 360000.00 | Sí |
| 7 | 2026-10-05 | Entregado | Core i5 12400F | Procesadores | 2 | 460000.00 | Sí |
| 8 | 2026-10-12 | Pendiente | Teclado Kumara | Teclados | 2 | 90000.00 | Sí |
| 8 | 2026-10-12 | Pendiente | Mouse G203 | Mouse | 2 | 70000.00 | Sí |
| 9 | 2026-10-12 | Entregado | Fuente 650W 80+ | Fuentes de Poder | 1 | 110000.00 | Sí |
| 10 | 2026-10-12 | Pendiente | Core i5 12400F | Procesadores | 1 | 230000.00 | Sí |
| 10 | 2026-10-12 | Pendiente | Vengeance 16GB | Memoria RAM | 2 | 130000.00 | Sí |

### Ejemplo de agrupación: Procesadores

| Venta | Producto | Cant. | Subtotal |
|:---:|:---|:---:|---:|
| 1 | Ryzen 5 5600 | 1 | 220000.00 |
| 7 | Core i5 12400F | 2 | 460000.00 |
| 10 | Core i5 12400F | 1 | 230000.00 |
| | **Total** | **4** | **910000.00** |

Son 3 ventas distintas (1, 7 y 10), 4 unidades y $910.000, que coincide con la primera fila del reporte.

---

## 9. Verificación del resultado

| Control | Resultado |
|---|---|
| Suma de `total_vendido` del reporte | 3.340.000 |
| Suma de `VENTA.total` de las ventas no canceladas (1, 2, 3, 4, 6, 7, 8, 9, 10) | 3.340.000 ✔ |
| Suma de `unidades_vendidas` | 27 |
| Categoría Procesadores | 3 ventas, 4 unidades, 910.000 ✔ |
| Categoría Gabinetes | No aparece (sin ventas) ✔ |
| Categoría Mouse | Sí aparece, con las ventas 4 y 8 (la venta 5, cancelada, queda excluida) ✔ |

### Consulta de control

La suma del reporte debe coincidir con esta consulta, que no usa categorías ni `GROUP BY`:

```sql
SELECT SUM(vd.subtotal) AS total_general
FROM VENTA v
INNER JOIN VENTA_DETALLE vd ON vd.id_venta = v.id_venta
WHERE v.estado <> 'Cancelado'
  AND v.fecha_venta >= '2026-09-10'
  AND v.fecha_venta <  '2026-10-13';
```

Resultado esperado: **3340000.00**.

### Prueba del filtro de estado

Si se quita la condición `v.estado <> 'Cancelado'`, la venta 5 se suma al reporte:

| Cambio | Efecto |
|---|---|
| Mouse | pasa a 3 ventas, 6 unidades y 210.000. |
| Teclados | pasa a 3 ventas, 6 unidades y 270.000. |
| Total general | sube a 3.580.000 (+240.000). |

---

## 10. Observaciones

- **Categorías sin movimiento:** al usar `INNER JOIN`, Gabinetes no figura en el reporte. Para listarla con valor cero habría que partir de `CATEGORIA` con `LEFT JOIN` y mover los filtros de fecha y estado a la condición `ON`.
- **Ventas pendientes:** el reporte incluye las ventas en estado `Pendiente` (3, 8 y 10), porque solo se excluyen las canceladas. Si el negocio quisiera contar únicamente ingresos concretados, el filtro sería `v.estado = 'Entregado'`.
- **Importes históricos:** el reporte usa los subtotales registrados en el detalle de cada venta, por lo que los resultados no se alteran si cambian los precios del catálogo.
- **Reutilización:** esta consulta puede convertirse en un procedimiento almacenado con `@desde` y `@hasta` como parámetros (ver Etapa V).
