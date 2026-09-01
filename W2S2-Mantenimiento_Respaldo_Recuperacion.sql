-- 1. Crear la base de datos
CREATE DATABASE LaboratorioBackup;
USE LaboratorioBackup;

-- 2. Crear tabla de productos
CREATE TABLE Productos
(
    IdProducto     INT IDENTITY (1,1) PRIMARY KEY,
    NombreProducto VARCHAR(100)   NOT NULL,
    Precio         DECIMAL(10, 2) NOT NULL,
    Stock          INT            NOT NULL
);

-- 3. Insertar datos a la tabla de productos
INSERT INTO Productos (NombreProducto, Precio, Stock)
VALUES ('Shampoo', 180.00, 20),
       ('Perfume', 750.00, 10),
       ('Labial', 220.00, 30);

INSERT INTO Productos (NombreProducto, Precio, Stock)
VALUES ('Rubor', 220.00, 20),
       ('cepillo', 50.00, 12),
       ('gelatina para pelo', 70.00, 8)

-- 4. Comprobar consistencia de la base de datos
DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;

--5. Hacer un respaldo de la base de datos LaboratorioBackup
BACKUP DATABASE LaboratorioBackup
    TO DISK = '/var/opt/mssql/backup/LaboratorioBackupPC.bak'
    WITH INIT,
    NAME = 'Backup completo - LaboratorioBackup',
    STATS = 10;

-- 6. Verificar el archivo de respaldo
RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak';

-- 7. Simular la pérdida de información
DELETE
FROM Productos;

SELECT *
FROM Productos;

-- 8. Restaurar la base de datos desde el archivo .bak
USE master;

ALTER DATABASE LaboratorioBackup
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE LaboratorioBackup
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak'
    WITH REPLACE,
    STATS = 10;

ALTER DATABASE LaboratorioBackup
    SET MULTI_USER;

-- 9. Verificar la recuperación
USE LaboratorioBackup

SELECT *
FROM Productos;

DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;




