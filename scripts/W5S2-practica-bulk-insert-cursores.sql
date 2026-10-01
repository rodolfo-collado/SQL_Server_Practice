-- =============================================
-- === 1. Crear la base de datos de práctica ===
-- =============================================

IF DB_ID(N'Practica_Bulk_Cursores') IS NULL
    BEGIN
        EXEC (N'CREATE DATABASE Practica_Bulk_Cursores');
    END

USE Practica_Bulk_Cursores;

-- ==============================================
-- === 2. Crear la tabla de consumo de abonos ===
-- ==============================================

CREATE TABLE CONSUMO_ABONOS
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

BULK INSERT dbo.CONSUMO_ABONOS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/trfJunio26.txt'
    WITH
    (
    FIRSTROW = 2, -- Indica que empieza en la segunda línea
    FIELDTERMINATOR = '|', -- Indica el separador de cada columna
    ROWTERMINATOR = '0x0a', -- Indica que cada registro termina con un salto de línea
--  CODEPAGE = '65001', -- Indica la codificación (UTF-8) de cada archivo. En linux no es necesario
    TABLOCK -- Solicita un bloqueo de tabla durante la ejecición
    )

BULK INSERT dbo.CONSUMO_ABONOS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/trfJulio26.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
--  CODEPAGE = '65001',
    TABLOCK
    )

BULK INSERT dbo.CONSUMO_ABONOS
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
FROM dbo.CONSUMO_ABONOS;


SELECT COUNT(*) AS TOTAL_REGISTRADOS
FROM dbo.CONSUMO_ABONOS;


SELECT MIN(DIA)            AS PRIMER_DIA,
       MAX(DIA)            AS ULTIMO_DIA,
       COUNT(DISTINCT DIA) AS DIAS,
       SUM(MB)             AS TOTAL_MB,
       SUM(INGRESO)        AS TOTAL_INGRESO
FROM dbo.CONSUMO_ABONOS;

-- ====================================
-- === 5. Crear la tabla segmentada ===
-- ====================================

CREATE TABLE dbo.CONSUMO_ABONOS_SEGMENTADO
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
    FROM dbo.CONSUMO_ABONOS;

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

        INSERT INTO dbo.CONSUMO_ABONOS_SEGMENTADO
        (ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA,
         ANTENA, EVENTOS, MB, MINUTOS, INGRESO, TIPO_CONSUMO)
        VALUES (@ABONADO, @TRAMO, @LNEGOCIO, @SEGMENTO, @DIA,
                @ANTENA, @EVENTOS, @MB, @MINUTOS, @INGRESO, @TIPO_CONSUMO);

        FETCH NEXT FROM CURSOR_CONSUMO
            INTO
                @ABONADO, @TRAMO, @LNEGOCIO, @SEGMENTO, @DIA,
                @ANTENA, @EVENTOS, @MB, @MINUTOS, @INGRESO;
    END;

CLOSE CURSOR_CONSUMO;
DEALLOCATE CURSOR_CONSUMO;

-- ===============================
-- === 7. Validar el resultado ===
-- ===============================

SELECT TIPO_CONSUMO,
       COUNT(*)     AS CANTIDAD_REGISTROS,
       SUM(MB)      AS TOTAL_MB,
       SUM(INGRESO) AS TOTAL_INGRESO
FROM dbo.CONSUMO_ABONOS_SEGMENTADO
GROUP BY TIPO_CONSUMO
ORDER BY TOTAL_MB DESC;

-- ============================================
-- == 8. Crear tabla RESUMEN_CONSUMO_DIARIO ===
-- ============================================

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

DECLARE
    @DIA INT,
    @FECHA DATE,
    @CANTIDAD_ABONADOS INT,
    @TOTAL_MB DECIMAL(19, 2),
    @PROMEDIO_MB DECIMAL(19, 2),
    @TOTAL_MINUTOS DECIMAL(19, 2),
    @TOTAL_EVENTOS INT,
    @TOTAL_INGRESO DECIMAL(19, 4);

