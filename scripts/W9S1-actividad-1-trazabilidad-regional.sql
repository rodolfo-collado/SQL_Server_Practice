USE BD_REGION_3;
GO

-- Preparacion: vista sencilla para tener una dependencia que probar,
-- incluso si esta region todavia no tiene vistas o procedimientos.
CREATE OR ALTER VIEW dbo.vw_PruebaImpactoDDL
AS
SELECT MB, INGRESO
FROM dbo.CONSUMO_REGIONAL;
GO

-- 1. Consultar dependencias junto con objetos y esquemas.
SELECT s.name AS Esquema,
       o.name AS Objeto,
       o.type_desc AS Tipo,
       d.referenced_database_name AS Base_Referenciada,
       d.referenced_schema_name AS Esquema_Referenciado,
       d.referenced_entity_name AS Entidad_Referenciada
FROM sys.sql_expression_dependencies AS d
JOIN sys.objects AS o ON o.object_id = d.referencing_id
JOIN sys.schemas AS s ON s.schema_id = o.schema_id;
GO

-- 2. Identificar dependencias asociadas con CONSUMO_REGIONAL.
SELECT s.name AS Esquema,
       o.name AS Objeto_Dependiente,
       o.type_desc AS Tipo,
       d.referenced_entity_name AS Entidad_Referenciada,
       d.is_schema_bound_reference AS Con_Schemabinding
FROM sys.sql_expression_dependencies AS d
JOIN sys.objects AS o ON o.object_id = d.referencing_id
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE d.referenced_entity_name = 'CONSUMO_REGIONAL';
GO

-- 3. Simular cambios reales y observar su impacto.


-- 3.1 Ampliar MB de DECIMAL(18,2) a DECIMAL(19,2).
-- Impacto: aumenta la precision; conserva los valores actuales.
-- La vista no usa SCHEMABINDING y permite este cambio.
ALTER TABLE dbo.CONSUMO_REGIONAL
ALTER COLUMN MB DECIMAL(19,2) NULL;
GO

-- Actualizar los metadatos de la vista despues del cambio de tipo.
EXEC sys.sp_refreshview N'dbo.vw_PruebaImpactoDDL';

SELECT TOP (5) MB, INGRESO
FROM dbo.vw_PruebaImpactoDDL;
GO

-- 3.2 Eliminar INGRESO de la tabla real.
-- Impacto: se pierden sus datos y la vista deja de funcionar.
-- Si existen restricciones u otros objetos que bloquean el cambio,
-- guardar el error como evidencia del impacto DDL.
ALTER TABLE dbo.CONSUMO_REGIONAL
DROP COLUMN INGRESO;
GO

-- Ejecutar por separado despues del DROP.
-- Resultado esperado si se elimino la columna: error de columna INGRESO
-- no valida y/o error de enlace de la vista.
SELECT TOP (5) MB, INGRESO
FROM dbo.vw_PruebaImpactoDDL;
GO

-- Recuperación: Restaurar la base de datos para revertir los cambios.

USE master;

ALTER DATABASE BD_REGION_3
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BD_REGION_3
FROM DISK = '/var/opt/mssql/backup/BD_REGION_3_mssql-lab.bak'
WITH REPLACE, RECOVERY, STATS = 10;

ALTER DATABASE BD_REGION_3
SET MULTI_USER;
