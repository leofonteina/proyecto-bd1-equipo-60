<p align="center">
<img src="https://images.seeklogo.com/logo-png/29/1/universidad-nacional-del-nordeste-logo-png_seeklogo-293999.png" width="150" height="150" alt="Logo UNNE">
</p>

[![Build Status](https://img.shields.io/badge/build-experimental-yellow)]() [![SQL](https://img.shields.io/badge/SQL-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)]()

# Proyecto BD1

## Integrantes

| Apellido y Nombre | DNI | Perfil de Github |
|---|---|---|
| Fonteina Leonardo | 46.602.160 | [Fonteina Leonardo](https://github.com/leofonteina) |
| Acuña Bruno | 95.764.841 | [Acuña Bruno](https://github.com/ThKo55) |
| Acuña Alejo | 46.512.761 | [Acuña Alejo](https://github.com/alejoacuna754-ui) |
| Gomez Agustín | 46.512.743 | [Gomez Agustín](https://github.com/agustinrgomezz) |
| García María Belén | 36.960.260 | [García María Belén](https://github.com/belengarcia918) |

## Sobre el proyecto

Base de datos para el sistema de ventas de una página web con diferentes productos de computación: hardware, accesorios, periféricos, etc.

Todo el código está hecho en lenguaje SQL (T-SQL) con la interfaz de SQL Server Management Studio 22, con diferentes tablas que organizan los datos hasta la Tercera Forma Normal (3FN), para obtener así una mejor consistencia de los datos y evitar dolores de cabeza futuros.

## Tabla de contenidos

- [Etapa 1](#etapa-1)
- [Etapa 2](#etapa-2)
- [Etapa 3](#etapa-3)
- [Etapa 4](#etapa-4)
- [Etapa 5](#etapa-5)
- [Estructura del proyecto](#estructura-del-proyecto)

---

## Etapa 1

**Requerimientos y dominio del negocio.** Qué problema resuelve el sistema, cuál es su alcance, quiénes lo usan y qué reglas rigen las operaciones.

| Documento | Contenido |
|---|---|
| [Descripción del caso](docs/etapa-01/descripcion-caso.md) | Introducción al rubro elegido y al sistema. |
| [Alcance](docs/etapa-01/alcance.md) | Qué incluye y qué no incluye el sistema. |
| [Reglas de negocio](docs/etapa-01/reglas-negocio.md) | Reglas que rigen stock, clientes, precios y métodos de pago. |
| [Decisiones de diseño](docs/etapa-01/decisiones-diseno.md) | Justificación de las decisiones tomadas. |

[⬆ Volver al índice](#tabla-de-contenidos)

---

## Etapa 2

**Modelado conceptual y lógico.** Cómo se pasó del dominio al Diagrama Entidad-Relación (DER), del DER al modelo relacional y cómo se justificó la normalización.

| Documento | Contenido |
|---|---|
| [Diagrama Entidad-Relación](docs/etapa-02/der/Modelo_Conceptual_DER.png) | DER en notación de Chen. |
| [Modelo relacional](docs/etapa-02/der/Modelo_Relacional_DER.jpg) | Tablas con claves primarias y foráneas. |
| [Normalización](docs/etapa-02/normalizacion.md) | Evolución del modelo: 1FN, 2FN y 3FN. |
| [Decisiones de diseño](docs/etapa-02/decisiones.md) | Justificación de las decisiones de modelado. |

[⬆ Volver al índice](#tabla-de-contenidos)

---

## Etapa 3

**Implementación física.** Cómo el modelo lógico se llevó al motor de base de datos (SQL Server) y cómo se verificaron las restricciones, los datos y la integridad.

| Documento | Contenido |
|---|---|
| [Implementación](docs/etapa-03/implementacion.md) | Pasos para llevar el modelo al motor. |
| [Restricciones de integridad](docs/etapa-03/restricciones-integridad.md) | `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK` y `NOT NULL`. |
| [Pruebas y validación](docs/etapa-03/pruebas-validacion.md) | Verificación de datos e integridad. |

| Script | Descripción |
|---|---|
| [`crear_bd.sql`](sql/ddl/crear_bd.sql) | DDL: creación de las 13 tablas y sus restricciones. |
| [`datos_prueba.sql`](sql/dml/datos_prueba.sql) | DML: carga de datos de prueba. |

**Orden de ejecución:** primero `crear_bd.sql` y después `datos_prueba.sql`.

[⬆ Volver al índice](#tabla-de-contenidos)

---

## Etapa 4

**Consultas y casos de uso.** Qué necesidad de información resuelve cada consulta, qué estrategia SQL utiliza y qué resultado se espera. Índice general de la etapa: [Casos de uso](docs/etapa-04/caso-uso.md).

| Caso de uso | Descripción | Documento | Script |
|---|---|---|---|
| **CU-01** Comprobante de venta | Encabezado y detalle de una venta, con subtotales por renglón y total acumulado. | [comprobante-venta.md](docs/etapa-04/comprobante-venta.md) | [`comprobante_ventas.sql`](sql/consultas/comprobante_ventas.sql) |
| **CU-02** Informe de ventas por categoría | Ventas, unidades y monto por categoría en un rango de fechas (`GROUP BY`, `SUM`, `COUNT`). | [informe-ventas.md](docs/etapa-04/informe-ventas.md) | [`informe_ventas.sql`](sql/consultas/informe_venta.sql) |
| **CU-03** Clientes de mayor valor | Clientes cuyo gasto supera el promedio (5 tablas, `HAVING` y subconsulta). | [consulta-avanzada.md](docs/etapa-04/consulta.avanzada.md) | [`consulta_avanzada.sql`](sql/consultas/consulta_avanzada.sql) |

[⬆ Volver al índice](#tabla-de-contenidos)

---

## Etapa 5

`⚠ EN CONSTRUCCION ⚠`

## Estructura del proyecto

```
proyecto-bd1-equipo-60/
│
├── docs/
│   ├── etapa-01/
│   │   ├── descripcion-caso.md
│   │   ├── alcance.md
│   │   ├── reglas-negocio.md
│   │   └── decisiones-diseno.md
│   │
│   ├── etapa-02/
│   │   ├── der/
│   │   │   └── der.png
│   │   ├── modelo-relacional.md
│   │   ├── normalizacion.md
│   │   └── decisiones-diseno.md
│   │
│   ├── etapa-03/
│   │   ├── implementacion.md
│   │   ├── restricciones-integridad.md
│   │   └── pruebas-validacion.md
│   │
│   ├── etapa-04/
│   │   ├── casos-uso.md
│   │   ├── comprobante-venta.md
│   │   ├── informe-ventas.md
│   │   └── consulta-avanzada.md
│   │
│   └── etapa-05/
│       ├── procedimientos-funciones.md
│       ├── transacciones.md
│       ├── triggers-auditoria.md
│       ├── seguridad.md
│       └── indices-optimizacion.md
│
├── sql/
│   ├── ddl/
│   │   └── crear_bd.sql
│   ├── dml/
│   │   └── datos_prueba.sql
│   ├── consultas/
│   │   ├── comprobante_venta.sql
│   │   ├── informe_ventas.sql
│   │   └── consulta_avanzada.sql
│   └── tecnico/
│       ├── procedimientos/
│       ├── funciones/
│       ├── transacciones/
│       ├── triggers/
│       ├── seguridad/
│       └── indices/
│
└── README.md
```

| Carpeta | Contenido |
|---|---|
| [`docs`](docs) | Documentación de cada etapa en archivos `.md`. |
| [`sql/ddl`](sql/ddl) | Scripts de construcción de la estructura. |
| [`sql/dml`](sql/dml) | Scripts de inserción y actualización de datos. |
| [`sql/consultas`](sql/consultas) | Scripts de recuperación y análisis de información. |
| [`sql/tecnico`](sql/tecnico) | Scripts de mecanismos avanzados del motor. |

[⬆ Volver al índice](#tabla-de-contenidos)
