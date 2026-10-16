# Etapa IV – Casos de uso y consultas

## 1. Introducción

En esta etapa se desarrollan y prueban las consultas SQL que responden a las necesidades de información del sistema de ventas de hardware y periféricos de computación. Cada consulta se documenta como un **caso de uso**: quién necesita la información, qué problema resuelve, qué estrategia SQL utiliza y qué resultado se espera al ejecutarla sobre los datos de prueba.

Este documento es el **índice general** de la etapa. El detalle de cada consulta (código, explicación de cada cláusula, resultado esperado y verificación) se encuentra en su documento específico.

---

## 2. Actores del sistema

Los actores corresponden a los roles registrados en la tabla `ROL`.

| Actor | Descripción | Casos de uso en los que participa |
|---|---|---|
| **Administrador** | Gestiona el catálogo de productos, controla las ventas y analiza reportes del negocio. | CU-01, CU-02, CU-03 |
| **Cliente** | Realiza compras y consulta los comprobantes de sus operaciones. | CU-01 |

## 3. Resumen de casos de uso

| N° | Caso de uso | Actor | Necesidad de información | Documento | Script SQL |
|---|---|---|---|---|---|
| **CU-01** | Emitir comprobante de venta | Administrador / Cliente | Consolidar encabezado y detalle de una venta, con subtotales por renglón y total acumulado. | `comprobante-venta.md` | `sql/consultas/comprobante_venta.sql` |
| **CU-02** | Informe de ventas por categoría | Administrador | Conocer cuántas ventas, unidades y qué monto se registraron por categoría de producto en un rango de fechas. | `informe-ventas.md` | `sql/consultas/informe_ventas.sql` |
| **CU-03** | Identificar clientes de mayor valor | Administrador | Detectar a los clientes cuyo gasto total supera el promedio, para acciones comerciales. | `consulta-avanzada.md` | `sql/consultas/consulta_avanzada.sql` |

---

## 4. Detalle de cada caso de uso

### CU-01 – Emitir comprobante de venta

| Campo | Descripción |
|---|---|
| **Actor** | Administrador / Cliente |
| **Objetivo** | Obtener el comprobante completo de una venta. |
| **Precondición** | La venta existe en la base de datos. |
| **Parámetro de entrada** | `id_venta` (en el ejemplo, la venta 1). |
| **Tablas involucradas** | `VENTA`, `USUARIO`, `VENTA_DETALLE`, `PRODUCTO` |
| **Estrategia SQL** | `INNER JOIN` de cuatro tablas, subtotal por renglón con `cantidad * precio_unitario` y total de la venta con la función de ventana `SUM() OVER (PARTITION BY id_venta)`. |
| **Resultado** | Una fila por producto vendido, con el total de la venta repetido como columna adicional. |
| **Resultado esperado (venta 1)** | 3 renglones (Ryzen 5 5600, B550 Tomahawk y Vengeance 16GB) y un total de **$530.000,00**. |

### CU-02 – Informe de ventas por categoría

| Campo | Descripción |
|---|---|
| **Actor** | Administrador |
| **Objetivo** | Medir el desempeño comercial de cada categoría de producto en un período. |
| **Precondición** | Existen ventas no canceladas dentro del rango de fechas consultado. |
| **Parámetros de entrada** | Fecha desde y fecha hasta (en el ejemplo, del `2026-09-10` al `2026-10-12`). |
| **Tablas involucradas** | `VENTA`, `VENTA_DETALLE`, `PRODUCTO`, `CATEGORIA` |
| **Estrategia SQL** | `INNER JOIN` de cuatro tablas, filtro por rango de fechas y estado, y agrupación con `GROUP BY` usando `COUNT(DISTINCT id_venta)`, `SUM(cantidad)` y `SUM(subtotal)`. |
| **Resultado** | Una fila por categoría con cantidad de ventas, unidades vendidas y monto total. |
| **Resultado esperado** | 9 categorías con movimiento, 9 ventas efectivas (se excluye la venta 5, cancelada), 27 unidades y **$3.340.000,00** en total. La categoría de mayor facturación es Procesadores ($910.000,00). |

> **Justificación del criterio:** la consigna admite el reporte por vendedor o por categoría. El modelo no tiene la figura de vendedor (los clientes compran y el administrador solo carga productos), por lo que se agrupa por **categoría de producto**.

### CU-03 – Identificar clientes de mayor valor

