-- 1. Abre la base PAGOS en mssql-dev.
USE [PAGOS]
GO

-- 2. Muestra los importes por mes y tipo de documento en la tabla original.
SELECT LEFT([MES], 6)     AS mes
     , CASE
           WHEN [TIPO_DOC] IN ('NCRED', 'Nota Credito Interna') THEN 'Notas de Credito'
           WHEN [TIPO_DOC] IN ('REGULARIZADO', 'REV_REGULARIZADO') THEN 'Regularizacion'
           ELSE 'Caja' END   Tipo_Documento
     , SUM([IMPORTEPAGO]) AS IMPORTEPAGO
FROM [dbo].[PAGOS]
GROUP BY LEFT([MES], 6),
         CASE
             WHEN [TIPO_DOC] IN ('NCRED', 'Nota Credito Interna') THEN 'Notas de Credito'
             WHEN [TIPO_DOC] IN ('REGULARIZADO', 'REV_REGULARIZADO') THEN 'Regularizacion'
             ELSE 'Caja' END
ORDER BY 1, 2
GO

-- 3. Compara los importes de julio, agosto y septiembre por tipo de documento.
SELECT CASE
           WHEN [TIPO_DOC] IN ('NCRED', 'Nota Credito Interna') THEN 'Notas de Credito'
           WHEN [TIPO_DOC] IN ('REGULARIZADO', 'REV_REGULARIZADO') THEN 'Regularizacion'
           ELSE 'Caja' END                                                       Tipo_Documento,
       SUM(CASE WHEN LEFT([MES], 6) = '202607' THEN [IMPORTEPAGO] ELSE 0 END) AS Julio26,
       SUM(CASE WHEN LEFT([MES], 6) = '202608' THEN [IMPORTEPAGO] ELSE 0 END) AS Agosto26,
       SUM(CASE WHEN LEFT([MES], 6) = '202609' THEN [IMPORTEPAGO] ELSE 0 END) AS Septiembre26
FROM [dbo].[PAGOS]
GROUP BY CASE
             WHEN [TIPO_DOC] IN ('NCRED', 'Nota Credito Interna') THEN 'Notas de Credito'
             WHEN [TIPO_DOC] IN ('REGULARIZADO', 'REV_REGULARIZADO') THEN 'Regularizacion'
             ELSE 'Caja' END
ORDER BY 1, 2
GO

-- 4. Define una partición por mes de julio a noviembre en PRIMARY.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'pf_PagosResumenMes')
    CREATE PARTITION FUNCTION pf_PagosResumenMes (INT)
    AS RANGE RIGHT FOR VALUES (202607, 202608, 202609, 202610, 202611, 202612);

IF NOT EXISTS (SELECT 1 FROM sys.partition_schemes WHERE name = N'ps_PagosResumenMes')
    CREATE PARTITION SCHEME ps_PagosResumenMes
    AS PARTITION pf_PagosResumenMes ALL TO ([PRIMARY]);
GO

-- 5. Crea la tabla de resumen particionada por Mes.
IF OBJECT_ID(N'dbo.PagosResumenMensual', N'U') IS NULL
    CREATE TABLE dbo.PagosResumenMensual
    (
        Mes INT NOT NULL,
        Tipo_Documento VARCHAR(50) NOT NULL,
        MontoPagado DECIMAL(38, 4) NOT NULL,
        CantidadPagos DECIMAL(15, 4) NOT NULL,
        CONSTRAINT PK_PagosResumenMensual PRIMARY KEY (Mes, Tipo_Documento)
    ) ON ps_PagosResumenMes(Mes);
GO

-- 6. Carga el resumen original y repone septiembre para repetir la prueba.
BEGIN TRANSACTION;

DELETE FROM dbo.PagosResumenMensual WHERE Mes = 202609;

WITH PagosClasificados AS
(
    SELECT CONVERT(INT, LEFT(MES, 6)) AS Mes,
           CASE
               WHEN TIPO_DOC IN ('NCRED', 'Nota Credito Interna') THEN 'Notas de Credito'
               WHEN TIPO_DOC IN ('REGULARIZADO', 'REV_REGULARIZADO') THEN 'Regularizacion'
               ELSE 'Caja'
           END AS Tipo_Documento,
           IMPORTEPAGO
    FROM dbo.PAGOS
)
INSERT INTO dbo.PagosResumenMensual (Mes, Tipo_Documento, MontoPagado, CantidadPagos)
SELECT p.Mes, p.Tipo_Documento, SUM(p.IMPORTEPAGO), COUNT_BIG(*)
FROM PagosClasificados AS p
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.PagosResumenMensual AS r
    WHERE r.Mes = p.Mes AND r.Tipo_Documento = p.Tipo_Documento
)
GROUP BY p.Mes, p.Tipo_Documento;

-- 7. Muestra los registros de septiembre antes del truncado.
SELECT Mes, Tipo_Documento, MontoPagado, CantidadPagos,
       $PARTITION.pf_PagosResumenMes(Mes) AS Particion
FROM dbo.PagosResumenMensual
WHERE Mes = 202609
ORDER BY Tipo_Documento;

-- 8. Trunca únicamente la partición 4, que corresponde a septiembre.
TRUNCATE TABLE dbo.PagosResumenMensual WITH (PARTITIONS (4));

-- 9. Comprueba que la partición de septiembre quedó vacía.
SELECT 4 AS Particion, COUNT(*) AS FilasDespuesDelTruncado
FROM dbo.PagosResumenMensual
WHERE Mes = 202609;

-- 10. Importa el TXT del contenedor y agrega las filas de septiembre a noviembre.
DROP TABLE IF EXISTS #PagosPendientes;
CREATE TABLE #PagosPendientes
(
    Mes INT NOT NULL,
    Tipo_Documento VARCHAR(50) NOT NULL,
    MontoPagado DECIMAL(38, 4) NOT NULL,
    CantidadPagos DECIMAL(15, 4) NOT NULL,
    PRIMARY KEY (Mes, Tipo_Documento)
);

BULK INSERT #PagosPendientes
FROM '/var/opt/mssql/backup/PagosPendientes.txt'
WITH (FIRSTROW = 2, FIELDTERMINATOR = '|', ROWTERMINATOR = '0x0d0a',
      MAXERRORS = 0, TABLOCK);

IF NOT EXISTS (SELECT 1 FROM #PagosPendientes WHERE Mes = 202609)
    THROW 50001, 'El archivo no contiene registros de septiembre.', 1;

INSERT INTO dbo.PagosResumenMensual (Mes, Tipo_Documento, MontoPagado, CantidadPagos)
SELECT p.Mes, p.Tipo_Documento, p.MontoPagado, p.CantidadPagos
FROM #PagosPendientes AS p
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.PagosResumenMensual AS r
    WHERE r.Mes = p.Mes AND r.Tipo_Documento = p.Tipo_Documento
);

DROP TABLE #PagosPendientes;
COMMIT TRANSACTION;

-- 11. Muestra el resumen final y la partición de cada fila.
SELECT Mes, Tipo_Documento, MontoPagado, CantidadPagos,
       $PARTITION.pf_PagosResumenMes(Mes) AS Particion
FROM dbo.PagosResumenMensual
ORDER BY Mes, Tipo_Documento;
GO
