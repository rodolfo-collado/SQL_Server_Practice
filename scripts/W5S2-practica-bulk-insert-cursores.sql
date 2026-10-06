-- =============================================
-- === 1. Crear la base de datos de práctica ===
-- =============================================

IF DB_ID(N'Practica_Bulk_Cursores') IS NULL
    BEGIN
        EXEC (N'CREATE DATABASE Practica_Bulk_Cursores');
    END

USE Practica_Bulk_Cursores;

SET NOCOUNT ON;

-- ==============================================
-- === 2. Crear la tabla de consumo de abonos ===
-- ==============================================

CREATE TABLE CONSUMO_ABONADOS
(
    ABONADO  BIGINT,
    TRAMO    INT,
    LNEGOCIO VARCHAR(20),
    SEGMENTO VARCHAR(10),
    DIA      INT,
    ANTENA   INT,
    EVENTOS  INT,
    MB       DECIMAL(19, 2),
    MINUTOS  DECIMAL(19, 2),
    INGRESO  DECIMAL(19, 3)
)

-- =====================================
-- === 3. Carga mediante BULK INSERT ===
-- =====================================

BULK INSERT dbo.CONSUMO_ABONADOS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/trfJunio26.txt'
    WITH
    (
    FIRSTROW = 2, -- Indica que empieza en la segunda línea
    FIELDTERMINATOR = '|', -- Indica el separador de cada columna
    ROWTERMINATOR = '0x0a', -- Indica que cada registro termina con un salto de línea
--  CODEPAGE = '65001', -- Indica la codificación (UTF-8) de cada archivo. En linux no es necesario
    TABLOCK -- Solicita un bloqueo de tabla durante la ejecición
    )

BULK INSERT dbo.CONSUMO_ABONADOS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/trfJulio26.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

BULK INSERT dbo.CONSUMO_ABONADOS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/trfAgosto26.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

-- ====================================
-- === 4. Validar la carga de datos ===
-- ====================================

SELECT TOP 20 *
FROM dbo.CONSUMO_ABONADOS;


SELECT COUNT(*) AS TOTAL_REGISTRADOS
FROM dbo.CONSUMO_ABONADOS;


SELECT MIN(DIA)            AS PRIMER_DIA,
       MAX(DIA)            AS ULTIMO_DIA,
       COUNT(DISTINCT DIA) AS DIAS,
       SUM(MB)             AS TOTAL_MB,
       SUM(INGRESO)        AS TOTAL_INGRESO
FROM dbo.CONSUMO_ABONADOS;

-- ====================================
-- === 5. Crear la tabla segmentada ===
-- ====================================

CREATE TABLE dbo.CONSUMO_ABONADOS_SEGMENTADO
(
    ABONADO      BIGINT,
    TRAMO        INT,
    LNEGOCIO     VARCHAR(20),
    SEGMENTO     VARCHAR(10),
    DIA          INT,
    ANTENA       INT,
    EVENTOS      INT,
    MB           DECIMAL(19, 2),
    MINUTOS      DECIMAL(19, 2),
    INGRESO      DECIMAL(19, 4),
    TIPO_CONSUMO VARCHAR(30)
)

-- ==========================================
-- === 6. Ejecutar cursor de segmentación ===
-- ==========================================
-- El cursor clasifica fila por fila, pero escribe en la tabla destino
-- por lotes de 10,000 para reducir el costo de 1,570,494 INSERT individuales.

DECLARE
    @ABONADO BIGINT,
    @TRAMO INT,
    @LNEGOCIO VARCHAR(20),
    @SEGMENTO VARCHAR(10),
    @DIA INT,
    @ANTENA INT,
    @EVENTOS INT,
    @MB DECIMAL(19, 2),
    @MINUTOS DECIMAL(19, 2),
    @INGRESO DECIMAL(19, 4),
    @TIPO_CONSUMO VARCHAR(30);

DECLARE @LOTE TABLE
              (
                  ABONADO      BIGINT,
                  TRAMO        INT,
                  LNEGOCIO     VARCHAR(20),
                  SEGMENTO     VARCHAR(10),
                  DIA          INT,
                  ANTENA       INT,
                  EVENTOS      INT,
                  MB           DECIMAL(19, 2),
                  MINUTOS      DECIMAL(19, 2),
                  INGRESO      DECIMAL(19, 4),
                  TIPO_CONSUMO VARCHAR(30)
              );

