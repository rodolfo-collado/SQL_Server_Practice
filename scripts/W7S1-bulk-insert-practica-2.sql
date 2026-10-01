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


BULK INSERT dbo.ANTENAS
    FROM '/var/opt/mssql/backup/practica-bulk-insert/Antenas.txt'
    WITH
    (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '0x0a',
    TABLOCK
    )

SELECT COUNT(*)
FROM dbo.ANTENAS;


UPDATE dbo.ANTENAS
SET ZONA = REPLACE(ZONA, CHAR(13), '')


UPDATE dbo.ANTENAS
SET ZONA =
        CASE
            WHEN ZONA = 'REGIONES AUT?NOMAS' THEN 'REGIONES AUTONOMAS'
            ELSE ZONA
            END;

UPDATE dbo.ANTENAS
SET DEPTO =
        CASE
            WHEN DEPTO = 'LE?N' THEN 'LEON'
            WHEN DEPTO = 'ESTEL?' THEN 'ESTELI'
            WHEN DEPTO = 'R?O SAN JUAN' THEN 'RIO SAN JUAN'
            ELSE DEPTO
            END;

SELECT DISTINCT ZONA
FROM dbo.ANTENAS
ORDER BY ZONA;

SELECT DISTINCT DEPTO
FROM dbo.antenas
ORDER BY DEPTO;

-- ID_SITIO repetidos
select ID_SITIO count(*)