IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = 'rol_administrador'
      AND type = 'R'
)
    CREATE ROLE rol_administrador;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = 'rol_cliente'
      AND type = 'R'
)
    CREATE ROLE rol_cliente;
GO


-- USUARIOS DE PRUEBA
IF DATABASE_PRINCIPAL_ID('usuario_demo_administrador') IS NULL
    CREATE USER usuario_demo_administrador WITHOUT LOGIN;
GO

IF DATABASE_PRINCIPAL_ID('usuario_demo_cliente') IS NULL
    CREATE USER usuario_demo_cliente WITHOUT LOGIN;
GO

---------------------


IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    INNER JOIN sys.database_principals r
        ON rm.role_principal_id = r.principal_id
    INNER JOIN sys.database_principals u
        ON rm.member_principal_id = u.principal_id
    WHERE r.name = 'rol_administrador'
      AND u.name = 'usuario_demo_administrador'
)
    ALTER ROLE rol_administrador
    ADD MEMBER usuario_demo_administrador;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members rm
    INNER JOIN sys.database_principals r
        ON rm.role_principal_id = r.principal_id
    INNER JOIN sys.database_principals u
        ON rm.member_principal_id = u.principal_id
    WHERE r.name = 'rol_cliente'
      AND u.name = 'usuario_demo_cliente'
)
    ALTER ROLE rol_cliente
    ADD MEMBER usuario_demo_cliente;
GO


-- Rol cliente
GRANT EXECUTE
ON OBJECT::dbo.sp_RegistrarVenta
TO rol_cliente;

GRANT EXECUTE
ON OBJECT::dbo.sp_CancelarVenta
TO rol_cliente;

GRANT EXECUTE, REFERENCES
ON TYPE::dbo.tipo_item_venta
TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.USUARIO TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.METODO_PAGO TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.PRODUCTO TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA_DETALLE TO rol_cliente;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA_PAGO TO rol_cliente;


-- Rol administrador
GRANT EXECUTE
ON OBJECT::dbo.sp_RegistrarVenta
TO rol_administrador;

GRANT EXECUTE
ON OBJECT::dbo.sp_CancelarVenta
TO rol_administrador;
GO

GRANT EXECUTE, REFERENCES
ON TYPE::dbo.tipo_item_venta
TO rol_administrador;
GO

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.USUARIO TO rol_administrador;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.METODO_PAGO TO rol_administrador;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.PRODUCTO TO rol_administrador;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA TO rol_administrador;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA_DETALLE TO rol_administrador;

DENY SELECT, INSERT, UPDATE, DELETE
ON OBJECT::dbo.VENTA_PAGO TO rol_administrador;
GO


-- VERIFICACION
SELECT
    r.name AS rol,
    u.name AS usuario
FROM sys.database_role_members rm
INNER JOIN sys.database_principals r
    ON rm.role_principal_id = r.principal_id
INNER JOIN sys.database_principals u
    ON rm.member_principal_id = u.principal_id
WHERE r.name IN ('rol_administrador', 'rol_cliente')
ORDER BY r.name;
GO
