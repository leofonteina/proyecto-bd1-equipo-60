-- =====================================================================
-- Etapa V - Triggers de auditoría
-- Script de implementación
--
-- Crea:
--   * AUDITORIA_VENTA              : historial de UPDATE y DELETE sobre VENTA
--   * AUDITORIA_INTENTOS_BORRADO   : intentos de DELETE bloqueados
--   * t_update_venta               : trigger AFTER UPDATE sobre VENTA
--   * t_delete_venta               : trigger AFTER DELETE sobre VENTA
--   * t_bloquear_delete_producto   : trigger INSTEAD OF DELETE sobre PRODUCTO
--
-- IMPORTANTE:
--   * Ejecutar con la base de datos del proyecto seleccionada.
--   * El script es re-ejecutable: elimina los objetos de versiones
--     anteriores y los vuelve a crear. Se pierde el historial que
--     tuvieran las tablas de auditoría.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Limpieza de versiones anteriores
--    (evita que triggers viejos sigan activos y escriban en tablas
--     con otra estructura)
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS dbo.t_update;
DROP TRIGGER IF EXISTS dbo.t_delete;
DROP TRIGGER IF EXISTS dbo.trg_bloquear_delete_producto;
DROP TRIGGER IF EXISTS dbo.t_update_venta;
DROP TRIGGER IF EXISTS dbo.t_delete_venta;
DROP TRIGGER IF EXISTS dbo.t_bloquear_delete_producto;
GO

DROP TABLE IF EXISTS AUDITORIA_VENTA;
DROP TABLE IF EXISTS AUDITORIA_INTENTOS_BORRADO;
GO

-- ---------------------------------------------------------------------
-- 1. Tablas auxiliares de auditoría
-- ---------------------------------------------------------------------
CREATE TABLE AUDITORIA_VENTA
(
  id_auditoria                   INT IDENTITY NOT NULL,
  accion                         VARCHAR(60)   NOT NULL,
  id_venta                       INT           NOT NULL,

  -- valores ANTES de la operación (tabla deleted)
  estado_anterior                VARCHAR(50)   NULL,
  domicilio_anterior             VARCHAR(150)  NULL,
  total_anterior                 DECIMAL(10,2) NULL,
  fecha_venta_anterior           DATETIME      NULL,
  id_usuario_vendedor_anterior   INT           NULL,

  -- valores DESPUÉS de la operación (tabla inserted); NULL en un DELETE
  estado_nuevo                   VARCHAR(50)   NULL,
  domicilio_nuevo                VARCHAR(150)  NULL,
  total_nuevo                    DECIMAL(10,2) NULL,
  fecha_venta_nueva              DATETIME      NULL,
  id_usuario_vendedor_nuevo      INT           NULL,

  -- datos de la auditoría
  fecha_modificacion             DATETIME      NOT NULL DEFAULT (GETDATE()),
  usuario_bd                     VARCHAR(100)  NOT NULL DEFAULT (SUSER_SNAME()),

  CONSTRAINT PK_AUDITORIA_VENTA PRIMARY KEY (id_auditoria)
);
GO

CREATE TABLE AUDITORIA_INTENTOS_BORRADO
(
  id_intento   INT IDENTITY NOT NULL,
  tabla        VARCHAR(50)  NOT NULL,
  accion       VARCHAR(60)  NOT NULL,
  id_registro  INT          NOT NULL,
  fecha        DATETIME     NOT NULL DEFAULT (GETDATE()),
  usuario_bd   VARCHAR(100) NOT NULL DEFAULT (SUSER_SNAME()),
  CONSTRAINT PK_AUDITORIA_INTENTOS_BORRADO PRIMARY KEY (id_intento)
);
GO

-- ---------------------------------------------------------------------
-- 2. Trigger de auditoría para UPDATE sobre VENTA
--    Registra una fila por cada venta que cambió algún valor.
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER t_update_venta
ON VENTA
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_VENTA
        (accion, id_venta,
         estado_anterior, estado_nuevo,
         domicilio_anterior, domicilio_nuevo,
         total_anterior, total_nuevo,
         fecha_venta_anterior, fecha_venta_nueva,
         id_usuario_vendedor_anterior, id_usuario_vendedor_nuevo)
    SELECT 'UPDATE en la tabla VENTA', d.id_venta,
           d.estado,            i.estado,
           d.domicilio_entrega, i.domicilio_entrega,
           d.total,             i.total,
           d.fecha_venta,       i.fecha_venta,
           d.id_usuario,        i.id_usuario
    FROM deleted d
    INNER JOIN inserted i ON i.id_venta = d.id_venta
    WHERE d.estado            <> i.estado
       OR d.domicilio_entrega <> i.domicilio_entrega
       OR d.total             <> i.total
       OR d.fecha_venta       <> i.fecha_venta
       OR d.id_usuario        <> i.id_usuario;
END;
GO

-- ---------------------------------------------------------------------
-- 3. Trigger de auditoría para DELETE sobre VENTA
--    Guarda los valores que tenía la venta borrada (los "nuevos" quedan NULL).
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER t_delete_venta
ON VENTA
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_VENTA
        (accion, id_venta,
         estado_anterior, domicilio_anterior, total_anterior,
         fecha_venta_anterior, id_usuario_vendedor_anterior)
    SELECT 'DELETE en la tabla VENTA', d.id_venta,
           d.estado, d.domicilio_entrega, d.total,
           d.fecha_venta, d.id_usuario
    FROM deleted d;
END;
GO

-- ---------------------------------------------------------------------
-- 4. Trigger que bloquea el DELETE sobre PRODUCTO
--    INSTEAD OF: el borrado nunca se ejecuta. Registra el intento y
--    emite un mensaje de error.
-- ---------------------------------------------------------------------
CREATE OR ALTER TRIGGER t_bloquear_delete_producto
ON PRODUCTO
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AUDITORIA_INTENTOS_BORRADO (tabla, accion, id_registro)
    SELECT 'PRODUCTO', 'Intento de DELETE bloqueado', d.id_producto
    FROM deleted d;

    RAISERROR('No se permite eliminar productos. Use la baja lógica (estado = 0).', 16, 1);
END;
GO
