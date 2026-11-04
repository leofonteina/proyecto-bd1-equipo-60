# Etapa V – Optimización de consultas mediante índices

## 1. Definición y objetivo

### ¿Qué es un índice?

Un **índice** es una estructura que SQL Server mantiene aparte de los datos para localizarlos sin recorrer toda la tabla. Funciona como el índice de un libro: en lugar de leer todas las páginas para encontrar un tema, se consulta el índice y se va directo a la página correcta.

Sin un índice adecuado, el motor debe leer **todas** las filas de la tabla (*scan*) para encontrar las que cumplen un filtro. Con muchos registros, esto genera tiempos de respuesta altos y muchas lecturas de disco.

### Tipos de estructuras

| Tipo | Descripción | Cantidad por tabla |
|---|---|---|
| **Heap** | Tabla sin índice agrupado: las filas se guardan sin orden en particular. | – |
| **Índice agrupado** (*clustered*) | Define el orden físico de las filas: las hojas del índice **son** la tabla. | Solo 1 |
| **Índice no agrupado** (*nonclustered*) | Estructura separada ordenada por la clave, con un puntero a la fila. | Muchos |
| **Índice con cobertura** (`INCLUDE`) | Índice no agrupado que además guarda otras columnas en sus hojas, de modo que resuelve la consulta sin leer la tabla. | Muchos |

Las claves primarias (`PRIMARY KEY`) y las restricciones `UNIQUE` generan un índice automáticamente. Las claves foráneas (`FOREIGN KEY`), **no**.

### Operadores del plan de ejecución

| Operador | Significado | Costo |
|---|---|---|
| **Table Scan** | Lee todas las filas de un heap. | Alto |
| **Clustered Index Scan** | Lee todas las filas de una tabla con índice agrupado. | Alto |
| **Clustered Index Seek** | Se posiciona en el rango buscado dentro del índice agrupado. | Bajo |
| **Index Seek** | Se posiciona en el rango buscado dentro de un índice no agrupado. | Bajo |
| **Key / RID Lookup** | Por cada fila encontrada en el índice, va a la tabla a buscar las columnas faltantes. | Crece con la cantidad de filas |

### Objetivo en este proyecto

Medir el impacto de los índices sobre una consulta de **búsqueda por período** (el mismo tipo de filtro que usa el informe de ventas de la Etapa IV), comparando tres escenarios sobre una tabla de **1.000.000 de registros**: sin índice, con índice agrupado sobre la fecha y con un índice con cobertura.

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aprecia en el sistema |
|---|---|
| **Menor tiempo de respuesta** en las búsquedas. | Los informes por rango de fechas se resuelven sin recorrer todas las ventas. |
| **Menos lecturas** del motor. | El plan de ejecución cambia de un recorrido completo (*scan*) a una búsqueda dirigida (*seek*). |
| **Mejores uniones (`JOIN`).** | Los índices sobre claves foráneas aceleran las uniones entre ventas, detalle y productos. |
| **Escalabilidad.** | El sistema sigue respondiendo bien cuando el historial de ventas crece. |

**Aplicaciones habituales:** filtros por fechas o por períodos, búsquedas por código o por cliente, uniones entre tablas por claves foráneas y ordenamientos o agrupaciones frecuentes.

**Costos a tener en cuenta:**

- **Espacio:** cada índice ocupa espacio adicional en disco.
- **Escrituras más lentas:** cada `INSERT`, `UPDATE` o `DELETE` debe mantener actualizados los índices.
- **No conviene indexar todo:** se indexan las columnas usadas con frecuencia en filtros, uniones y ordenamientos.

---

## 3. Implementación en SQL Server

Scripts asociados:

| Script | Contenido |
|---|---|
| [`sql/tecnico/indices/implementacion_indices.sql`](../../sql/tecnico/indices/implentacion_indices.sql) | Tabla de pruebas y carga masiva de 1.000.000 de registros. |
| [`sql/tecnico/indices/demostracion_indices.sql`](../../sql/tecnico/indices/demostracion_indices.sql) | Los tres escenarios de medición. |

### 3.1 Tabla de pruebas `VENTA_HISTORICA`

Es una copia de la estructura de `VENTA`, **sin clave primaria ni índices** (un *heap*):

```sql
CREATE TABLE VENTA_HISTORICA
(
  id_venta           INT IDENTITY(1,1) NOT NULL,
  estado             VARCHAR(50)   NOT NULL,
  domicilio_entrega  VARCHAR(150)  NOT NULL,
  total              DECIMAL(10,2) NOT NULL,
  fecha_venta        DATETIME      NOT NULL,
  id_usuario         INT           NOT NULL
);
```

