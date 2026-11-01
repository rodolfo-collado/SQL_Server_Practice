USE BD_REGION_3;
GO

-- Indice de apoyo para consultas regionales por fecha y zona.
-- Se crea una sola vez; ajuste DIA/ZONA si su carga real filtra por otras columnas.
IF OBJECT_ID(N'dbo.CONSUMO_REGIONAL', N'U') IS NOT NULL
    AND COL_LENGTH(N'dbo.CONSUMO_REGIONAL', N'DIA') IS NOT NULL
    AND COL_LENGTH(N'dbo.CONSUMO_REGIONAL', N'ZONA') IS NOT NULL
    AND NOT EXISTS
       (SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.CONSUMO_REGIONAL')
          AND name = N'IX_CONSUMO_REGIONAL_DIA_ZONA')
    BEGIN
        CREATE NONCLUSTERED INDEX IX_CONSUMO_REGIONAL_DIA_ZONA
            ON dbo.CONSUMO_REGIONAL (DIA, ZONA);
    END;
GO

-- 1. Fragmentacion: tabla, indice, tipo, porcentaje y paginas.
-- HEAP significa que la tabla no tiene indice clustered.
SELECT OBJECT_NAME(ips.object_id)                              AS Tabla,
       i.name                                                  AS Indice,
       ips.index_type_desc                                     AS Tipo,
       ips.partition_number                                    AS Particion,
       CAST(ips.avg_fragmentation_in_percent AS DECIMAL(6, 2)) AS Fragmentacion_Porcentaje,
       ips.page_count                                          AS Paginas
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
         JOIN sys.indexes AS i
              ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.index_level = 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 2. Archivos MDF/NDF/LDF: tamano y autocrecimiento.
-- Si growth = 0, el autocrecimiento esta deshabilitado.
SELECT name                                 AS Nombre_Logico,
       type_desc                            AS Tipo,
       physical_name                        AS Ruta,
       CAST(size / 128.0 AS DECIMAL(18, 2)) AS Tamano_MB,
       CASE
           WHEN is_percent_growth = 1
               THEN CONCAT(growth, ' %')
           ELSE CONCAT(CAST(growth / 128.0 AS DECIMAL(18, 2)), ' MB')
           END                              AS Autocrecimiento
FROM sys.database_files;

-- 3. Espacio reservado y utilizado por datos e indices de la base.
-- database_size incluye datos y log; reserved corresponde a datos e indices.
EXEC sys.sp_spaceused;

-- Espacio ocupado en el log de la base.
SELECT CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS Log_Total_MB,
       CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(18, 2)) AS Log_Usado_MB,
       CAST(used_log_space_in_percent AS DECIMAL(6, 2))            AS Log_Uso_Porcentaje
FROM sys.dm_db_log_space_usage;

-- Memoria del proceso SQL Server; corresponde a toda la instancia.
SELECT CAST(physical_memory_in_use_kb / 1024.0 AS DECIMAL(18, 2)) AS Memoria_En_Uso_MB,
       CAST(large_page_allocations_kb / 1024.0 AS DECIMAL(18, 2)) AS Paginas_Grandes_MB,
       memory_utilization_percentage                              AS Porcentaje_Memoria_Comprometida_En_RAM,
       process_physical_memory_low                                AS Alerta_Memoria_Baja
FROM sys.dm_os_process_memory;

-- 4. Recomendacion automatica (diagnostico, no ejecuta mantenimiento).
-- Umbrales de fragmentacion: <=10 % ninguna accion; >10-30 % REORGANIZE;
-- >30 % REBUILD. Se omiten indices con menos de 1000 paginas para evitar
-- actuar sobre estructuras pequenas. HEAP no se mantiene con ALTER INDEX.
WITH Fragmentacion AS
         (SELECT ips.object_id,
                 ips.index_id,
                 SUM(ips.avg_fragmentation_in_percent * ips.page_count) /
                 NULLIF(SUM(ips.page_count), 0) AS Fragmentacion_Pct,
                 SUM(ips.page_count)            AS Paginas
          FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
          WHERE ips.index_level = 0
            AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
          GROUP BY ips.object_id, ips.index_id),
     ArchivosDatos AS
         (SELECT df.name,
                 df.size / 128.0                            AS Tamano_MB,
                 FILEPROPERTY(df.name, 'SpaceUsed') / 128.0 AS Usado_MB
          FROM sys.database_files AS df
          WHERE df.type = 0),
     Recomendaciones AS
         (SELECT CONCAT(QUOTENAME(OBJECT_SCHEMA_NAME(f.object_id)), '.', QUOTENAME(OBJECT_NAME(f.object_id)), '.',
                        QUOTENAME(i.name)) AS Elemento,
                 CASE
                     WHEN f.Paginas < 1000 THEN 'NINGUNA'
                     WHEN f.Fragmentacion_Pct > 30 THEN 'REBUILD'
                     WHEN f.Fragmentacion_Pct > 10 THEN 'REORGANIZE'
                     ELSE 'NINGUNA'
                     END                   AS Accion,
                 CONCAT('Fragmentacion=', CAST(f.Fragmentacion_Pct AS DECIMAL(6, 2)), '%; paginas=', f.Paginas,
                        CASE
                            WHEN f.Paginas < 1000 THEN '; indice pequeno, no se recomienda mantenimiento'
                            ELSE '' END)   AS Evidencia
          FROM Fragmentacion AS f
                   JOIN sys.indexes AS i ON i.object_id = f.object_id AND i.index_id = f.index_id
          WHERE i.index_id > 0
            AND i.name IS NOT NULL

          UNION ALL

          SELECT CONCAT('Archivo de datos ', QUOTENAME(name)),
                 CASE
                     WHEN Tamano_MB - Usado_MB >= 1024
                         AND (Tamano_MB - Usado_MB) / NULLIF(Tamano_MB, 0) >= 0.30
                         THEN 'EVALUAR SHRINKFILE'
                     ELSE 'NO SHRINKFILE' END,
                 CONCAT('Tamano=', CAST(Tamano_MB AS DECIMAL(18, 2)), ' MB; usado=', CAST(Usado_MB AS DECIMAL(18, 2)),
                        ' MB; libre=', CAST(Tamano_MB - Usado_MB AS DECIMAL(18, 2)),
                        ' MB. Reducir solo si el espacio libre es permanente; SHRINK puede fragmentar y causar autogrowth.')
          FROM ArchivosDatos

          UNION ALL

          SELECT 'Memoria de SQL Server',
                 CASE
                     WHEN pm.process_physical_memory_low = 1 THEN 'INVESTIGAR; NO CAMBIAR AUN'
                     ELSE 'NO CAMBIO JUSTIFICADO' END,
                 CONCAT('Alerta de memoria baja del proceso=', pm.process_physical_memory_low,
                        '; una muestra no justifica cambiar max server memory; revisar tendencia y memoria del host/contenedor.')
          FROM sys.dm_os_process_memory AS pm)
SELECT Elemento, Accion, Evidencia
FROM Recomendaciones
ORDER BY Elemento;

