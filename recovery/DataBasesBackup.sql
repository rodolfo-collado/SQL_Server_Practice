-- ==========================================================================
-- Instancia Origen (mssql-dev)
-- ==========================================================================

-- ==== SINSA ====

DBCC CHECKDB ('SINSA') WITH NO_INFOMSGS;

BACKUP DATABASE SINSA
    TO DISK = '/var/opt/mssql/backup/SINSA_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - SINSA',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/SINSA_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== Northwind ====

DBCC CHECKDB ('Northwind') WITH NO_INFOMSGS;

BACKUP DATABASE Northwind
    TO DISK = '/var/opt/mssql/backup/Northwind_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - Northwind',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Northwind_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== BaseDatosOrigen ====

DBCC CHECKDB ('BaseDatosOrigen') WITH NO_INFOMSGS;

BACKUP DATABASE BaseDatosOrigen
    TO DISK = '/var/opt/mssql/backup/BaseDatosOrigen_mssql-dev.bak'
    WITH INIT, CHECKSUM , NAME = 'Backup completo - BaseDatosOrigen'

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/BaseDatosOrigen_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== LaboratorioBackup ====

DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;

BACKUP DATABASE LaboratorioBackup
    TO DISK = '/var/opt/mssql/backup/LaboratorioBackup_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - LaboratorioBackup',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== Sistema_Nomina ====

DBCC CHECKDB ('Sistema_Nomina') WITH NO_INFOMSGS;

BACKUP DATABASE Sistema_Nomina
    TO DISK = '/var/opt/mssql/backup/Sistema_Nomina_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - Sistema_Nomina',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Sistema_Nomina_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== Practica_Bulk_Cursores ====

DBCC CHECKDB ('Practica_Bulk_Cursores') WITH NO_INFOMSGS;

BACKUP DATABASE Practica_Bulk_Cursores
    TO DISK = '/var/opt/mssql/backup/Practica_Bulk_Cursores_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - Practica_Bulk_Cursores',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Practica_Bulk_Cursores_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== TechNova_Central ====

DBCC CHECKDB ('TechNova_Central') WITH NO_INFOMSGS;

BACKUP DATABASE TechNova_Central
    TO DISK = '/var/opt/mssql/backup/TechNova_Central_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - TechNova_Central',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/TechNova_Central_mssql-dev.bak'
    WITH CHECKSUM;

-- ===== TechNova_Sinonimos ====

DBCC CHECKDB ('TechNova_Sinonimos') WITH NO_INFOMSGS;

BACKUP DATABASE TechNova_Sinonimos
    TO DISK = '/var/opt/mssql/backup/TechNova_Sinonimos_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - TechNova_Sinonimos',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/TechNova_Sinonimos_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== Ventas_Norte ====

DBCC CHECKDB ('Ventas_Norte') WITH NO_INFOMSGS;

BACKUP DATABASE Ventas_Norte
    TO DISK = '/var/opt/mssql/backup/Ventas_Norte_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - Ventas_Norte',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Ventas_Norte_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== BD_REGION_1 ====

DBCC CHECKDB ('BD_REGION_1') WITH NO_INFOMSGS;

BACKUP DATABASE BD_REGION_1
    TO DISK = '/var/opt/mssql/backup/BD_REGION_1_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - BD_REGION_1',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_1_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== BD_REGION_2 ====

DBCC CHECKDB ('BD_REGION_2') WITH NO_INFOMSGS;

BACKUP DATABASE BD_REGION_2
    TO DISK = '/var/opt/mssql/backup/BD_REGION_2_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - BD_REGION_2',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_2_mssql-dev.bak'
    WITH CHECKSUM;

-- ==== master ====

DBCC CHECKDB ('master') WITH NO_INFOMSGS;

BACKUP DATABASE master
    TO DISK = '/var/opt/mssql/backup/master_mssql-dev.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - master_mssql-dev',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/master_mssql-dev.bak'
    WITH CHECKSUM;


-- ==========================================================================
-- Instancia Destino (mssql-lab)
-- ==========================================================================

-- ==== BaseDatosDestino ====

DBCC CHECKDB ('BaseDatosDestino') WITH NO_INFOMSGS;

BACKUP DATABASE BaseDatosDestino
    TO DISK = '/var/opt/mssql/backup/BaseDatosDestino_mssql-lab.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - BaseDatosDestino_mssql-lab',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/BaseDatosDestino_mssql-lab.bak'
    WITH CHECKSUM;

-- ==== BD_REGION_3 ====

DBCC CHECKDB ('BD_REGION_3') WITH NO_INFOMSGS;

BACKUP DATABASE BD_REGION_3
    TO DISK = '/var/opt/mssql/backup/BD_REGION_3_mssql-lab.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - BD_REGION_3_mssql-lab',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_3_mssql-lab.bak'
    WITH CHECKSUM;

-- ==== TechNova_Bodega ====

