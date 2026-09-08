-- ====================
-- COMANDOS DE TESTING
-- ====================

-- Borrar base de datos y login (testing)

USE master;
DROP DATABASE UAM_Biblioteca;
DROP TABLE dbo.Libros;
DROP LOGIN login_biblioteca;


-- Ver quien eres ahora mismo

SELECT ORIGINAL_LOGIN() AS LoginOriginal,
       SUSER_SNAME()    AS LoginActual,
       USER_NAME()      AS UsuarioActualDB,
       CURRENT_USER     AS CurrentUser,
       DB_NAME()        AS BaseActual;


-- Ver logins existentes a nivel de instancia

USE master;
SELECT name, type_desc, is_disabled, create_date, modify_date
FROM sys.server_principals
WHERE type IN ('S', 'U', 'G')
ORDER BY name;


-- =======================
-- COMANDOS DE ACTIVIDADES
-- =======================

-- ACTIVIDAD 4: Verificar la instancia

SELECT @@SERVERNAME                     AS server_name,
       @@VERSION                        AS version,
       SERVERPROPERTY('Edition')        AS edition,
       SERVERPROPERTY('ProductVersion') AS product_version,
       DB_NAME()                        AS current_database,
       GETDATE()                        AS server_time;

-- ACTIVIDAD 5: Crear la base de datos

CREATE DATABASE UAM_Biblioteca;
USE UAM_Biblioteca;
GO

-- ACTIVIDAD 6: Crear tabla y datos de prueba

CREATE TABLE dbo.Libros
(
    IdLibro         INT IDENTITY (1,1) PRIMARY KEY,
    Titulo          VARCHAR(150) NOT NULL,
    Autor           VARCHAR(150) NOT NULL,
    AnioPublicacion INT,
    Disponible      BIT DEFAULT 1
);
GO

INSERT INTO dbo.Libros
    (Titulo, Autor, AnioPublicacion)
VALUES ('Fundamentos de Bases de Datos', 'Abraham Silberschatz', 2021),
       ('SQL Server Administration', 'Microsoft', 2024),
       ('Database System Concepts', 'Silberschatz, Korth y Sudarshan', 2021);
GO

SELECT *
FROM dbo.Libros;
GO

-- ACTIVIDAD 7: Crear un Login

USE master;
GO

CREATE LOGIN login_biblioteca
    WITH PASSWORD = 'UamSQL#2026_Lab';
GO

-- ACTIVIDAD 8: Crear el User

USE UAM_Biblioteca;
GO

CREATE USER usuario_biblioteca
    FOR LOGIN login_biblioteca;
GO

-- ACTIVIDAD 9: Crear roles personalizados

USE UAM_Biblioteca;
GO

CREATE ROLE rol_consulta;
GO

CREATE ROLE rol_operador;
GO

-- ACTIVIDAD 10: Asignar permisos a los roles

GRANT SELECT
    ON dbo.Libros
    TO rol_consulta;
GO

GRANT SELECT, INSERT, UPDATE
    ON dbo.Libros
    TO rol_operador;
GO

-- ACTIVIDAD 11: Agregar usuarios a los roles

-- Rol de consulta
ALTER ROLE rol_consulta
    ADD MEMBER usuario_biblioteca;
GO

-- Rol de operador
ALTER ROLE rol_operador
    ADD MEMBER usuario_biblioteca;
GO


-- ACTIVIDAD 12: Prueba de permisos

EXECUTE AS USER = 'usuario_biblioteca';

-- SELECT
USE UAM_Biblioteca;
GO
SELECT *
FROM dbo.Libros;
GO

-- INSERT
INSERT INTO dbo.Libros (Titulo, Autor, AnioPublicacion)
VALUES ('Nuevo Libro', 'Autor de Prueba', 2026);
GO

-- UPDATE
UPDATE dbo.Libros
SET AnioPublicacion = 2025
WHERE IdLibro = 1;
GO

-- DELETE
DELETE
FROM dbo.Libros
WHERE IdLibro = 4;
GO

REVERT;
-- Revierte la impersonación del usuario y vuelve al contexto anterior

-- ACTIVIDAD 13: Consultar usuarios y roles

USE UAM_Biblioteca;
GO

-- Usuarios
SELECT name, type_desc, authentication_type_desc
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G')
ORDER BY name;
GO

-- Miembros de roles
SELECT dp.name AS Usuario,
       rp.name AS Rol
FROM sys.database_role_members drm
         JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
         JOIN sys.database_principals dp ON drm.member_principal_id = dp.principal_id
ORDER BY dp.name, rp.name;
GO

-- Login de instancia
USE master;
GO

SELECT name, type_desc, is_disabled
FROM sys.server_principals
ORDER BY name;
GO


SELECT *
FROM dbo.Libros;