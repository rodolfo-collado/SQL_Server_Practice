-- =========================================
-- Práctica particionamiento regional
-- =========================================

-- 1. Abre BD_REGION_1 en mssql-dev y prueba el vínculo con mssql-lab.
USE BD_REGION_1;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @EstadoVinculo INT;
EXEC @EstadoVinculo = master.dbo.sp_testlinkedserver N'SERVIDOR_REGION3';

DROP TABLE IF EXISTS #DiagnosticoRegional;

-- 2. Cuenta filas por región y mes, y comprueba que DIA sea una fecha válida.
SELECT Region, DIA / 100 AS Periodo, COUNT_BIG(*) AS Filas,
       MIN(DIA) AS PrimerDia, MAX(DIA) AS UltimoDia,
       SUM(CONVERT(BIGINT, CASE
           WHEN DIA NOT BETWEEN 10000101 AND 99991231
             OR TRY_CONVERT(DATE, CONVERT(VARCHAR(11), DIA), 112) IS NULL THEN 1
           ELSE 0
       END)) AS FechasInvalidas
INTO #DiagnosticoRegional
FROM
(
    SELECT 'BD_REGION_1' AS Region, DIA FROM dbo.CONSUMO_REGIONAL
    UNION ALL
    SELECT 'BD_REGION_2', DIA FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
    UNION ALL
    SELECT 'BD_REGION_3', DIA FROM [SERVIDOR_REGION3].[BD_REGION_3].dbo.CONSUMO_REGIONAL
) AS Origen
GROUP BY Region, DIA / 100;

-- 3. Muestra los totales, las fechas y los meses de cada región. El código 0 del vínculo indica éxito.
SELECT Region, SUM(Filas) AS Filas, MIN(PrimerDia) AS PrimerDia, MAX(UltimoDia) AS UltimoDia,
       COUNT(Periodo) AS Meses, SUM(FechasInvalidas) AS FechasInvalidas,
       CASE WHEN Region = 'BD_REGION_3' THEN 'SERVIDOR_REGION3' END AS ServidorVinculado,
       CASE WHEN Region = 'BD_REGION_3' THEN @EstadoVinculo END AS EstadoVinculo
FROM #DiagnosticoRegional
GROUP BY Region
ORDER BY Region;

-- 4. Muestra los meses presentes en las tres fuentes y su total de filas.
SELECT Periodo, SUM(Filas) AS Filas
FROM #DiagnosticoRegional
GROUP BY Periodo
ORDER BY Periodo;

-- 5. Define junio, julio y agosto en PRIMARY. DIA permite filtrar por rangos y RANGE RIGHT incluye cada límite en la partición siguiente.
IF EXISTS (SELECT 1 FROM #DiagnosticoRegional WHERE FechasInvalidas > 0)
    THROW 50001, 'Los orígenes contienen fechas DIA inválidas.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'pf_TraficoMes')
    CREATE PARTITION FUNCTION pf_TraficoMes (INT)
    AS RANGE RIGHT FOR VALUES (20260601, 20260701, 20260801, 20260901);

IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = N'ps_TraficoMes')
    CREATE PARTITION SCHEME ps_TraficoMes
    AS PARTITION pf_TraficoMes ALL TO ([PRIMARY]);

-- 6. Muestra la función, el esquema y el inicio de cada partición con límite inferior.
SELECT f.name AS Funcion, s.name AS Esquema, f.fanout AS TotalParticiones,
       CASE WHEN f.boundary_value_on_right = 1 THEN 'RANGE RIGHT' ELSE 'RANGE LEFT' END AS TipoRango,
       r.boundary_id + 1 AS Particion, CONVERT(INT, r.value) AS InicioIncluido
FROM sys.partition_functions AS f
JOIN sys.partition_schemes AS s ON s.function_id = f.function_id
JOIN sys.partition_range_values AS r ON r.function_id = f.function_id
WHERE f.name = N'pf_TraficoMes'
ORDER BY r.boundary_id;

