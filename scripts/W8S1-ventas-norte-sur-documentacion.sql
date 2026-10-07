/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM)
 FACULTAD DE INGENIERÍA Y ARQUITECTURA
 CARRERA DE INGENIERÍA EN SISTEMAS DE INFORMACIÓN
 
 ASIGNATURA: Administración y Gestión de Bases de Datos (SIS0211)
 UNIDAD III: Documentación Técnica y Trazabilidad de Bases de Datos (RAAE3)
 SESIÓN 15: Extracción Automatizada de Metadatos y Vistas de Catálogo (sys.*)
 CASO DE ESTUDIO: Consumo de Trafico Movil y Servidores Enlazados

*******************************************************************************/

USE BD_REGION_1; -- Instancia / Base de Datos Central
GO


-- ============================================================================
-- SCRIPT 1: DICCIONARIO DE DATOS AUTOMATIZADO CON PROPIEDADES EXTENDIDAS
-- ============================================================================
-- Extrae la estructura física, tipos de datos, longitud, nulabilidad y 
-- descripciones de negocio (MS_Description) de las tablas de consumo.

PRINT '>>> EJECUTANDO SCRIPT 1: DICCIONARIO DE DATOS AUTOMATIZADO...';
GO

SELECT t.name                                                         AS [Tabla_Local],
       c.column_id                                                    AS [Orden],
       c.name                                                         AS [Columna],
       ty.name                                                        AS [Tipo_Dato],
       c.max_length                                                   AS [Longitud_Bytes],
       CASE WHEN c.is_nullable = 1 THEN 'SÍ' ELSE 'NO' END            AS [Permite_Nulos],
       ISNULL(CAST(ep.value AS VARCHAR(250)), '⚠️ Sin documentación') AS [Descripcion_Negocio]
FROM sys.tables t
         INNER JOIN sys.columns c
                    ON t.object_id = c.object_id
         INNER JOIN sys.types ty
                    ON c.user_type_id = ty.user_type_id
         LEFT JOIN sys.extended_properties ep
                   ON ep.major_id = c.object_id
                       AND ep.minor_id = c.column_id
                       AND ep.name = 'MS_Description'
WHERE t.name IN ('CONSUMO_REGIONAL', 'ANTENAS_UNICAS')
ORDER BY t.name, c.column_id;
GO


-- ============================================================================
-- SCRIPT 2: AUDITORÍA DE SERVIDORES ENLAZADOS Y SINÓNIMOS DISTRIBUIDOS
-- ============================================================================
-- Permite auditar desde el catálogo del gestor la infraestructura de conexión 
-- externa (sys.servers) y la abstracción de objetos remotos (sys.synonyms).

PRINT '>>> EJECUTANDO SCRIPT 2: AUDITORÍA DE SERVIDORES ENLAZADOS Y SINÓNIMOS...';
GO

-- 2.1. Consultar Servidores Enlazados Registrados en el SGBD
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

-- 2.2. Consultar Sinónimos y sus Rutas de Abstracción Remota
SELECT s.name             AS [Sinonimo_Local],
       s.base_object_name AS [Objeto_Remoto_4_Partes],
       s.create_date      AS [Fecha_Creacion]
FROM sys.synonyms s;
GO

-- Crear sinónimo
IF OBJECT_ID(N'dbo.syn_REGION_3', N'SN') IS NOT NULL
    DROP SYNONYM dbo.syn_REGION_3;
GO

CREATE SYNONYM dbo.syn_REGION_3
    FOR [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL];
GO


-- ============================================================================
-- SCRIPT 3: TRAZABILIDAD Y MAPEO DE DEPENDENCIAS (sys.sql_expression_dependencies)
-- ============================================================================
-- Inspecciona qué vistas globales (vw_ConsumoNacional) o procedimientos almacenados
-- dependen de las tablas locales o remotas antes de aplicar cambios de esquema.

PRINT '>>> EJECUTANDO SCRIPT 3: ANÁLISIS DE IMPACTO Y DEPENDENCIAS...';
GO