### 3.2 Carga masiva de 1.000.000 de registros

```sql
WITH numeros AS
(
    SELECT TOP (1000000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO VENTA_HISTORICA (estado, domicilio_entrega, total, fecha_venta, id_usuario)
SELECT CASE n % 3 WHEN 0 THEN 'Pendiente'
                  WHEN 1 THEN 'Entregado'
                  ELSE        'Cancelado' END,
       'Domicilio de prueba ' + CAST(n AS VARCHAR(10)),
       CAST((ABS(CHECKSUM(NEWID())) % 1000000) / 100.0 + 1 AS DECIMAL(10,2)),
       DATEADD(SECOND, ABS(CHECKSUM(NEWID())) % 86400,
               DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1826, CAST('2020-01-01' AS DATETIME))),
       (n % 10) + 1
FROM numeros;
```

### 3.3 Consulta utilizada en las pruebas

```sql
SELECT id_venta, fecha_venta, total
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
```

Busca las ventas del primer trimestre de 2023. El rango se define con `>=` y `<` (el día siguiente al final) en lugar de `BETWEEN`, para incluir todas las ventas del último día aunque tengan hora.

### 3.4 Índices del experimento

**Índice agrupado sobre la fecha**

```sql
CREATE CLUSTERED INDEX IX_VentaHistorica_Fecha
ON VENTA_HISTORICA (fecha_venta);
```

Ordena físicamente la tabla por `fecha_venta`.

**Índice con cobertura (columnas incluidas)**

```sql
CREATE NONCLUSTERED INDEX IX_VentaHistorica_Fecha_Cobertura
ON VENTA_HISTORICA (fecha_venta)
INCLUDE (id_venta, total);
```

La clave es `fecha_venta` y las hojas guardan además `id_venta` y `total`, que son las otras columnas de la consulta. Así el índice contiene **todo lo que la consulta necesita** y no hace falta leer la tabla.

**Eliminación del índice agrupado**

```sql
DROP INDEX IX_VentaHistorica_Fecha ON VENTA_HISTORICA;
```

La tabla vuelve a ser un heap antes de crear el índice del escenario 3, de modo que cada escenario parte de una base comparable.

---

## 4. Caso concreto aplicado al sistema de ventas

El informe de ventas por categoría (Etapa IV, `informe_venta.sql`) filtra las ventas por un **rango de fechas** y por estado:

```sql
WHERE v.fecha_venta BETWEEN '2026-09-10' AND '2026-10-12' AND v.estado <> 'Cancelado'
```

Con las 10 ventas de prueba esto es instantáneo, pero en un negocio real `VENTA` acumula miles de registros por mes y esa consulta se ejecuta con cada reporte. La columna `fecha_venta` es el candidato natural a indexar, y es la que se usa en la prueba.

Como con 10 filas el motor siempre prefiere leer la tabla completa (no se nota ninguna diferencia), la demostración se hace sobre `VENTA_HISTORICA`, que replica la estructura de `VENTA` con un volumen realista de 1.000.000 de registros.

---

## 5. Demostración y resultados

Script completo: [`demostracion_indices.sql`](../../sql/tecnico/indices/demostracion_indices.sql).

### 5.0 Preparación del entorno

En SQL Server Management Studio:

1. Activar el plan de ejecución real: `Ctrl + M`.
2. Activar *Query > Query Options > Results > Grid > Discard results after execution*, para que el tiempo medido no incluya el dibujo de unas 49.000 filas en pantalla.
3. Activar las estadísticas de tiempo y lecturas:

```sql
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
```

Antes de cada escenario se vacía la caché de datos para medir en las mismas condiciones (solo en entorno de pruebas):

```sql
CHECKPOINT;
DBCC DROPCLEANBUFFERS;
```

### 5.1 Verificación de la carga y estado inicial

```sql
SELECT COUNT(*)         AS cantidad_registros,
       MIN(fecha_venta) AS fecha_minima,
       MAX(fecha_venta) AS fecha_maxima
FROM VENTA_HISTORICA;

SELECT ISNULL(i.name, '(sin nombre)') AS indice, i.type_desc AS tipo
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('VENTA_HISTORICA');
```

**Resultado esperado:** 1.000.000 de registros con fechas entre 2020 y 2024, y una única estructura de tipo `HEAP` (sin índices).


