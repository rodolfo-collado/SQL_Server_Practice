/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM) - FACULTAD DE INGENIERÍA Y ARQUITECTURA
 ASIGNATURA: ADMINISTRACIÓN Y GESTIÓN DE BASES DE DATOS (2S2026)
--------------------------------------------------------------------------------
 SESIÓN 13: TRAZABILIDAD DEL ESQUEMA Y AUDITORÍA DE PARÁMETROS CRÍTICOS DEL SGBD
 Resultado de Aprendizaje: RAAE3 (Trazabilidad y Documentación)
 Indicadores de Logro: ILE3.1, ILE3.2, ILE4.3 (Métricas de Rendimiento y Capacidad)
*******************************************************************************/

SET NOCOUNT ON;
GO

-- Seleccionar la base de datos de trabajo (ejemplo: Northwind, GestionConsumoDB o BD local)
IF EXISTS (SELECT 1
           FROM sys.databases
           WHERE name = 'Northwind')
USE Northwind;
ELSE
    USE master;
GO

PRINT '========================================================================';
PRINT ' UAM - SCRIPT DE LABORATORIO SESIÓN 13: TRAZABILIDAD Y AUDITORÍA SGBD';
PRINT ' Base de datos activa: ' + DB_NAME();
PRINT '========================================================================';
GO

-- ============================================================================
-- SECCIÓN 1: ANÁLISIS DE TRAZABILIDAD Y MAPEO DE DEPENDENCIAS DEL ESQUEMA
-- Objetivo: Identificar relaciones entre tablas, vistas y procedimientos
-- ============================================================================

PRINT '--- 1.1 MAPEO DE DEPENDENCIAS ENTRE OBJETOS (sys.sql_expression_dependencies) ---';
GO

SELECT OBJECT_SCHEMA_NAME(d.referencing_id)          AS [Esquema_Consumidor],
       OBJECT_NAME(d.referencing_id)                 AS [Objeto_Consumidor],
       o.type_desc                                   AS [Tipo_Objeto_Consumidor],
       ISNULL(d.referenced_database_name, DB_NAME()) AS [Base_Datos_Destino],
       ISNULL(d.referenced_schema_name, 'dbo')       AS [Esquema_Referenciado],
       d.referenced_entity_name                      AS [Objeto_Referenciado_Dependiente]
FROM sys.sql_expression_dependencies d
         INNER JOIN sys.objects o ON d.referencing_id = o.object_id
WHERE o.is_ms_shipped = 0
ORDER BY [Objeto_Consumidor], [Objeto_Referenciado_Dependiente];
GO

PRINT '--- 1.2 ARBOL DE INTEGRIDAD REFERENCIAL (CLAVES FORÁNEAS PK/FK) ---';
GO

SELECT fk.name                                                      AS [Nombre_FK],
       OBJECT_NAME(fk.parent_object_id)                             AS [Tabla_Padre_Origen],
       COL_NAME(fkc.parent_object_id, fkc.parent_column_id)         AS [Columna_Origen],
       OBJECT_NAME(fk.referenced_object_id)                         AS [Tabla_Referenciada_Destino],
       COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS [Columna_Destino],
       fk.delete_referential_action_desc                            AS [Accion_Delete],
       fk.update_referential_action_desc                            AS [Accion_Update]
FROM sys.foreign_keys fk
         INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
ORDER BY [Tabla_Padre_Origen];
GO

PRINT '--- 1.3 DETECCIÓN DE TABLAS HUÉRFANAS (SIN DEPENDENCIAS REGISTRADAS) ---';
GO

SELECT t.name AS [Tabla_Sin_Dependencias]
FROM sys.tables t
WHERE t.is_ms_shipped = 0
  AND t.object_id NOT IN (SELECT DISTINCT parent_object_id FROM sys.foreign_keys)
  AND t.object_id NOT IN (SELECT DISTINCT referenced_object_id FROM sys.foreign_keys)
ORDER BY t.name;
GO


-- ============================================================================
-- SECCIÓN 2: EXTRACCIÓN AUTOMATIZADA DE METADATOS Y ESPECIFICACIONES
-- Objetivo: Documentar la configuración y propiedades de la base de datos
-- ============================================================================

PRINT '--- 2.1 PARÁMETROS CONFIGURACIÓN DE LA BASE DE DATOS ACTUAL ---';
GO

