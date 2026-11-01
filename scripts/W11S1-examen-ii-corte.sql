-- ===========================================================================================
-- Creación de la base de datos PAGOS
-- ===========================================================================================

USE master;

IF DB_ID(N'PAGOS') IS NOT NULL
    BEGIN
        DROP DATABASE PAGOS;
    END

EXEC (N'CREATE DATABASE PAGOS');

-- ===========================================================================================
-- Crear tabla PAGOS
-- ===========================================================================================

USE PAGOS;

IF OBJECT_ID('dbo.PAGOS', 'U') IS NOT NULL
    BEGIN
        DROP TABLE PAGOS;
    END

IF OBJECT_ID('dbo.PAGOS', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PAGOS
        (
            MES         CHAR(8)        NOT NULL,
            CTE         VARCHAR(30)    NOT NULL,
            TIPO_DOC    VARCHAR(30)    NOT NULL,
            FORMA_P     VARCHAR(40)    NOT NULL,
            IMPORTEPAGO DECIMAL(18, 4) NOT NULL
        );
    END;

-- ===========================================================================================
-- Inserción de datos mediante BULK INSERT
-- ===========================================================================================

BULK INSERT dbo.PAGOS
    FROM '/var/opt/mssql/bulk-inserts/PAGOS_JULIO.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

BULK INSERT dbo.PAGOS
    FROM '/var/opt/mssql/bulk-inserts/PAGOS_AGOSTO.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

BULK INSERT dbo.PAGOS
    FROM '/var/opt/mssql/bulk-inserts/PAGOS_Septiembre.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

-- ===========================================================================================
-- Bloque 1: Auditoría, Metadatos y Parámetros Críticos
-- ===========================================================================================

-- Ejecutar desde aquí si la base y los BULK INSERT ya están preparados.
USE PAGOS;
GO

-- 1.1: Crear una vista y consultar los objetos que dependen de dbo.PAGOS.
CREATE OR ALTER VIEW dbo.vw_Pagos
AS
SELECT MES, CTE, TIPO_DOC, FORMA_P, IMPORTEPAGO
FROM dbo.PAGOS;


SELECT DISTINCT SCHEMA_NAME(o.schema_id) AS Esquema,
                o.name                   AS Objeto,
                o.type_desc              AS Tipo
FROM sys.sql_expression_dependencies AS d
         INNER JOIN sys.objects AS o ON o.object_id = d.referencing_id
WHERE d.referenced_id = OBJECT_ID('dbo.PAGOS')
  AND o.type IN ('V', 'FN', 'IF', 'TF', 'P');


-- 1.2: Crear el índice si no existe, comprobarlo y revisar su fragmentación.
IF NOT EXISTS (SELECT 1
               FROM sys.indexes
               WHERE object_id = OBJECT_ID('dbo.PAGOS')
                 AND name = 'IX_PAGOS_MES_CTE')
CREATE INDEX IX_PAGOS_MES_CTE ON dbo.PAGOS (MES, CTE);

SELECT name AS Indice, type_desc AS Tipo
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.PAGOS')
  AND index_id > 0;

SELECT i.name                         AS Indice,
       f.page_count                   AS Paginas,
       f.avg_fragmentation_in_percent AS PorcentajeFragmentacion
FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID('dbo.PAGOS'), NULL, NULL, 'LIMITED') AS f
         INNER JOIN sys.indexes AS i
                    ON i.object_id = f.object_id AND i.index_id = f.index_id
WHERE i.index_id > 0;
-- Solo se consulta: el porcentaje por sí solo no justifica reconstruir el índice.
GO

-- 1.3: Tamaño, espacio usado y libre de los archivos de datos, en MB.
SELECT name                                             AS Archivo,
       physical_name                                    AS Ruta,
       size / 128.0                                     AS TamanoMB,
       FILEPROPERTY(name, 'SpaceUsed') / 128.0          AS UsadoMB,
       (size - FILEPROPERTY(name, 'SpaceUsed')) / 128.0 AS LibreMB
FROM sys.database_files
WHERE type_desc = 'ROWS';

-- El log se mide por separado, a nivel de toda la base.
SELECT total_log_size_in_bytes / 1048576.0                             AS TamanoLogMB,
       used_log_space_in_bytes / 1048576.0                             AS UsadoLogMB,
       (total_log_size_in_bytes - used_log_space_in_bytes) / 1048576.0 AS LibreLogMB
FROM sys.dm_db_log_space_usage;

-- ===========================================================================================
-- Bloque 2: DDL Idempotente y Diccionario de Datos
-- ===========================================================================================

