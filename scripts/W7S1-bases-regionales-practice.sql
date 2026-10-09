-- =========================================================
-- === 1. Creación de base de datos e inserción de datos ===
-- =========================================================

USE Practica_Bulk_Cursores;
GO


-- Crear la tabla ANTENAS
IF OBJECT_ID('dbo.ANTENAS', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.ANTENAS
        (
            ID_SITIO  INT,
            SITIO     VARCHAR(50),
            DEPTO     VARCHAR(50),
            MUNICIPIO VARCHAR(100),
            ZONA      VARCHAR(50)
        )
    END

-- Insertar datos de Antenas.txt
BULK INSERT dbo.ANTENAS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/Antenas.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
    TABLOCK
    )

-- ==============================
-- === 2. Inspección de datos ===
-- ==============================

-- Todos los datos
SELECT COUNT(*)
FROM dbo.ANTENAS;

-- Sitios diferentes
SELECT COUNT(*)                 AS REGISTROS_CATALOGO,
       COUNT(DISTINCT ID_SITIO) AS SITIOS_DISTINTOS
FROM dbo.ANTENAS;

-- Zonas distintas
SELECT DISTINCT ZONA
FROM dbo.ANTENAS
ORDER BY ZONA;

-- Departamentos distintos
SELECT DISTINCT DEPTO AS DEPARTAMENTOS
FROM dbo.ANTENAS
ORDER BY DEPTO;

-- =================================
-- === 3. Normalización de datos ===
-- =================================

-- Eliminar posibles Carriage Return (\r) de los datos
UPDATE dbo.ANTENAS
SET ZONA = REPLACE(ZONA, CHAR(13), '')

-- Actualizar zonas mal escritas
UPDATE dbo.ANTENAS
SET ZONA =
        CASE
            WHEN ZONA = 'REGIONES AUT?NOMAS' THEN 'REGIONES AUTONOMAS'
            ELSE ZONA
            END;

-- Actualizar departamentos mal escritos
UPDATE dbo.ANTENAS
SET DEPTO =
        CASE
            WHEN DEPTO = 'LE?N' THEN 'LEON'
            WHEN DEPTO = 'ESTEL?' THEN 'ESTELI'
            WHEN DEPTO = 'R?O SAN JUAN' THEN 'RIO SAN JUAN'
            ELSE DEPTO
            END;

-- Verificar correción de zonas
SELECT DISTINCT ZONA
FROM dbo.ANTENAS
ORDER BY ZONA;

-- Verificar correción de departamentos
SELECT DISTINCT DEPTO
FROM dbo.antenas
ORDER BY DEPTO;

-- ID_SITIO repetidos
SELECT ID_SITIO,
       COUNT(*) AS CANTIDAD
FROM dbo.ANTENAS
GROUP BY ID_SITIO
HAVING COUNT(*) > 1
ORDER BY CANTIDAD DESC, ID_SITIO;

-- ID_SITIO asociados a mas de una zona (ambigüedades)
SELECT ID_SITIO, COUNT(DISTINCT ZONA) AS CANTIDAD_ZONAS
FROM dbo.ANTENAS
GROUP BY ID_SITIO
HAVING COUNT(DISTINCT ZONA) > 1
ORDER BY ID_SITIO;

-- Creación de tabla de excepciones
IF OBJECT_ID('dbo.ANTENAS_AMBIGUAS', 'U') IS NOT NULL
    DROP TABLE dbo.ANTENAS_AMBIGUAS;

SELECT A.*
INTO dbo.ANTENAS_AMBIGUAS
FROM dbo.ANTENAS A
WHERE A.ID_SITIO IN (SELECT ID_SITIO
                     FROM dbo.ANTENAS
                     GROUP BY ID_SITIO
                     HAVING COUNT(DISTINCT zona) > 1);

-- Catálogo operativo: Una fila por ID_SITIO SOLO cuando la zona es inequívoca
-- MAX() se usa únicamente después de asegurar que existe una sola zona.
IF OBJECT_ID('dbo.ANTENAS_UNICAS', 'U') IS NOT NULL
    DROP TABLE dbo.ANTENAS_UNICAS;