DECLARE @FILAS_LOTE INT = 0,
    @FILAS_TOTAL BIGINT = 0;

DECLARE CURSOR_CONSUMO CURSOR LOCAL FAST_FORWARD FOR
    SELECT ABONADO,
           TRAMO,
           LNEGOCIO,
           SEGMENTO,
           DIA,
           ANTENA,
           EVENTOS,
           MB,
           MINUTOS,
           INGRESO
    FROM dbo.CONSUMO_ABONADOS;

OPEN CURSOR_CONSUMO;

FETCH NEXT FROM CURSOR_CONSUMO
    INTO
        @ABONADO, @TRAMO, @LNEGOCIO, @SEGMENTO, @DIA,
        @ANTENA, @EVENTOS, @MB, @MINUTOS, @INGRESO;

WHILE @@FETCH_STATUS = 0
    BEGIN
        IF ISNULL(@MB, 0) = 0
            SET @TIPO_CONSUMO = 'SIN CONSUMO';
        ELSE
            IF @MB <= 100
                SET @TIPO_CONSUMO = 'CONSUMO BAJO';
            ELSE
                IF @MB <= 1000
                    SET @TIPO_CONSUMO = 'CONSUMO MEDIO';
                ELSE
                    SET @TIPO_CONSUMO = 'CONSUMO ALTO';

        INSERT INTO @LOTE
        (ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA,
         ANTENA, EVENTOS, MB, MINUTOS, INGRESO, TIPO_CONSUMO)
        VALUES (@ABONADO, @TRAMO, @LNEGOCIO, @SEGMENTO, @DIA,
                @ANTENA, @EVENTOS, @MB, @MINUTOS, @INGRESO, @TIPO_CONSUMO);

        SET @FILAS_LOTE += 1;
        SET @FILAS_TOTAL += 1;

        IF @FILAS_LOTE = 10000
            BEGIN
                INSERT INTO dbo.CONSUMO_ABONADOS_SEGMENTADO
                (ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA,
                 ANTENA, EVENTOS, MB, MINUTOS, INGRESO, TIPO_CONSUMO)
                SELECT ABONADO,
                       TRAMO,
                       LNEGOCIO,
                       SEGMENTO,
                       DIA,
                       ANTENA,
                       EVENTOS,
                       MB,
                       MINUTOS,
                       INGRESO,
                       TIPO_CONSUMO
                FROM @LOTE;

                DELETE FROM @LOTE;
                SET @FILAS_LOTE = 0;

                RAISERROR (N'Cursor de segmentación: lote de 10,000 filas completado.',
                    10, 1) WITH NOWAIT;
            END;

        FETCH NEXT FROM CURSOR_CONSUMO
            INTO
                @ABONADO, @TRAMO, @LNEGOCIO, @SEGMENTO, @DIA,
                @ANTENA, @EVENTOS, @MB, @MINUTOS, @INGRESO;
    END;

IF EXISTS (SELECT 1
           FROM @LOTE)
    INSERT INTO dbo.CONSUMO_ABONADOS_SEGMENTADO
    (ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA,
     ANTENA, EVENTOS, MB, MINUTOS, INGRESO, TIPO_CONSUMO)
    SELECT ABONADO,
           TRAMO,
           LNEGOCIO,
           SEGMENTO,
           DIA,
           ANTENA,
           EVENTOS,
           MB,
           MINUTOS,
           INGRESO,
           TIPO_CONSUMO
    FROM @LOTE;

CLOSE CURSOR_CONSUMO;
DEALLOCATE CURSOR_CONSUMO;

-- Verificar que la cantidad de filas sea la misma en ambas tablas

-- Cantidad de datos en CONSUMO_ABONADOS
SELECT COUNT_BIG(*)
FROM dbo.CONSUMO_ABONADOS;

-- Cantidad de datos en CONSUMO_ABONADOS_SEGMENTADO
SELECT COUNT_BIG(*)
FROM dbo.CONSUMO_ABONADOS_SEGMENTADO;

-- ===============================
-- === 7. Validar el resultado ===
-- ===============================

