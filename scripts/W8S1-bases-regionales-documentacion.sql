/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM) - ADMINISTRACIÓN Y GESTIÓN DE BASES DE DATOS
 Sesión 15: Extracción Automatizada de Metadatos y Diccionario de Datos
 Caso de Estudio: Práctica Guiada de Bases de Datos Distribuidas (Ventas Norte y Ventas Sur)
 Indicadores de Logro: ILE3.1, ILE3.2 (RAAE3) | ILE2.1, ILE2.2 (RAAE2)
*******************************************************************************/

SET NOCOUNT ON;
GO

-- ============================================================================
-- SECCIÓN 1: ASIGNACIÓN DE PROPIEDADES EXTENDIDAS (MS_Description)
-- Documentación embebida directamente en el gestor para Ventas_Norte y Ventas_Sur
-- ============================================================================

-- 1.1 Documentar tablas y columnas en Ventas_Norte
USE Ventas_Norte;
GO

-- Tabla Clientes
EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Catálogo de clientes atendidos por la Sucursal Norte.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Clientes';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Identificador único del cliente en la sucursal.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Clientes',
     @level2type = N'COLUMN', @level2name = N'IdCliente';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Ciudad de residencia del cliente (utilizada para análisis de fragmentación geográfica).',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Clientes',
     @level2type = N'COLUMN', @level2name = N'Ciudad';

-- Tabla Ventas
EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Registro transaccional de ventas realizadas en la Sucursal Norte.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Ventas';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Fecha de emisión de la venta.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Ventas',
     @level2type = N'COLUMN', @level2name = N'Fecha';
GO

-- 1.2 Documentar Sinónimos para la Sucursal Sur (en caso de Servidor Enlazado o BD Remota)
IF OBJECT_ID(N'dbo.syn_VentasSur', N'SN') IS NOT NULL
    BEGIN
        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Sinónimo/Alias local que apunta a la tabla Ventas de la base de datos remota Ventas_Sur.',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'SYNONYM', @level1name = N'syn_VentasSur';
    END;
GO

-- Comprobar extended properties
SELECT *
FROM sys.extended_properties;

--Comprobar servidores
SELECT *
FROM sys.servers;



-- Crear Servidor enlazado
USE master;

IF NOT EXISTS (SELECT 1
               FROM sys.servers
               WHERE name = N'SERVIDOR_VENTAS_SUR')
    BEGIN

        EXEC master.dbo.sp_addlinkedserver
             @server = N'SERVIDOR_VENTAS_SUR',
             @srvproduct = N'',
             @provider = N'MSOLEDBSQL',
             @datasrc = N'mssql-lab,1433',
             @provstr = N'Encrypt=Optional;TrustServerCertificate=Yes',
             @catalog = N'Ventas_Sur';
    END;

-- añadir sa como login remoto
IF NOT EXISTS (SELECT 1
               FROM sys.linked_logins AS ll
                        INNER JOIN sys.servers AS s
                                   ON s.server_id = ll.server_id
               WHERE s.name = N'SERVIDOR_VENTAS_SUR'
                 AND ll.local_principal_id = SUSER_ID('sa'))
    BEGIN
        EXEC master.dbo.sp_addlinkedsrvlogin
             @rmtsrvname = N'SERVIDOR_VENTAS_SUR',
             @useself = N'False',
             @locallogin = 'sa',
             @rmtuser = N'sa',
             @rmtpassword = N'BasesDeDatos!2026';
    END;

-- test del servidor
EXEC master.dbo.sp_testlinkedserver N'SERVIDOR_VENTAS_SUR';


