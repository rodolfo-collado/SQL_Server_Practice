CREATE DATABASE LaboratorioBackup;
USE LaboratorioBackup;

CREATE TABLE Productos
(
    IdProducto     INT IDENTITY (1,1) PRIMARY KEY,
    NombreProducto VARCHAR(100)   NOT NULL,
    Precio         DECIMAL(10, 2) NOT NULL,
    Stock          INT            NOT NULL
);

INSERT INTO Productos (NombreProducto, Precio, Stock)
VALUES ('Shampoo', 180.00, 20),
       ('Perfume', 750.00, 10),
       ('Labial', 220.00, 30);

INSERT INTO Productos (NombreProducto, Precio, Stock)
VALUES ('Rubor', 220.00, 20),
       ('cepillo', 50.00, 12),
       ('gelatina para pelo', 70.00, 8)

DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;

BACKUP DATABASE LaboratorioBackup
    TO DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak'
    WITH INIT,
    NAME = 'Backup completo - LaboratorioBackup',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak';

DELETE
FROM Productos;

SELECT *
FROM Productos;

USE master;

ALTER DATABASE LaboratorioBackup
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE LaboratorioBackup
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak'
    WITH REPLACE,
    STATS = 10;

ALTER DATABASE LaboratorioBackup
    SET MULTI_USER;

USE LaboratorioBackup

SELECT *
FROM Productos;

DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;