SELECT TIPO_CONSUMO,
       COUNT(*)     AS CANTIDAD_REGISTROS,
       SUM(MB)      AS TOTAL_MB,
       SUM(INGRESO) AS TOTAL_INGRESO
FROM dbo.CONSUMO_ABONADOS_SEGMENTADO
GROUP BY TIPO_CONSUMO
ORDER BY TOTAL_MB DESC;

-- ============================================
-- == 8. Crear tabla RESUMEN_CONSUMO_DIARIO ===
-- ============================================

CREATE INDEX IX_CONSUMO_ABONADOS_DIA
    ON dbo.CONSUMO_ABONADOS (DIA)
    INCLUDE (ABONADO, MB, MINUTOS, EVENTOS, INGRESO);

CREATE TABLE dbo.RESUMEN_CONSUMO_DIARIO
(
    DIA               INT,
    FECHA             DATE,
    CANTIDAD_ABONADOS INT,
    TOTAL_MB          DECIMAL(19, 2),
    PROMEDIO_MB       DECIMAL(19, 2),
    TOTAL_MINUTOS     DECIMAL(19, 2),
    TOTAL_EVENTOS     INT,
    TOTAL_INGRESO     DECIMAL(19, 4)
);

-- ==============================================
-- == 9. Ejecutar el cursor de resumen diario ===
-- ==============================================
-- El índice sobre DIA evita un escaneo completo de la tabla por cada día.

DECLARE
    @DIA_RESUMEN INT,
    @FECHA_RESUMEN DATE,
    @CANTIDAD_ABONADOS_RESUMEN INT,
    @TOTAL_MB_RESUMEN DECIMAL(19, 2),
    @PROMEDIO_MB_RESUMEN DECIMAL(19, 2),
    @TOTAL_MINUTOS_RESUMEN DECIMAL(19, 2),
    @TOTAL_EVENTOS_RESUMEN INT,
    @TOTAL_INGRESO_RESUMEN DECIMAL(19, 4);

DECLARE CURSOR_DIAS CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT DIA
    FROM dbo.CONSUMO_ABONADOS
    ORDER BY DIA;

OPEN CURSOR_DIAS;

FETCH NEXT FROM CURSOR_DIAS INTO @DIA_RESUMEN;

WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FECHA_RESUMEN =
                TRY_CONVERT(DATE, CONVERT(CHAR(8), @DIA_RESUMEN), 112);

        SELECT @CANTIDAD_ABONADOS_RESUMEN = COUNT(DISTINCT ABONADO),
               @TOTAL_MB_RESUMEN = SUM(ISNULL(MB, 0)),
               @PROMEDIO_MB_RESUMEN = AVG(ISNULL(MB, 0)),
               @TOTAL_MINUTOS_RESUMEN = SUM(ISNULL(MINUTOS, 0)),
               @TOTAL_EVENTOS_RESUMEN = SUM(ISNULL(EVENTOS, 0)),
               @TOTAL_INGRESO_RESUMEN = SUM(ISNULL(INGRESO, 0))
        FROM dbo.CONSUMO_ABONADOS
        WHERE DIA = @DIA_RESUMEN;

        INSERT INTO dbo.RESUMEN_CONSUMO_DIARIO
        VALUES (@DIA_RESUMEN, @FECHA_RESUMEN, @CANTIDAD_ABONADOS_RESUMEN,
                @TOTAL_MB_RESUMEN, @PROMEDIO_MB_RESUMEN, @TOTAL_MINUTOS_RESUMEN,
                @TOTAL_EVENTOS_RESUMEN, @TOTAL_INGRESO_RESUMEN);

        FETCH NEXT FROM CURSOR_DIAS INTO @DIA_RESUMEN;
    END;

CLOSE CURSOR_DIAS;
DEALLOCATE CURSOR_DIAS;

-- debe producir 92 filas

SELECT *
FROM dbo.RESUMEN_CONSUMO_DIARIO
ORDER BY DIA;

-- =====================================================
-- === 10. Crear tabla de COMPARATIVO_CONSUMO_DIARIO ===
-- =====================================================

CREATE TABLE dbo.COMPARATIVO_CONSUMO_DIARIO
(
    DIA               INT,
    FECHA             DATE,
    TOTAL_MB          DECIMAL(19, 2),
    TOTAL_MB_ANTERIOR DECIMAL(19, 2),
    VARIACION_MB      DECIMAL(19, 2),
    VARIACION_PORC    DECIMAL(19, 4),
    COMPORTAMIENTO    VARCHAR(20)
);