DBCC CHECKDB ('TechNova_Bodega') WITH NO_INFOMSGS;

BACKUP DATABASE TechNova_Bodega
    TO DISK = '/var/opt/mssql/backup/TechNova_Bodega_mssql-lab.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - TechNova_Bodega_mssql-lab',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/TechNova_Bodega_mssql-lab.bak'
    WITH CHECKSUM;

-- ==== Ventas_Sur ====

DBCC CHECKDB ('Ventas_Sur') WITH NO_INFOMSGS;

BACKUP DATABASE Ventas_Sur
    TO DISK = '/var/opt/mssql/backup/Ventas_Sur_mssql-lab.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - Ventas_Sur_mssql-lab',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Ventas_Sur_mssql-lab.bak'
    WITH CHECKSUM;

-- ==== master ====

DBCC CHECKDB ('master') WITH NO_INFOMSGS;

BACKUP DATABASE master
    TO DISK = '/var/opt/mssql/backup/master_mssql-lab.bak'
    WITH INIT, CHECKSUM, NAME = 'Backup completo - master_mssql-lab',
    STATS = 10;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/master_mssql-lab.bak'
    WITH CHECKSUM;

-- ==========================================================================
-- Restauraciones de Bases de Datos en instancia Origen
-- ==========================================================================

USE master;

-- SINSA

ALTER DATABASE SINSA
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE SINSA
    FROM DISK = '/var/opt/mssql/backup/SINSA_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE SINSA
    SET MULTI_USER;

-- Northwind

ALTER DATABASE Northwind
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Northwind
    FROM DISK = '/var/opt/mssql/backup/Northwind_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Northwind
    SET MULTI_USER;

-- BaseDatosOrigen

ALTER DATABASE BaseDatosOrigen
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BaseDatosOrigen
    FROM DISK = '/var/opt/mssql/backup/BaseDatosOrigen_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE BaseDatosOrigen
    SET MULTI_USER;

-- LaboratorioBackup

ALTER DATABASE LaboratorioBackup
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE LaboratorioBackup
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE LaboratorioBackup
    SET MULTI_USER;

-- Sistema_Nomina

ALTER DATABASE Sistema_Nomina
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Sistema_Nomina
    FROM DISK = '/var/opt/mssql/backup/Sistema_Nomina_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Sistema_Nomina
    SET MULTI_USER;

-- Practica_Bulk_Cursores

ALTER DATABASE Practica_Bulk_Cursores
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Practica_Bulk_Cursores
    FROM DISK = '/var/opt/mssql/backup/Practica_Bulk_Cursores_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Practica_Bulk_Cursores
    SET MULTI_USER;

-- TechNova_Central

ALTER DATABASE TechNova_Central
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE TechNova_Central
    FROM DISK = '/var/opt/mssql/backup/TechNova_Central_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE TechNova_Central
    SET MULTI_USER;

-- TechNova_Sinonimos

ALTER DATABASE TechNova_Sinonimos
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE TechNova_Sinonimos
    FROM DISK = '/var/opt/mssql/backup/TechNova_Sinonimos_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE TechNova_Sinonimos
    SET MULTI_USER;

-- Ventas_Norte

ALTER DATABASE Ventas_Norte
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Ventas_Norte
    FROM DISK = '/var/opt/mssql/backup/Ventas_Norte_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Ventas_Norte
    SET MULTI_USER;

-- BD_REGION_1

ALTER DATABASE BD_REGION_1
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BD_REGION_1
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_1_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE BD_REGION_1
    SET MULTI_USER;

-- BD_REGION_2

ALTER DATABASE BD_REGION_2
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BD_REGION_2
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_2_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE BD_REGION_2
    SET MULTI_USER;


-- ==========================================================================
-- Restauraciones de Bases de Datos en instancia Destino
-- ==========================================================================

USE master;

-- BaseDatosDestino

ALTER DATABASE BaseDatosDestino
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BaseDatosDestino
    FROM DISK = '/var/opt/mssql/backup/BaseDatosDestino_mssql-lab.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE BaseDatosDestino
    SET MULTI_USER;

-- BD_REGION_3

ALTER DATABASE BD_REGION_3
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE BD_REGION_3
    FROM DISK = '/var/opt/mssql/backup/BD_REGION_3_mssql-lab.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE BD_REGION_3
    SET MULTI_USER;

-- TechNova_Bodega

ALTER DATABASE TechNova_Bodega
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE TechNova_Bodega
    FROM DISK = '/var/opt/mssql/backup/TechNova_Bodega_mssql-lab.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE TechNova_Bodega
    SET MULTI_USER;

-- Ventas_Sur

ALTER DATABASE Ventas_Sur
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Ventas_Sur
    FROM DISK = '/var/opt/mssql/backup/Ventas_Sur_mssql-lab.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Ventas_Sur
    SET MULTI_USER;