-- 7. Crea la tabla consolidada con los mismos tipos de origen, particionada por DIA.
IF OBJECT_ID(N'dbo.CONSUMO_TRAFICO_PART', N'U') IS NULL
    CREATE TABLE dbo.CONSUMO_TRAFICO_PART
    (
        ABONADO  BIGINT NULL,
        TRAMO    INT NULL,
        LNEGOCIO VARCHAR(20) NULL,
        SEGMENTO VARCHAR(10) NULL,
        DIA      INT NULL,
        ANTENA   INT NULL,
        ZONA     VARCHAR(50) NULL,
        EVENTOS  INT NULL,
        MB       DECIMAL(18, 2) NULL,
        MINUTOS  DECIMAL(18, 2) NULL,
        INGRESO  DECIMAL(18, 3) NULL
    ) ON ps_TraficoMes(DIA);

-- 8. Recarga la tabla de práctica con todas las filas de los tres orígenes.
DECLARE @FilasOrigen BIGINT = (SELECT SUM(Filas) FROM #DiagnosticoRegional);

BEGIN TRANSACTION;

TRUNCATE TABLE dbo.CONSUMO_TRAFICO_PART;

INSERT INTO dbo.CONSUMO_TRAFICO_PART
    (ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO)
SELECT ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO
FROM dbo.CONSUMO_REGIONAL
UNION ALL
SELECT ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO
FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO
FROM [SERVIDOR_REGION3].[BD_REGION_3].dbo.CONSUMO_REGIONAL;

IF ROWCOUNT_BIG() <> @FilasOrigen
    THROW 50002, 'El total cargado difiere del total de los orígenes.', 1;

COMMIT TRANSACTION;

-- 9. Muestra una muestra de filas de la tabla particionada.
SELECT TOP (10) *
FROM dbo.CONSUMO_TRAFICO_PART;

-- 10. Compara el número de filas cargadas con el total de los orígenes.
SELECT @FilasOrigen AS FilasOrigen, COUNT_BIG(*) AS FilasCargadas,
       COUNT_BIG(*) - @FilasOrigen AS Diferencia
FROM dbo.CONSUMO_TRAFICO_PART;

DROP TABLE #DiagnosticoRegional;

-- 11. Cuenta las filas por partición y las compara con el catálogo, incluidas las particiones vacías.
WITH FilasPorParticion AS
(
    SELECT $PARTITION.pf_TraficoMes(DIA) AS Particion, COUNT_BIG(*) AS Filas
    FROM dbo.CONSUMO_TRAFICO_PART
    GROUP BY $PARTITION.pf_TraficoMes(DIA)
)
SELECT p.partition_number AS Particion, COALESCE(f.Filas, 0) AS Filas, p.rows AS FilasCatalogo
FROM sys.partitions AS p
LEFT JOIN FilasPorParticion AS f ON f.Particion = p.partition_number
WHERE p.object_id = OBJECT_ID(N'dbo.CONSUMO_TRAFICO_PART') AND p.index_id = 0
ORDER BY p.partition_number;

-- 12. Muestra los totales de MB e ingresos por mes y zona.
SELECT DIA / 100 AS Periodo, ZONA, SUM(MB) AS TotalMB, SUM(INGRESO) AS TotalIngreso
FROM dbo.CONSUMO_TRAFICO_PART
GROUP BY DIA / 100, ZONA
ORDER BY Periodo, ZONA;

-- 13. Activa los planes reales para comparar las particiones leídas.
SET STATISTICS XML ON;

-- 14. Calcula el consumo de julio con un filtro directo por DIA.
SELECT COUNT_BIG(*) AS Filas, SUM(MB) AS TotalMB, SUM(INGRESO) AS TotalIngreso
FROM dbo.CONSUMO_TRAFICO_PART
WHERE DIA >= 20260701 AND DIA < 20260801
OPTION (RECOMPILE, USE HINT('DISALLOW_BATCH_MODE'));

-- 15. Calcula el consumo de todos los meses para comparar con el plan anterior.
SELECT COUNT_BIG(*) AS Filas, SUM(MB) AS TotalMB, SUM(INGRESO) AS TotalIngreso
FROM dbo.CONSUMO_TRAFICO_PART
OPTION (RECOMPILE, USE HINT('DISALLOW_BATCH_MODE'));
SET STATISTICS XML OFF;
GO