-- 2.1: Crear la tabla únicamente si no existe, con los tipos de la guía.
IF OBJECT_ID('dbo.PAGOS', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.PAGOS
        (
            MES         CHAR(8)        NOT NULL,
            CTE         VARCHAR(30)    NOT NULL,
            TIPO_DOC    VARCHAR(30)    NOT NULL,
            FORMA_P     VARCHAR(40)    NOT NULL,
            IMPORTEPAGO DECIMAL(18, 4) NOT NULL
        );
        PRINT 'Tabla dbo.PAGOS creada.';
    END
ELSE
    PRINT 'La tabla dbo.PAGOS ya existe.';

-- 2.2: Agregar la descripción solo si todavía no existe.
IF NOT EXISTS (SELECT 1
               FROM sys.extended_properties
               WHERE class = 1
                 AND major_id = OBJECT_ID('dbo.PAGOS')
                 AND minor_id = COLUMNPROPERTY(OBJECT_ID('dbo.PAGOS'), 'IMPORTEPAGO', 'ColumnId')
                 AND name = 'MS_Description')
    BEGIN
        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Importe del pago con cuatro posiciones decimales.',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'TABLE', @level1name = N'PAGOS',
             @level2type = N'COLUMN', @level2name = N'IMPORTEPAGO';
    END;

SELECT t.name                           AS Tabla,
       c.name                           AS Columna,
       ty.name                          AS Tipo,
       c.max_length                     AS LongitudBytes,
       c.precision                      AS Precision,
       c.scale                          AS Escala,
       c.is_nullable                    AS PermiteNulos,
       CAST(ep.value AS NVARCHAR(4000)) AS Descripcion
FROM sys.tables AS t
         INNER JOIN sys.columns AS c ON c.object_id = t.object_id
         INNER JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
         LEFT JOIN sys.extended_properties AS ep
                   ON ep.class = 1 AND ep.major_id = c.object_id
                       AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
WHERE t.object_id = OBJECT_ID('dbo.PAGOS')
ORDER BY c.column_id;

-- ===========================================================================================
-- Bloque 3: Funciones Definidas por el Usuario
-- ===========================================================================================

-- 3.1: Clasificación del importe individual.
CREATE OR ALTER FUNCTION dbo.ufn_ClasificarImportePago(@Importe DECIMAL(18, 4))
    RETURNS VARCHAR(10)
    WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
               WHEN @Importe >= 20 THEN 'ALTO'
               WHEN @Importe >= 10 THEN 'MEDIO'
               ELSE 'BAJO' END;
END;

SELECT TOP (20) MES,
                CTE,
                IMPORTEPAGO,
                dbo.ufn_ClasificarImportePago(IMPORTEPAGO) AS Clasificacion
FROM dbo.PAGOS;

-- 3.2: Función de tabla en línea; MES se compara como texto AAAAMMDD.
CREATE OR ALTER FUNCTION dbo.ufn_ObtenerPagosPorForma(
    @FormaPago VARCHAR(40), @MesInicial CHAR(8), @MesFinal CHAR(8)
)
    RETURNS TABLE
        AS
        RETURN(SELECT MES, CTE, TIPO_DOC, FORMA_P, IMPORTEPAGO
               FROM dbo.PAGOS
               WHERE FORMA_P = @FormaPago
                 AND MES BETWEEN @MesInicial AND @MesFinal);

SELECT TOP (20) p.MES, p.CTE, p.TIPO_DOC, p.FORMA_P, p.IMPORTEPAGO
FROM (VALUES ('DESCONOCIDO'), ('SUCURSAL'), ('DEBITO_AUT')) AS formas(FormaPago)
         CROSS APPLY dbo.ufn_ObtenerPagosPorForma(formas.FormaPago, '20260701', '20260930') AS p;

-- 3.3: Función multisentencia. Umbrales sobre el total:
-- ALTO >= 20, MEDIO >= 10 y BAJO < 10. Sin pagos, cantidad y total son cero.
CREATE OR ALTER FUNCTION dbo.ufn_ResumenPagosCliente(@CTE VARCHAR(30))
    RETURNS @Resumen TABLE
                     (
                         CantidadRegistros INT,
                         TotalPagado       DECIMAL(38, 4),
                         Clasificacion     VARCHAR(10)
                     )
AS
BEGIN
    INSERT INTO @Resumen (CantidadRegistros, TotalPagado, Clasificacion)
    SELECT COUNT(*),
           COALESCE(SUM(IMPORTEPAGO), 0),
           CASE
               WHEN COALESCE(SUM(IMPORTEPAGO), 0) >= 20 THEN 'ALTO'
               WHEN COALESCE(SUM(IMPORTEPAGO), 0) >= 10 THEN 'MEDIO'
               ELSE 'BAJO' END
    FROM dbo.PAGOS
    WHERE CTE = @CTE;

    RETURN;
END;

SELECT *
FROM dbo.ufn_ResumenPagosCliente('7010790629');

-- ===========================================================================================
-- Bloque 4: Procedimientos Almacenados y transacciones
-- ===========================================================================================

-- 4.1: Registrar un pago y devolver la cantidad de filas insertadas.
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPago @MES CHAR(8),
                                                @CTE VARCHAR(30),
                                                @TIPO_DOC VARCHAR(30),
                                                @FORMA_P VARCHAR(40),
                                                @IMPORTEPAGO DECIMAL(18, 4),
                                                @FilasInsertadas INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @FilasInsertadas = 0;

    BEGIN TRY
        IF @IMPORTEPAGO IS NULL OR @IMPORTEPAGO <= 0
            THROW 50001, 'El importe del pago debe ser positivo.', 1;

        BEGIN TRANSACTION;
        INSERT INTO dbo.PAGOS (MES, CTE, TIPO_DOC, FORMA_P, IMPORTEPAGO)
        VALUES (@MES, @CTE, @TIPO_DOC, @FORMA_P, @IMPORTEPAGO);

        SET @FilasInsertadas = @@ROWCOUNT;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @FilasInsertadas = 0;
        THROW;
    END CATCH;
END;

-- 4.2: Eliminar únicamente una coincidencia exacta de los cinco campos.
-- No se puede actualizar EstadoPago porque esa columna no existe.
-- Sin clave primaria, dos filas idénticas no se distinguen. Si el DELETE
-- afecta más de una fila, se revierte todo; una clave técnica evitaría la ambigüedad.
CREATE OR ALTER PROCEDURE dbo.usp_EliminarPagoLaboratorio @MES CHAR(8),
                                                          @CTE VARCHAR(30),
                                                          @TIPO_DOC VARCHAR(30),
                                                          @FORMA_P VARCHAR(40),
                                                          @IMPORTEPAGO DECIMAL(18, 4)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @FilasEliminadas INT;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE
        FROM dbo.PAGOS
        WHERE MES = @MES
          AND CTE = @CTE
          AND TIPO_DOC = @TIPO_DOC
          AND FORMA_P = @FORMA_P
          AND IMPORTEPAGO = @IMPORTEPAGO;

        SET @FilasEliminadas = @@ROWCOUNT;
        IF @FilasEliminadas <> 1
            THROW 50002, 'Se esperaba un solo pago de prueba; se revierte la eliminacion.', 1;

        COMMIT TRANSACTION;
        SELECT @FilasEliminadas AS FilasEliminadas;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

-- Prueba de ambos procedimientos con un cliente ficticio.
-- La transacción externa se revierte para no conservar cambios de la prueba.
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Filas INT;

    EXEC dbo.usp_RegistrarPago
         @MES = '20260930', @CTE = 'PRUEBA_GUIA_SQL', @TIPO_DOC = 'PRUEBA',
         @FORMA_P = 'SUCURSAL', @IMPORTEPAGO = 15,
         @FilasInsertadas = @Filas OUTPUT;

    SELECT @Filas AS FilasInsertadas;

    EXEC dbo.usp_EliminarPagoLaboratorio
         @MES = '20260930', @CTE = 'PRUEBA_GUIA_SQL', @TIPO_DOC = 'PRUEBA',
         @FORMA_P = 'SUCURSAL', @IMPORTEPAGO = 15;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- 4.3: Auditoría de las funciones y procedimientos creados en la guía.
-- parameter_id = 0 identifica el retorno de la función escalar.
SELECT SCHEMA_NAME(o.schema_id)                                      AS Esquema,
       o.name                                                        AS Objeto,
       o.type_desc                                                   AS TipoObjeto,
       p.parameter_id                                                AS Orden,
       CASE WHEN p.parameter_id = 0 THEN '(RETORNO)' ELSE p.name END AS Parametro,
       ty.name                                                       AS TipoDato,
       p.max_length                                                  AS LongitudBytes,
       p.precision                                                   AS Precision,
       p.scale                                                       AS Escala,
       p.is_output                                                   AS EsSalida
FROM sys.objects AS o
         LEFT JOIN sys.parameters AS p ON p.object_id = o.object_id
         LEFT JOIN sys.types AS ty ON ty.user_type_id = p.user_type_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('FN', 'IF', 'TF', 'P')
  AND o.schema_id = SCHEMA_ID('dbo')
  AND o.name IN ('ufn_ClasificarImportePago', 'ufn_ObtenerPagosPorForma',
                 'ufn_ResumenPagosCliente', 'usp_RegistrarPago', 'usp_EliminarPagoLaboratorio')
ORDER BY o.name, p.parameter_id;