-- Crear tabla ANTENAS_UNICAS
WITH SITIOS_VALIDOS AS (SELECT ID_SITIO
                        FROM dbo.ANTENAS
                        GROUP BY ID_SITIO
                        HAVING COUNT(DISTINCT ZONA) = 1)
SELECT A.ID_SITIO,
       MAX(A.ID_SITIO)  AS SITIO,
       MAX(A.DEPTO)     AS DEPARTAMENTO,
       MAX(A.MUNICIPIO) AS MUNICIPIO,
       MAX(A.ZONA)      AS zona
INTO dbo.ANTENAS_UNICAS
FROM dbo.ANTENAS A
         INNER JOIN SITIOS_VALIDOS V ON A.ID_SITIO = V.ID_SITIO
GROUP BY A.ID_SITIO;

-- =======================================
-- === 4. Integracióñ consumo - antena ===
-- =======================================

SELECT TOP (100) C.ABONADO,
                 C.DIA,
                 C.ANTENA,
                 A.DEPARTAMENTO,
                 A.MUNICIPIO,
                 A.ZONA,
                 C.MB,
                 C.MINUTOS,
                 C.INGRESO
FROM dbo.CONSUMO_ABONADOS C
         INNER JOIN dbo.ANTENAS_UNICAS A
                    ON c.ANTENA = a.ID_SITIO;

-- Antenas de consumo que no tienen correspondencia válida en el catálogo operativo
SELECT C.ANTENA,
       COUNT(*) AS REGISTROS_CONSUMO
FROM dbo.CONSUMO_ABONADOS C
         LEFT JOIN dbo.ANTENAS_UNICAS A
                   ON C.ANTENA = A.ID_SITIO
WHERE A.ID_SITIO IS NULL
GROUP BY C.ANTENA
ORDER BY C.ANTENA;

-- ====================================
-- === 5. Creación de nodos lógicos ===
-- ====================================

-- mssql-dev
USE master;

IF DB_ID('BD_REGION_1') IS NULL EXEC ('CREATE DATABASE BD_REGION_1');
IF DB_ID('BD_REGION_2') IS NULL EXEC ('CREATE DATABASE BD_REGION_2');

USE BD_REGION_1;

IF OBJECT_ID('dbo.CONSUMO_REGIONAL', 'U') IS NULL
CREATE TABLE dbo.CONSUMO_REGIONAL
(
    ABONADO  BIGINT,
    TRAMO    INT,
    LNEGOCIO VARCHAR(20),
    SEGMENTO VARCHAR(10),
    DIA      INT,
    ANTENA   INT,
    ZONA     VARCHAR(50),
    EVENTOS  INT,
    MB       DECIMAL(18, 2),
    MINUTOS  DECIMAL(18, 2),
    INGRESO  DECIMAL(18, 3)
);


USE BD_REGION_2;

IF OBJECT_ID('dbo.CONSUMO_REGIONAL', 'U') IS NULL
CREATE TABLE dbo.CONSUMO_REGIONAL
(
    ABONADO  BIGINT,
    TRAMO    INT,
    LNEGOCIO VARCHAR(20),
    SEGMENTO VARCHAR(10),
    DIA      INT,
    ANTENA   INT,
    ZONA     VARCHAR(50),
    EVENTOS  INT,
    MB       DECIMAL(18, 2),
    MINUTOS  DECIMAL(18, 2),
    INGRESO  DECIMAL(18, 3)
);


-- mssql-lab
USE master;

IF DB_ID('BD_REGION_3') IS NULL EXEC ('CREATE DATABASE BD_REGION_3');

USE BD_REGION_3;

IF OBJECT_ID('dbo.CONSUMO_REGIONAL', 'U') IS NULL
CREATE TABLE dbo.CONSUMO_REGIONAL
(
    ABONADO  BIGINT,
    TRAMO    INT,
    LNEGOCIO VARCHAR(20),
    SEGMENTO VARCHAR(10),
    DIA      INT,
    ANTENA   INT,
    ZONA     VARCHAR(50),
    EVENTOS  INT,
    MB       DECIMAL(18, 2),
    MINUTOS  DECIMAL(18, 2),
    INGRESO  DECIMAL(18, 3)
);