| Campo | Descripción |
|---|---|
| **Actor** | Administrador |
| **Objetivo** | Identificar a los clientes con gasto superior al promedio, como insumo para acciones comerciales. |
| **Precondición** | Existen ventas en estado `Entregado`. |
| **Parámetros de entrada** | Ninguno. |
| **Tablas involucradas** | `USUARIO`, `DIRECCION`, `CIUDAD`, `PROVINCIA`, `VENTA` |
| **Estrategia SQL** | `INNER JOIN` de cinco tablas, filtro `WHERE` sobre ventas entregadas, agrupación por cliente y `HAVING` que compara el gasto de cada cliente contra una subconsulta con `AVG(total)`. |
| **Resultado** | Cliente, provincia, cantidad de compras y gasto total, ordenados de mayor a menor gasto. |
| **Resultado esperado** | 3 clientes por encima del promedio de **$426.666,67**: Sofia Luna ($820.000,00), Carlos Lopez ($560.000,00) y Laura Perez ($530.000,00). |

---

## 5. Cobertura de los requisitos de la Etapa IV

| Requisito de la consigna | Caso de uso | Cómo se cumple |
|---|---|---|
| **Factura / Comprobante:** encabezado y detalle de una venta, con subtotales por renglón y total acumulado. | CU-01 | `JOIN` de encabezado y detalle, subtotal por renglón y total con función de ventana. |
| **Reporte agregado:** total de ventas por vendedor o categoría en un rango de fechas (`GROUP BY`, `SUM`, `COUNT`). | CU-02 | Agrupación por categoría con `COUNT`, `SUM` y filtro de fechas. |
| **Consulta de negocio avanzada:** al menos 3 tablas con `JOIN` y filtros condicionales (`HAVING` o subconsultas). | CU-03 | 5 tablas unidas, `HAVING` y subconsulta con `AVG`. |

### Elementos de SQL utilizados en cada consulta

| Elemento | CU-01 | CU-02 | CU-03 |
|---|:---:|:---:|:---:|
| `INNER JOIN` | ✔ | ✔ | ✔ |
| `WHERE` | ✔ | ✔ | ✔ |
| `GROUP BY` | | ✔ | ✔ |
| `COUNT` | | ✔ | ✔ |
| `SUM` | ✔ (como función de ventana) | ✔ | ✔ |
| `HAVING` | | | ✔ |
| Subconsulta | | | ✔ |
| Función de ventana (`OVER`) | ✔ | | |
| `ORDER BY` | ✔ | | ✔ |

---

## 6. Reglas de negocio que respaldan las consultas

| Regla | Dónde se refleja |
|---|---|
| **Historial de precios:** el precio unitario se registra en el detalle de cada venta para evitar cambios retroactivos. | CU-01 y CU-02 calculan los importes con `VENTA_DETALLE.precio_unitario` y `subtotal`, no con `PRODUCTO.precio`. |
| **Las ventas canceladas no representan ingresos.** | CU-02 las excluye con `estado <> 'Cancelado'`. |
| **Solo las ventas entregadas se consideran gasto efectivo del cliente.** | CU-03 filtra con `estado = 'Entregado'`. |
| **Cada venta pertenece a un único cliente registrado.** | CU-01 y CU-03 vinculan `VENTA` con `USUARIO`. |

---

## 7. Orden de ejecución y datos de prueba

1. Ejecutar `sql/ddl/crear_bd.sql` para crear la estructura.
2. Ejecutar `sql/dml/datos_prueba.sql` para cargar los datos de prueba.
3. Aplicar la actualización de fechas de la tabla `VENTA` (documentada en `informe-ventas.md`, sección 1), necesaria para que el rango de fechas de CU-02 tenga sentido. Conviene incluirla en `datos_prueba.sql`.
4. Ejecutar los scripts de `sql/consultas/` (en cualquier orden):
   - `comprobante_venta.sql`
   - `informe_ventas.sql`
   - `consulta_avanzada.sql`

### Estado de las ventas de prueba

Los resultados de las tres consultas dependen de los estados cargados en el script de datos:

| Estado | Ventas |
|---|---|
| Entregado | 1, 2, 4, 6, 7 y 9 |
| Pendiente | 3, 8 y 10 |
| Cancelado | 5 |

Si se modifica el estado de alguna venta, cambian los resultados de CU-02 y CU-03.

---

## 8. Observaciones

- **Fechas de las ventas:** `VENTA.fecha_venta` toma por defecto `GETDATE()`, por lo que sin la actualización de fechas todas las ventas tendrían la fecha de carga del script. Con la actualización aplicada, la venta 1 (CU-01) figura con fecha `2026-09-10`.
- **Alcance de la comparación en CU-03:** el promedio utilizado es por **venta**, no por cliente. Con clientes de una sola compra ambos criterios coinciden, pero un cliente con varias compras quedaría favorecido en la comparación.
- **Categorías sin movimiento:** al usar `INNER JOIN`, CU-02 no muestra las categorías sin ventas en el período (por ejemplo, Gabinetes).
- **Reutilización:** las tres consultas pueden convertirse en procedimientos o funciones almacenadas con parámetros (`@id_venta`, `@desde`, `@hasta`), lo que se desarrolla en la Etapa V.