SELECT o.name                                        AS [Objeto_Consumidor],
       o.type_desc                                   AS [Tipo_Objeto],
       d.referenced_entity_name                      AS [Entidad_Referenciada_Dependiente],
       ISNULL(d.referenced_database_name, DB_NAME()) AS [Base_Datos_Destino]
FROM sys.sql_expression_dependencies d
         INNER JOIN sys.objects o
                    ON d.referencing_id = o.object_id
WHERE d.referenced_entity_name LIKE '%CONSUMO%'
   OR o.name LIKE '%VW_CONSUMO%'
ORDER BY o.name;
GO



-- ============================================================================
-- SCRIPT 4: ASIGNACIÓN DE PROPIEDADES EXTENDIDAS (MS_Description) EN DATOS DISTRIBUIDOS
-- ============================================================================
-- Asigna directamente en el motor el propósito de negocio de la fragmentación 
-- regional y las columnas clave de consumo.

PRINT '>>> EJECUTANDO SCRIPT 4: DOCUMENTACIÓN DE PROPIEDADES EXTENDIDAS...';
GO

-- 4.1. Documentar la Tabla Transaccional de Consumo
IF EXISTS (SELECT 1
           FROM sys.tables
           WHERE name = 'CONSUMO_REGIONAL')
    BEGIN
        -- Eliminar propiedad si ya existe para evitar duplicados
        IF EXISTS (SELECT 1
                   FROM sys.extended_properties
                   WHERE major_id = OBJECT_ID('CONSUMO_REGIONAL')
                     AND minor_id = 0
                     AND name = 'MS_Description')
            BEGIN
                EXEC sys.sp_dropextendedproperty
                     @name = N'MS_Description',
                     @level0type = N'SCHEMA', @level0name = N'dbo',
                     @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL';
            END;

        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Tabla transaccional fragmentada horizontalmente por zonas comerciales (Capital, Sur Oriente, etc.).',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL';

        -- Documentar columna MB (Tráfico de Datos)
        IF EXISTS (SELECT 1
                   FROM sys.extended_properties
                   WHERE major_id = OBJECT_ID('CONSUMO_REGIONAL')
                     AND minor_id = COLUMNPROPERTY(OBJECT_ID('CONSUMO_REGIONAL'), 'MB', 'ColumnId')
                     AND name = 'MS_Description')
            BEGIN
                EXEC sys.sp_dropextendedproperty
                     @name = N'MS_Description',
                     @level0type = N'SCHEMA', @level0name = N'dbo',
                     @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL',
                     @level2type = N'COLUMN', @level2name = N'MB';
            END;

        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Tráfico de datos consumido en Megabytes (MB) en el periodo registrado.',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL',
             @level2type = N'COLUMN', @level2name = N'MB';

        -- Documentar columna INGRESO (Monto Facturado)
        IF EXISTS (SELECT 1
                   FROM sys.extended_properties
                   WHERE major_id = OBJECT_ID('CONSUMO_REGIONAL')
                     AND minor_id = COLUMNPROPERTY(OBJECT_ID('CONSUMO_REGIONAL'), 'INGRESO', 'ColumnId')
                     AND name = 'MS_Description')
            BEGIN
                EXEC sys.sp_dropextendedproperty
                     @name = N'MS_Description',
                     @level0type = N'SCHEMA', @level0name = N'dbo',
                     @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL',
                     @level2type = N'COLUMN', @level2name = N'INGRESO';
            END;

        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Monto facturado en córdobas por el uso de servicios de voz, datos y eventos.',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE', @level1name = N'CONSUMO_REGIONAL',
             @level2type = N'COLUMN', @level2name = N'INGRESO';
    END;
GO

PRINT '>>> TODOS LOS SCRIPTS DE LA SESIÓN 15 FUERON COMPILADOS EXITOSAMENTE.';
GO

-- comprobar las descripciones
SELECT *
FROM sys.extended_properties;