DECLARE CURSOR_DIAS CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT DIA
    FROM dbo.CONSUMO_ABONOS
    ORDER BY DIA;

OPEN CURSOR_DIAS;

FETCH NEXT FROM CURSOR_DIAS INTO @DIA;

WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FECHA =
                TRY_CONVERT(DATE, CONVERT(CHAR(8), @DIA), 112);

        SELECT @CANTIDAD_ABONADOS = COUNT(DISTINCT ABONADO),
               @TOTAL_MB = SUM(ISNULL(MB, 0)),
               @PROMEDIO_MB = AVG(ISNULL(MB, 0)),
               @TOTAL_MINUTOS = SUM(ISNULL(MINUTOS, 0)),
               @TOTAL_EVENTOS = SUM(ISNULL(EVENTOS, 0)),
               @TOTAL_INGRESO = SUM(ISNULL(INGRESO, 0))
        FROM dbo.CONSUMO_ABONOS
        WHERE DIA = @DIA;

        INSERT INTO dbo.RESUMEN_CONSUMO_DIARIO
        VALUES (@DIA, @FECHA, @CANTIDAD_ABONADOS,
                @TOTAL_MB, @PROMEDIO_MB, @TOTAL_MINUTOS,
                @TOTAL_EVENTOS, @TOTAL_INGRESO);

        FETCH NEXT FROM CURSOR_DIAS INTO @DIA;
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
    @DIA INT,
    @FECHA DATE,
    @TOTAL_MB DECIMAL(19, 2),
    @TOTAL_MB_ANTERIOR DECIMAL(19, 2),
    @VARIACION_MB DECIMAL(19, 2),
    @VARIACION_PORC DECIMAL(19, 4),
    @COMPORTAMIENTO VARCHAR(20);

DECLARE CURSOR_COMPARATIVO CURSOR LOCAL FAST_FORWARD FOR
    SELECT DIA, FECHA, TOTAL_MB
    FROM dbo.RESUMEN_CONSUMO_DIARIO
    ORDER BY DIA;

SET @TOTAL_MB_ANTERIOR = NULL;

OPEN CURSOR_COMPARATIVO;

FETCH NEXT FROM CURSOR_COMPARATIVO
    INTO @DIA, @FECHA, @TOTAL_MB;

WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @TOTAL_MB_ANTERIOR IS NULL
            BEGIN
                SET @VARIACION_MB = NULL;
                SET @VARIACION_PORC = NULL;
                SET @COMPORTAMIENTO = 'PRIMER DIA';
            END
        ELSE
            BEGIN
                SET @VARIACION_MB = @TOTAL_MB - @TOTAL_MB_ANTERIOR;

                IF @TOTAL_MB_ANTERIOR = 0
                    SET @VARIACION_PORC = NULL;
                ELSE
                    SET @VARIACION_PORC =
                            (@VARIACION_MB * 100.0) / @TOTAL_MB_ANTERIOR;

                IF @VARIACION_MB > 0
                    SET @COMPORTAMIENTO = 'AUMENTO';
                ELSE
                    IF @VARIACION_MB < 0
                        SET @COMPORTAMIENTO = 'DISMINUCION';
                    ELSE
                        SET @COMPORTAMIENTO = 'SIN CAMBIO';
            END;

        INSERT INTO dbo.COMPARATIVO_CONSUMO_DIARIO
        VALUES (@DIA, @FECHA, @TOTAL_MB, @TOTAL_MB_ANTERIOR,
                @VARIACION_MB, @VARIACION_PORC, @COMPORTAMIENTO);

        SET @TOTAL_MB_ANTERIOR = @TOTAL_MB;

        FETCH NEXT FROM CURSOR_COMPARATIVO
            INTO @DIA, @FECHA, @TOTAL_MB;
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

SELECT name,
       data_source,
       is_linked
FROM master.sys.servers;

EXEC master.dbo.sp_testlinkedserver
     N'SRV_UAM_DISTRIBUIDO';