Luego se consulta cuántas filas devuelve el filtro del período (aproximadamente el 5 % de la tabla):

```sql
SELECT COUNT(*) AS filas_del_periodo
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
```

Como referencia, esta consulta sobre la tabla sin índices debe recorrerla completa: se registraron **9.328 lecturas lógicas**, con **188 ms de CPU** y **587 ms de tiempo total**.

### 5.2 Escenario 1 – Sin índice

```sql
SELECT id_venta, fecha_venta, total
FROM VENTA_HISTORICA
WHERE fecha_venta >= '2023-01-01' AND fecha_venta < '2023-04-01';
```

**Plan esperado:** `Table Scan`.

**Resultado obtenido (pestaña Mensajes: lecturas lógicas, CPU y tiempo total):**

> <img width="559" height="220" alt="MENSAJE_ESCENARIO_1" src="https://github.com/user-attachments/assets/7c37594c-e4fa-4752-b960-2ee43284ca03" />


**Plan de ejecución obtenido:**

> <img width="529" height="139" alt="PLAN_ESCENARIO_1" src="https://github.com/user-attachments/assets/36ef76c1-bd66-4802-aeda-a0bb9df33901" />



### 5.3 Escenario 2 – Índice agrupado sobre la fecha

```sql
CREATE CLUSTERED INDEX IX_VentaHistorica_Fecha
ON VENTA_HISTORICA (fecha_venta);
```

Se repite la misma consulta.

**Plan esperado:** `Clustered Index Seek`.

**Resultado obtenido (pestaña Mensajes: lecturas lógicas, CPU y tiempo total):**

> <img width="536" height="191" alt="MENSAJE_ESCENARIO_2" src="https://github.com/user-attachments/assets/abc202f4-adc7-4815-9a2c-5db331e5024b" />


**Plan de ejecución obtenido:**

> <img width="730" height="137" alt="PLAN_ESCENARIO_2" src="https://github.com/user-attachments/assets/2d38e3a3-f606-460d-9ec0-8a54727f2906" />



Luego se elimina el índice para que la tabla vuelva a ser un heap:

```sql
DROP INDEX IX_VentaHistorica_Fecha ON VENTA_HISTORICA;
```

### 5.4 Escenario 3 – Índice con cobertura

```sql
CREATE NONCLUSTERED INDEX IX_VentaHistorica_Fecha_Cobertura
ON VENTA_HISTORICA (fecha_venta)
INCLUDE (id_venta, total);
```

Se repite la misma consulta.

**Plan esperado:** `Index Seek` sobre el índice con cobertura, sin `Key Lookup` ni acceso a la tabla.

**Resultado obtenido (pestaña Mensajes: lecturas lógicas, CPU y tiempo total):**

> <img width="538" height="181" alt="MENSAJE_ESCENARIO_3" src="https://github.com/user-attachments/assets/c37d238e-f329-495d-959f-23a98e6ca6c0" />



**Plan de ejecución obtenido:**

> <img width="745" height="137" alt="PLAN_ESCENARIO_3" src="https://github.com/user-attachments/assets/07a5bb9d-8c94-4733-a868-a95fa1bf79ef" />

---

## 6. Conclusiones

1. **Sin índice, el motor recorre toda la tabla.** El plan fue un `Table Scan`: para devolver las ventas de un trimestre tuvo que leer todos los registros, aunque solo una pequeña parte cumplía el filtro. Fue el escenario con más trabajo.

2. **El índice agrupado hizo la consulta más rápida** porque ordena la tabla por `fecha_venta`. El motor pasó a un `Clustered Index Seek` y leyó únicamente el rango de fechas buscado, sin recorrer el resto.

3. **El índice con cobertura fue el más eficiente.** Como contiene todas las columnas que pide la consulta, el motor la resolvió usando solo el índice, sin acceder a la tabla, y con filas más angostas que las de la tabla completa.

4. **Los planes de ejecución confirman el cambio de estrategia:** se pasó de un recorrido completo (`Table Scan`) a búsquedas dirigidas (`Seek`), que es lo que explica la mejora.

5. **Los índices tienen un costo.** Ocupan espacio adicional y deben actualizarse en cada `INSERT`, `UPDATE` o `DELETE`, por lo que conviene crearlos solo sobre las columnas usadas con frecuencia en filtros y uniones.

6. **Aplicación al sistema:** el informe de ventas filtra por `fecha_venta`; al crecer el historial, un índice sobre esa columna evitaría recorrer todas las ventas en cada reporte.
