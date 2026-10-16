# Informe de Ventas por Categoría (Reporte Agregado)

El presente documento detalla la implementación, ejecución y validación del reporte agregado de ventas por categoría de producto, aplicando funciones de agregación (`COUNT`, `SUM`), agrupación (`GROUP BY`) y filtrado por rango de fechas y estados válidos.

---

## 1. Preparación de Datos (Actualización de Fechas)

Para garantizar la representatividad de la prueba dentro del período evaluado (`2026-09-10` al `2026-10-12`), se aplicaron las siguientes actualizaciones sobre el lote de datos de prueba en la tabla `VENTA`:

```sql
-- Fechas actualizadas para el funcionamiento de Reporte Agregado
UPDATE VENTA SET fecha_venta = '2026-09-10' WHERE id_venta IN (1, 2);
UPDATE VENTA SET fecha_venta = '2026-09-25' WHERE id_venta IN (3, 4, 5);
UPDATE VENTA SET fecha_venta = '2026-10-05' WHERE id_venta IN (6, 7);
UPDATE VENTA SET fecha_venta = '2026-10-12' WHERE id_venta IN (8, 9, 10);
```

---

## 2. Consulta SQL Implementada

La consulta vincula las tablas `VENTA`, `VENTA_DETALLE`, `PRODUCTO` y `CATEGORIA` mediante `INNER JOIN`, excluyendo las operaciones anuladas (`estado <> 'Cancelado'`) y contabilizando las ventas únicas, el volumen de unidades y la recaudación total por rubro:

```sql
SELECT 
    c.descripcion AS Categoria, 
    COUNT(DISTINCT v.id_venta) AS Ventas, 
    SUM(vd.cantidad) AS Unidades, 
    SUM(vd.subtotal) AS Total
FROM Venta v
JOIN venta_detalle vd ON vd.id_venta = v.id_venta 
JOIN producto p ON vd.id_producto = p.id_producto
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE v.fecha_venta BETWEEN '2026-09-10' AND '2026-10-12' 
  AND v.estado <> 'Cancelado'
GROUP BY c.descripcion;
```

---

## 3. Resultado Esperado de la Ejecución

Al ejecutar la sentencia sobre el lote de datos (DML), el motor de base de datos devuelve la siguiente tabla de resultados consolidada:

| Categoria | Ventas | Unidades | Total |
| :--- | :---: | :---: | ---: |
| **Almacenamiento SSD** | 1 | 1 | 90000.00 |
| **Fuentes de Poder** | 1 | 1 | 110000.00 |
| **Memoria RAM** | 1 | 1 | 65000.00 |
| **Monitores** | 1 | 1 | 280000.00 |
| **Motherboards** | 1 | 1 | 180000.00 |
| **Placas de Video** | 1 | 1 | 450000.00 |
| **Procesadores** | 2 | 2 | 450000.00 |
| **Teclados** | 1 | 1 | 45000.00 |

> **Resumen Global del Período:** **9** ventas efectivas procesadas | **9** unidades vendidas | **$1,670,000.00** recaudados.

---

## 4. Trazabilidad y Validación del Comportamiento

El siguiente cuadro demuestra cómo el motor de base de datos evalúa cada registro cargado en el DML para construir el reporte final:

| ID Venta | Fecha Actualizada | Estado | Producto Vendido | Categoría | Subtotal | ¿Se incluye en el reporte? |
| :---: | :---: | :---: | :--- | :--- | ---: | :--- |
| **1** | `2026-09-10` | Entregado | Ryzen 5 5600 | Procesadores | $220,000.00 | **Sí** *(Suma 1ª venta a Procesadores)* |
| **2** | `2026-09-10` | Enviado | RTX 3060 12GB | Placas de Video | $450,000.00 | **Sí** |
| **3** | `2026-09-25` | Pendiente | Vengeance 16GB | Memoria RAM | $65,000.00 | **Sí** |
| **4** | `2026-09-25` | Entregado | SSD 1TB NVMe | Almacenamiento SSD | $90,000.00 | **Sí** |
| **5** | `2026-09-25` | Cancelado | Mouse G203 | Mouse | $35,000.00 | **No** *(Filtrado por `estado <> 'Cancelado'`)* |
| **6** | `2026-10-05` | Enviado | Monitor 24 144Hz | Monitores | $280,000.00 | **Sí** |
| **7** | `2026-10-05` | Entregado | B550 Tomahawk | Motherboards | $180,000.00 | **Sí** |
| **8** | `2026-10-12` | Pendiente | Teclado Kumara | Teclados | $45,000.00 | **Sí** |
| **9** | `2026-10-12` | Entregado | Fuente 650W 80+ | Fuentes de Poder | $110,000.00 | **Sí** |
| **10** | `2026-10-12` | Enviado | Core i5 12400F | Procesadores | $230,000.00 | **Sí** *(Suma 2ª venta a Procesadores)* |

### Observaciones de Integridad en los Datos:
* **Agrupación en `Procesadores`:** Es la única categoría que consolida dos operaciones distintas (`id_venta = 1` por $220,000.00 e `id_venta = 10` por $230,000.00), reflejando **2 ventas**, **2 unidades** y un total de **$450,000.00**.
* **Exclusión de la categoría `Mouse`:** Su única operación registrada (`id_venta = 5`) se encuentra en estado `Cancelado`, por lo que la cláusula `WHERE` la descarta antes de agrupar.
* **Exclusión de la categoría `Gabinetes`:** Al utilizar cláusulas `INNER JOIN`, las categorías que no registran productos con ventas asociadas en el período quedan fuera del listado.