-- =============================================
-- === 11. Comparar cada día con el anterior ===
-- =============================================

DECLARE
    @DIA_COMPARATIVO INT,
    @FECHA_COMPARATIVO DATE,
    @TOTAL_MB_COMPARATIVO DECIMAL(19, 2),
    @TOTAL_MB_ANTERIOR_COMPARATIVO DECIMAL(19, 2),
    @VARIACION_MB_COMPARATIVO DECIMAL(19, 2),
    @VARIACION_PORC_COMPARATIVO DECIMAL(19, 4),
    @COMPORTAMIENTO_COMPARATIVO VARCHAR(20);

DECLARE CURSOR_COMPARATIVO CURSOR LOCAL FAST_FORWARD FOR
    SELECT DIA, FECHA, TOTAL_MB
    FROM dbo.RESUMEN_CONSUMO_DIARIO
    ORDER BY DIA;

SET @TOTAL_MB_ANTERIOR_COMPARATIVO = NULL;

OPEN CURSOR_COMPARATIVO;

FETCH NEXT FROM CURSOR_COMPARATIVO
    INTO @DIA_COMPARATIVO, @FECHA_COMPARATIVO, @TOTAL_MB_COMPARATIVO;

WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @TOTAL_MB_ANTERIOR_COMPARATIVO IS NULL
            BEGIN
                SET @VARIACION_MB_COMPARATIVO = NULL;
                SET @VARIACION_PORC_COMPARATIVO = NULL;
                SET @COMPORTAMIENTO_COMPARATIVO = 'PRIMER DIA';
            END
        ELSE
            BEGIN
                SET @VARIACION_MB_COMPARATIVO =
                        @TOTAL_MB_COMPARATIVO - @TOTAL_MB_ANTERIOR_COMPARATIVO;

                IF @TOTAL_MB_ANTERIOR_COMPARATIVO = 0
                    SET @VARIACION_PORC_COMPARATIVO = NULL;
                ELSE
                    SET @VARIACION_PORC_COMPARATIVO =
                            (@VARIACION_MB_COMPARATIVO * 100.0)
                                / @TOTAL_MB_ANTERIOR_COMPARATIVO;

                IF @VARIACION_MB_COMPARATIVO > 0
                    SET @COMPORTAMIENTO_COMPARATIVO = 'AUMENTO';
                ELSE
                    IF @VARIACION_MB_COMPARATIVO < 0
                        SET @COMPORTAMIENTO_COMPARATIVO = 'DISMINUCION';
                    ELSE
                        SET @COMPORTAMIENTO_COMPARATIVO = 'SIN CAMBIO';
            END;

        INSERT INTO dbo.COMPARATIVO_CONSUMO_DIARIO
        VALUES (@DIA_COMPARATIVO, @FECHA_COMPARATIVO, @TOTAL_MB_COMPARATIVO,
                @TOTAL_MB_ANTERIOR_COMPARATIVO, @VARIACION_MB_COMPARATIVO,
                @VARIACION_PORC_COMPARATIVO, @COMPORTAMIENTO_COMPARATIVO);

        SET @TOTAL_MB_ANTERIOR_COMPARATIVO = @TOTAL_MB_COMPARATIVO;

        FETCH NEXT FROM CURSOR_COMPARATIVO
            INTO @DIA_COMPARATIVO, @FECHA_COMPARATIVO, @TOTAL_MB_COMPARATIVO;
    END;

CLOSE CURSOR_COMPARATIVO;
DEALLOCATE CURSOR_COMPARATIVO;

-- consulta final
SELECT *
FROM dbo.COMPARATIVO_CONSUMO_DIARIO
ORDER BY DIA;

-- =============================
-- === 1. Parte distribuida ===
-- =============================
-- Ejecutar únicamente después de crear el Linked Server
-- SRV_UAM_DISTRIBUIDO en la instancia mssql-dev.


USE master;

SELECT name,
       data_source,
       is_linked
FROM master.sys.servers;

EXEC master.dbo.sp_testlinkedserver
     N'SRV_UAM_DISTRIBUIDO';