--Crear credenciales remotas para el servidor
IF NOT EXISTS (SELECT 1
               FROM sys.server_principals
               WHERE name = N'LoginRegion3')
    BEGIN
        CREATE LOGIN LoginRegion3
            WITH PASSWORD = 'BasesDeDatosRegion3!2026';
    END;

USE BD_REGION_3;

IF NOT EXISTS (SELECT 1
               FROM sys.database_principals
               WHERE name = N'UsuarioRegion3')
    BEGIN
        CREATE USER UsuarioRegion3
            FOR LOGIN LoginRegion3;
    END;

IF IS_ROLEMEMBER(N'db_datawriter', N'UsuarioRegion3') <> 1
    BEGIN
        ALTER ROLE db_datawriter
            ADD MEMBER UsuarioRegion3;
    END;


-- SERVIDOR ENLAZADO (mssql-dev) de BD_REGION_3
USE master;

-- Crear Servidor enlazado
IF NOT EXISTS (SELECT 1
               FROM sys.servers
               WHERE name = N'SERVIDOR_REGION3')
    BEGIN

        EXEC master.dbo.sp_addlinkedserver
             @server = N'SERVIDOR_REGION3',
             @srvproduct = N'',
             @provider = N'MSOLEDBSQL',
             @datasrc = N'mssql-lab,1433',
             @provstr = N'Encrypt=Optional;TrustServerCertificate=Yes;User ID=LoginRegion3;UID=LoginRegion3',
             @catalog = N'BD_REGION_3';
    END;

-- añadir LoginRegion3 como login remoto del servidor
IF NOT EXISTS (SELECT 1
               FROM sys.linked_logins AS ll
                        INNER JOIN sys.servers AS s
                                   ON s.server_id = ll.server_id
               WHERE s.name = N'SERVIDOR_REGION3'
                 AND ll.local_principal_id = SUSER_ID('sa'))
    BEGIN
        EXEC master.dbo.sp_addlinkedsrvlogin
             @rmtsrvname = N'SERVIDOR_REGION3',
             @useself = N'False',
             @locallogin = 'sa',
             @rmtuser = N'LoginRegion3',
             @rmtpassword = N'BasesDeDatosRegion3!2026';
    END;

-- test del servidor
EXEC master.dbo.sp_testlinkedserver N'SERVIDOR_REGION3';


-- ===================================
-- === 6. Fragmentación Horizontal ===
-- ===================================

-- mssql-dev
USE Practica_Bulk_Cursores;

TRUNCATE TABLE BD_REGION_1.dbo.CONSUMO_REGIONAL;
TRUNCATE TABLE BD_REGION_2.dbo.CONSUMO_REGIONAL;


INSERT INTO BD_REGION_1.dbo.CONSUMO_REGIONAL
(ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO)
SELECT C.ABONADO,
       C.TRAMO,
       C.LNEGOCIO,
       C.SEGMENTO,
       C.DIA,
       C.ANTENA,
       A.ZONA,
       C.EVENTOS,
       C.MB,
       C.MINUTOS,
       C.INGRESO
FROM dbo.CONSUMO_ABONADOS C
         INNER JOIN dbo.ANTENAS_UNICAS A ON C.ANTENA = A.ID_SITIO
WHERE A.ZONA IN ('CAPITAL', 'SUR ORIENTE');


INSERT INTO BD_REGION_2.dbo.CONSUMO_REGIONAL
(ABONADO, TRAMO, LNEGOCIO, SEGMENTO, DIA, ANTENA, ZONA, EVENTOS, MB, MINUTOS, INGRESO)
SELECT C.ABONADO,
       C.TRAMO,
       C.LNEGOCIO,
       C.SEGMENTO,
       C.DIA,
       C.ANTENA,
       A.ZONA,
       C.EVENTOS,
       C.MB,
       C.MINUTOS,
       C.INGRESO
FROM dbo.CONSUMO_ABONADOS C
         INNER JOIN dbo.ANTENAS_UNICAS A ON C.ANTENA = A.ID_SITIO