-- Crear sinónimo
IF OBJECT_ID(N'dbo.syn_VentasSur', N'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_VentasSur;
GO

CREATE SYNONYM dbo.syn_VentasSur
    FOR [SERVIDOR_VENTAS_SUR].[Ventas_Sur].[dbo].[Ventas];
GO

-- ============================================================================
-- SECCIÓN 2: DICCIONARIO DE DATOS AUTOMATIZADO CON VISTAS DE CATÁLOGO (sys.*)
-- Genera el reporte físico de campos, tipos, nulos y descripciones de negocio
-- ============================================================================

USE Ventas_Norte;
GO

SELECT DB_NAME()                                                             AS [Base_Datos],
       t.name                                                                AS [Tabla],
       c.column_id                                                           AS [Orden],
       c.name                                                                AS [Columna],
       ty.name                                                               AS [Tipo_Dato],
       c.max_length                                                          AS [Longitud_Bytes],
       CASE WHEN c.is_nullable = 1 THEN 'SÍ' ELSE 'NO' END                   AS [Permite_Nulos],
       ISNULL(CAST(ep.value AS VARCHAR(250)), '⚠️ Sin descripción asignada') AS [Descripcion_Negocio]
FROM sys.tables t
         INNER JOIN sys.columns c
                    ON t.object_id = c.object_id
         INNER JOIN sys.types ty
                    ON c.user_type_id = ty.user_type_id
         LEFT JOIN sys.extended_properties ep
                   ON ep.major_id = c.object_id
                       AND ep.minor_id = c.column_id
                       AND ep.name = 'MS_Description'
WHERE t.name IN ('Clientes', 'Productos', 'Ventas')
ORDER BY t.name, c.column_id;
GO

-- ============================================================================
-- SECCIÓN 3: AUDITORÍA DE INFRAESTRUCTURA DISTRIBUIDA (Linked Servers y Sinónimos)
-- Permite inspeccionar conexiones externas y la abstracción de objetos remotos
-- ============================================================================

-- 3.1 Auditar Servidores Enlazados Registrados en la Instancia
SELECT server_id   AS [ID_Servidor],
       name        AS [Nombre_Servidor_Enlazado],
       product     AS [Producto],
       provider    AS [Proveedor_OLEDB],
       data_source AS [Origen_Datos_IP_Instancia],
       is_linked   AS [Es_Enlazado],
       modify_date AS [Ultima_Modificacion]
FROM sys.servers
WHERE is_linked = 1;
GO

-- 3.2 Auditar Sinónimos Configurados para Ventas Distribuidas
SELECT s.name             AS [Sinonimo_Local],
       s.base_object_name AS [Objeto_Remoto_Referenciado],
       s.create_date      AS [Fecha_Creacion]
FROM sys.synonyms s;
GO

-- ============================================================================
-- SECCIÓN 4: ANÁLISIS DE IMPACTO Y MAPEO DE DEPENDENCIAS DE OBJETOS
-- Examina vistas globales o procedimientos que consumen fragmentos de ventas
-- ============================================================================

-- Ejemplo: Creación de Vista Global Consolidada si no existe
USE Ventas_Norte;
GO

CREATE OR ALTER VIEW dbo.VW_VentasGlobales AS
SELECT IdVenta, Fecha, IdCliente, 'Norte' AS Sucursal
FROM Ventas_Norte.dbo.Ventas
UNION ALL
SELECT IdVenta, Fecha, IdCliente, 'Sur' AS Sucursal
FROM syn_VentasSur;
GO

-- Mapeo de dependencias utilizando sys.sql_expression_dependencies
SELECT o.name                                        AS [Objeto_Consumidor_Global],
       o.type_desc                                   AS [Tipo_Objeto],
       d.referenced_entity_name                      AS [Tabla_Referenciada_Dependiente],
       ISNULL(d.referenced_database_name, DB_NAME()) AS [Base_Datos_Destino]
FROM sys.sql_expression_dependencies d
         INNER JOIN sys.objects o
                    ON d.referencing_id = o.object_id
WHERE o.name = 'VW_VentasGlobales'
   OR d.referenced_entity_name IN ('Ventas', 'Clientes', 'Productos');
GO
