
USE BD_REGION_1;

-- 1. Fragmentacion: tabla, indice, tipo, porcentaje y paginas.
-- HEAP significa que la tabla no tiene indice clustered.
SELECT OBJECT_NAME(ips.object_id) AS Tabla,
       i.name AS Indice,
       ips.index_type_desc AS Tipo,
       ips.partition_number AS Particion,
       CAST(ips.avg_fragmentation_in_percent AS DECIMAL(6,2)) AS Fragmentacion_Porcentaje,
       ips.page_count AS Paginas
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ips
JOIN sys.indexes AS i
    ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.index_level = 0
  AND ips.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 2. Archivos MDF/NDF/LDF: tamano y autocrecimiento.
-- Si growth = 0, el autocrecimiento esta deshabilitado.
SELECT name AS Nombre_Logico,
       type_desc AS Tipo,
       physical_name AS Ruta,
       CAST(size / 128.0 AS DECIMAL(18,2)) AS Tamano_MB,
       CASE WHEN is_percent_growth = 1
            THEN CONCAT(growth, ' %')
            ELSE CONCAT(CAST(growth / 128.0 AS DECIMAL(18,2)), ' MB')
       END AS Autocrecimiento
FROM sys.database_files;

-- 3. Espacio reservado y utilizado por datos e indices de la base.
-- database_size incluye datos y log; reserved corresponde a datos e indices.
EXEC sys.sp_spaceused;

-- 4. Espacio ocupado en el log de la base.
SELECT CAST(total_log_size_in_bytes / 1048576.0 AS DECIMAL(18,2)) AS Log_Total_MB,
       CAST(used_log_space_in_bytes / 1048576.0 AS DECIMAL(18,2)) AS Log_Usado_MB,
       CAST(used_log_space_in_percent AS DECIMAL(6,2)) AS Log_Uso_Porcentaje
FROM sys.dm_db_log_space_usage;

-- 5. Memoria del proceso SQL Server; corresponde a toda la instancia.
SELECT CAST(physical_memory_in_use_kb / 1024.0 AS DECIMAL(18,2)) AS Memoria_En_Uso_MB,
       CAST(large_page_allocations_kb / 1024.0 AS DECIMAL(18,2)) AS Paginas_Grandes_MB,
       memory_utilization_percentage AS Porcentaje_Memoria_Comprometida_En_RAM,
       process_physical_memory_low AS Alerta_Memoria_Baja
FROM sys.dm_os_process_memory;

/*
 PLAN DE OPTIMIZACION: completar con las salidas obtenidas.
 - Indices: registrar indice, porcentaje y paginas. Como orientacion del
   laboratorio, evaluar REORGANIZE con >10 a 30 % y REBUILD con >30 %.
   Justificar segun tamano, consultas afectadas y costo; no son reglas automaticas.
   Si aparece HEAP, no corresponde aplicar ALTER INDEX a esa fila.
 - Archivos: justificar el autocrecimiento segun el tamano y crecimiento real.
 - Espacio: proponer SHRINKFILE solo ante espacio sobrante permanente;
   no como mantenimiento rutinario, porque puede fragmentar y volver a crecer.
 - RAM: justificar cualquier cambio de memoria con muestras de carga y limites
   del host/contenedor. El porcentaje mostrado no es el uso de RAM total del host.
 Para cada propuesta anotar la metrica observada, accion, motivo y riesgo.
*/