WHERE A.ZONA IN ('OCCIDENTE', 'ZONA NORTE');

-- mssql-lab
TRUNCATE TABLE syn_REGION_3;

-- Ejecutar en master en mssql-dev luego del truncate table de mssql-lab
USE master;
INSERT INTO [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL]
(
    ABONADO,
    TRAMO,
    LNEGOCIO,
    SEGMENTO,
    DIA,
    ANTENA,
    ZONA,
    EVENTOS,
    MB,
    MINUTOS,
    INGRESO
)
SELECT
    C.ABONADO,
    C.TRAMO,
    C.LNEGOCIO,
    C.SEGMENTO,
    C.DIA,
    C.ANTENA,
    A.ZONA,
    C.EVENTOS,
    C.MB,
    C.MINUTOS,
    C.INGRESO
FROM Practica_Bulk_Cursores.dbo.CONSUMO_ABONADOS AS C
INNER JOIN Practica_Bulk_Cursores.dbo.ANTENAS_UNICAS AS A
    ON C.ANTENA = A.ID_SITIO
WHERE A.ZONA IN ('ZONA CENTRO', 'REGIONES AUTONOMAS');

-- =====================
-- === 7. Validación ===
-- =====================
use Practica_Bulk_Cursores;

SELECT 'CENTRAL_CON_MAPEO_VALIDO'     AS ORIGEN,
       COUNT_BIG(*)                   AS REGISTROS,
       SUM(CAST(C.EVENTOS AS BIGINT)) AS EVENTOS,
       SUM(C.MB)                      AS MB,
       SUM(C.MINUTOS)                 AS MINUTOS,
       SUM(C.INGRESO)                 AS INGRESO
FROM dbo.CONSUMO_ABONADOS C
         INNER JOIN dbo.ANTENAS_UNICAS A ON C.ANTENA = A.ID_SITIO

UNION ALL

SELECT 'DISTRIBUIDO',
       COUNT_BIG(*),
       SUM(CAST(EVENTOS AS BIGINT)),
       SUM(MB),
       SUM(MINUTOS),
       SUM(INGRESO)
FROM (SELECT EVENTOS, MB, MINUTOS, INGRESO
      FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
      UNION ALL
      SELECT EVENTOS, MB, MINUTOS, INGRESO
      FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
      UNION ALL
      SELECT EVENTOS, MB, MINUTOS, INGRESO
      FROM [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL]) D;

-- ================================
-- === 8. Reconstrucción Global ===
-- ================================

SELECT 'NODO 1' AS NODO,
       ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT 'NODO 2',
       ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT 'NODO 3',
       ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL];


-- CORREGIR LUEGO

-- ============================================
-- === 9. Consultas analíticas distribuidas ===
-- ============================================


WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT ZONA, SUM(INGRESO) AS INGRESO_TOTAL
FROM GLOBAL
GROUP BY ZONA
ORDER BY INGRESO_TOTAL DESC;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT ZONA, SUM(MB) AS MB_TOTAL, SUM(MINUTOS) AS MINUTOS_TOTAL
FROM GLOBAL
GROUP BY ZONA
ORDER BY ZONA;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT ZONA, COUNT(DISTINCT ABONADO) AS ABONADOS_DISTINTOS
FROM GLOBAL
GROUP BY ZONA
ORDER BY ZONA;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT DIA / 100    AS MES,
       ZONA,
       SUM(MB)      AS MB_TOTAL,
       SUM(MINUTOS) AS MINUTOS_TOTAL,
       SUM(INGRESO) AS INGRESO_TOTAL
FROM GLOBAL
GROUP BY DIA / 100, ZONA
ORDER BY MES, ZONA;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT TOP (10) ANTENA,
                SUM(INGRESO) AS INGRESO_TOTAL
FROM GLOBAL
GROUP BY ANTENA
ORDER BY INGRESO_TOTAL DESC;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT TOP (10) ABONADO,
                SUM(MB) AS MB_TOTAL