SELECT name                                                                        AS [Base_Datos],
       compatibility_level                                                         AS [Nivel_Compatibilidad],
       collation_name                                                              AS [Colacion],
       user_access_desc                                                            AS [Modo_Acceso],
       state_desc                                                                  AS [Estado],
       recovery_model_desc                                                         AS [Modelo_Recuperacion],
       CASE WHEN is_auto_shrink_on = 1 THEN 'SÍ (Riesgo)' ELSE 'NO (Correcto)' END AS [Auto_Shrink],
       CASE WHEN is_auto_close_on = 1 THEN 'SÍ (Riesgo)' ELSE 'NO (Correcto)' END  AS [Auto_Close]
FROM sys.databases
WHERE name = DB_NAME();
GO

PRINT '--- 2.2 DICCIONARIO DE DATOS Y DESCRIPCIONES EMBEBIDAS (MS_Description) ---';
GO

SELECT t.name                                                                AS [Tabla],
       c.column_id                                                           AS [Orden],
       c.name                                                                AS [Columna],
       ty.name                                                               AS [Tipo_Dato],
       c.max_length                                                          AS [Longitud_Bytes],
       CASE WHEN c.is_nullable = 1 THEN 'SÍ' ELSE 'NO' END                   AS [Permite_Nulos],
       ISNULL(CAST(ep.value AS VARCHAR(250)), '⚠️ Pendiente por documentar') AS [Descripcion_Negocio]
FROM sys.tables t
         INNER JOIN sys.columns c ON t.object_id = c.object_id
         INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
         LEFT JOIN sys.extended_properties ep
                   ON ep.major_id = c.object_id
                       AND ep.minor_id = c.column_id
                       AND ep.name = 'MS_Description'
WHERE t.is_ms_shipped = 0
ORDER BY t.name, c.column_id;
GO


-- ============================================================================
-- SECCIÓN 3: DOCUMENTACIÓN DE PARÁMETROS CRÍTICOS DEL SGBD
-- Objetivo: Monitorear almacenamiento, fragmentación de índices y memoria
-- ============================================================================

PRINT '--- 3.1 CAPACIDAD Y ESPACIO DE ARCHIVOS DE DATOS Y LOG (.mdf / .ldf) ---';
GO

SELECT name                                                                            AS [Nombre_Logico],
       type_desc                                                                       AS [Tipo_Archivo],
       physical_name                                                                   AS [Ruta_Fisica],
       CAST((size * 8.0 / 1024) AS DECIMAL(10, 2))                                     AS [Tamaño_Total_MB],
       CAST((FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024) AS DECIMAL(10, 2))          AS [Espacio_Usado_MB],
       CAST(((size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024) AS DECIMAL(10, 2)) AS [Espacio_Libre_MB],
       CAST((FILEPROPERTY(name, 'SpaceUsed') * 100.0 / size) AS DECIMAL(5, 2))         AS [Porcentaje_Uso]
FROM sys.database_files;
GO

PRINT '--- 3.2 DIAGNÓSTICO DE FRAGMENTACIÓN LÓGICA DE ÍNDICES (> 10%) ---';
GO

SELECT OBJECT_NAME(ips.object_id)                              AS [Tabla],
       i.name                                                  AS [Indice],
       ips.index_type_desc                                     AS [Tipo_Indice],
       CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5, 2)) AS [Porcentaje_Fragmentacion],
       ips.page_count                                          AS [Total_Paginas],
       CASE
           WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD (Reconstruir)'
           WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30 THEN 'REORGANIZE (Reorganizar)'
           ELSE 'OK (Aceptable)'
           END                                                 AS [Accion_Recomendada]
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
         INNER JOIN sys.indexes i
                    ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10.0
  AND i.name IS NOT NULL
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

PRINT '--- 3.3 MONITOREO DE USO DE MEMORIA DEL SERVIDOR ---';
GO

SELECT CAST(physical_memory_in_use_kb / 1024.0 AS DECIMAL(10, 2))                                            AS [Memoria_En_Uso_MB],
       CAST(large_page_allocations_kb / 1024.0 AS DECIMAL(10, 2))                                            AS [Paginas_Grandes_MB],
       memory_utilization_percentage                                                                         AS [Porcentaje_Utilizacion_RAM],
       CASE
           WHEN process_physical_memory_low = 1 THEN '⚠️ ALERTA: Memoria Física Baja'
           ELSE 'OK: Normal' END                                                                             AS [Estado_Memoria]
FROM sys.dm_os_process_memory;
GO

PRINT '========================================================================';
PRINT ' SCRIPT COMPLETADO CON ÉXITO - UAM SESIÓN 13';
PRINT '========================================================================';
GO


