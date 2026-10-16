# Consulta: clientes con gasto superior al promedio

## 1. ¿Qué hace la consulta?

Muestra **los clientes cuyo gasto total en ventas entregadas es mayor al promedio de todas las ventas entregadas**. Por cada cliente devuelve:

| Columna | Significado |
|---|---|
| `nombre`, `apellido` | Datos del cliente |
| `provincia` | Provincia de su dirección registrada |
| `cantidad_compras` | Cuántas ventas entregadas tiene |
| `gasto_total` | Suma del total de esas ventas |

Resultado ordenado de mayor a menor gasto.

---

## 2. La consulta

```sql
SELECT 
    u.nombre, 
    u.apellido, 
    p.nomb_prov AS provincia,
    COUNT(v.id_venta) AS cantidad_compras,
    SUM(v.total) AS gasto_total
FROM USUARIO u
INNER JOIN DIRECCION d ON u.id_direccion = d.id_direccion
INNER JOIN CIUDAD c ON d.id_ciudad = c.id_ciudad
INNER JOIN PROVINCIA p ON c.id_provincia = p.id_provincia
INNER JOIN VENTA v ON u.id_usuario = v.id_usuario
WHERE v.estado = 'Entregado'
GROUP BY u.id_usuario, u.nombre, u.apellido, p.nomb_prov
HAVING SUM(v.total) > (
    SELECT AVG(total) 
    FROM VENTA 
    WHERE estado = 'Entregado'
)
ORDER BY gasto_total DESC;
```

---

## 3. Funciones y cláusulas utilizadas

### `INNER JOIN`
Une tablas y **solo conserva las filas que tienen coincidencia en ambas**. Se encadenan 4 para recorrer este camino:

```
USUARIO → DIRECCION → CIUDAD → PROVINCIA
USUARIO → VENTA
```

Así se llega desde el usuario hasta el nombre de su provincia y hasta sus ventas. Un usuario sin ventas queda fuera.

### `WHERE v.estado = 'Entregado'`
Filtra **fila por fila, antes de agrupar**. Solo pasan las ventas entregadas; las `Pendiente` y `Cancelado` se descartan.

### `COUNT(v.id_venta)`
Función de agregación: **cuenta** cuántas ventas tiene cada grupo (cada cliente).

### `SUM(v.total)`
Función de agregación: **suma** el campo `total` de las ventas de cada cliente.

### `GROUP BY`
Agrupa las filas para que `COUNT` y `SUM` se calculen **por cliente**. Todas las columnas del `SELECT` que no son agregaciones deben estar acá (`nombre`, `apellido`, `provincia`). Se incluye `id_usuario` para distinguir a dos clientes con el mismo nombre.

### `HAVING`
Filtra **después de agrupar**, usando resultados de agregaciones. Es la diferencia clave con `WHERE`:

| | `WHERE` | `HAVING` |
|---|---|---|
| Cuándo actúa | Antes de agrupar | Después de agrupar |
| Filtra | Filas individuales | Grupos completos |
| Puede usar `SUM`, `COUNT` | No | Sí |

### Subconsulta con `AVG`
```sql
SELECT AVG(total) FROM VENTA WHERE estado = 'Entregado'
```
Calcula el **promedio del total de las ventas entregadas**. Se ejecuta primero y devuelve un único número, que el `HAVING` usa para comparar.

### `ORDER BY gasto_total DESC`
Ordena el resultado de **mayor a menor** gasto.

### Alias (`AS`)
`AS provincia`, `AS cantidad_compras`, `AS gasto_total` renombran las columnas del resultado. `u`, `d`, `c`, `p`, `v` son alias de tablas para escribir menos.

---

## 4. Funcionamiento paso a paso (con tus datos de prueba)

### Paso 1 – `WHERE`: ventas entregadas
Después de los `UPDATE`, las ventas `Entregado` son la 1, 2, 4, 6, 7 y 9.

| id_venta | id_usuario | Cliente | total |
|---|---|---|---|
| 1 | 2 | Laura Perez | 530.000,00 |
| 2 | 3 | Carlos Lopez | 560.000,00 |
| 4 | 5 | Jorge Ruiz | 260.000,00 |
| 6 | 7 | Diego Silva | 280.000,00 |
| 7 | 8 | Sofia Luna | 820.000,00 |
| 9 | 10 | Lucia Cruz | 110.000,00 |

> La venta 5 está `Cancelado`; las ventas 3, 8 y 10 siguen `Pendiente`. Por eso Laura Perez (que tiene las ventas 1 y 10) solo cuenta **1** compra.

### Paso 2 – Subconsulta: promedio

```
AVG = (530.000 + 560.000 + 260.000 + 280.000 + 820.000 + 110.000) / 6
    = 2.560.000 / 6
    ≈ 426.666,67
```

### Paso 3 – `GROUP BY` + `HAVING`: comparar cada cliente con el promedio

| Cliente | gasto_total | ¿> 426.666,67? | Resultado |
|---|---|---|---|
| Laura Perez | 530.000,00 | Sí | ✅ Aparece |
| Carlos Lopez | 560.000,00 | Sí | ✅ Aparece |
| Jorge Ruiz | 260.000,00 | No | ❌ Excluido |
| Diego Silva | 280.000,00 | No | ❌ Excluido |
| Sofia Luna | 820.000,00 | Sí | ✅ Aparece |
| Lucia Cruz | 110.000,00 | No | ❌ Excluido |

### Paso 4 – Provincia de cada cliente (por los `JOIN`)

| Cliente | Dirección | Ciudad | Provincia |
|---|---|---|---|
| Laura Perez | Belgrano 456 | Cordoba Capital | Córdoba |
| Carlos Lopez | Sarmiento 789 | Rosario | Santa Fe |
| Sofia Luna | Junín 505 | Corrientes Capital | Corrientes |

---

## 5. Resultado esperado al ejecutar

| nombre | apellido | provincia | cantidad_compras | gasto_total |
|---|---|---|---|---|
| Sofia | Luna | Corrientes | 1 | 820000.00 |
| Carlos | Lopez | Santa Fe | 1 | 560000.00 |
| Laura | Perez | Córdoba | 1 | 530000.00 |

Ordenado por `gasto_total` de forma descendente (`DESC`).

---

## 6. Resumen en una frase

> Une usuario + dirección + ciudad + provincia + ventas, se queda solo con ventas entregadas, suma y cuenta por cliente, y muestra únicamente a quienes gastaron más que el promedio de venta entregada.

## 7. Observaciones

- El promedio compara **el gasto total de un cliente** contra **el promedio por venta**, no contra el promedio de gasto por cliente. Con clientes de una sola compra da lo mismo, pero si alguien tuviera varias compras, quedaría favorecido.
- Si cambiás los estados de las ventas (por ejemplo, entregás la venta 10), el promedio y el resultado cambian.