FROM GLOBAL
GROUP BY ABONADO
ORDER BY MB_TOTAL DESC;
GO

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT ZONA, LNEGOCIO, SUM(CAST(EVENTOS AS BIGINT)) AS EVENTOS_TOTAL
FROM GLOBAL
GROUP BY ZONA, LNEGOCIO
ORDER BY ZONA, LNEGOCIO;
GO

SELECT 'NODO 1' AS NODO, SUM(INGRESO) AS INGRESO
FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT 'NODO 2', SUM(INGRESO)
FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT 'NODO 3', SUM(INGRESO)
FROM syn_REGION_3;
GO

-- =======================
-- === 10. Vista gloal ===
-- =======================

CREATE OR ALTER VIEW dbo.VW_CONSUMO_NACIONAL
AS
SELECT ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
UNION ALL
SELECT ABONADO,
       TRAMO,
       LNEGOCIO,
       SEGMENTO,
       DIA,
       ANTENA,
       ZONA,
       EVENTOS,
       MB,
       MINUTOS,
       INGRESO
FROM syn_REGION_3;
GO

SELECT ZONA, SUM(INGRESO) AS INGRESO_TOTAL
FROM dbo.VW_CONSUMO_NACIONAL
GROUP BY ZONA;

SELECT DIA / 100 AS MES, SUM(MB) AS MB_TOTAL
FROM dbo.VW_CONSUMO_NACIONAL
GROUP BY DIA / 100
ORDER BY MES;

SELECT TOP (10) ABONADO, SUM(INGRESO) AS INGRESO_TOTAL
FROM dbo.VW_CONSUMO_NACIONAL
GROUP BY ABONADO
ORDER BY INGRESO_TOTAL DESC;
GO

-- ========================================================
-- === 11. Linked servers de las otras regiones (2 y 1) ===
-- ========================================================

-- SERVIDOR ENLAZADO (mssql-lab) de BD_REGION_1 y BD_REGION_2
USE master;

-- Crear Servidor enlazado
IF NOT EXISTS (SELECT 1
               FROM sys.servers
               WHERE name = N'SERVIDOR_REGION3')
    BEGIN

        EXEC master.dbo.sp_addlinkedserver
             @server = N'SERVIDOR_REGION3',
             @srvproduct = N'',
             @provider = N'MSOLEDBSQL',
             @datasrc = N'mssql-lab,1433',
             @provstr = N'Encrypt=Optional;TrustServerCertificate=Yes;User ID=LoginRegion3;UID=LoginRegion3',
             @catalog = N'BD_REGION_3';
    END;

-- añadir LoginRegion3 como login remoto del servidor
IF NOT EXISTS (SELECT 1
               FROM sys.linked_logins AS ll
                        INNER JOIN sys.servers AS s
                                   ON s.server_id = ll.server_id
               WHERE s.name = N'SERVIDOR_REGION3'
                 AND ll.local_principal_id = SUSER_ID('sa'))
    BEGIN
        EXEC master.dbo.sp_addlinkedsrvlogin
             @rmtsrvname = N'SERVIDOR_REGION3',
             @useself = N'False',
             @locallogin = 'sa',
             @rmtuser = N'LoginRegion3',
             @rmtpassword = N'BasesDeDatosRegion3!2026';
    END;

-- test del servidor
EXEC master.dbo.sp_testlinkedserver N'SERVIDOR_REGION3';

-- ======================
-- === 12. Reto final ===
-- ======================

WITH GLOBAL AS (SELECT *
                FROM BD_REGION_1.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM BD_REGION_2.dbo.CONSUMO_REGIONAL
                UNION ALL
                SELECT *
                FROM syn_REGION_3)
SELECT DIA / 100                    AS MES,
       ZONA,
       COUNT(DISTINCT ABONADO)      AS ABONADOS_DISTINTOS,
       SUM(CAST(EVENTOS AS BIGINT)) AS EVENTOS,
       SUM(MB)                      AS MB,
       SUM(MINUTOS)                 AS MINUTOS,
       SUM(INGRESO)                 AS INGRESO
FROM GLOBAL
GROUP BY DIA / 100, ZONA
ORDER BY MES, ZONA;
GO
