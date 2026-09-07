DBCC CHECKDB ('Northwind') WITH NO_INFOMSGS;
DBCC CHECKDB ('SINSA') WITH NO_INFOMSGS;
DBCC CHECKDB ('Sistema_Nomina') WITH NO_INFOMSGS;
DBCC CHECKDB ('LaboratorioBackup') WITH NO_INFOMSGS;


BACKUP DATABASE LaboratorioBackup
    TO DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak'
    WITH INIT,
    NAME = 'Backup completo - LaboratorioBackup',
    STATS = 10;

BACKUP DATABASE Northwind
    TO DISK = '/var/opt/mssql/backup/Northwind.bak'
    WITH INIT,
    CHECKSUM,
    NAME = 'Backup completo - Northwind',
    STATS = 10;


BACKUP DATABASE SINSA
    TO DISK = '/var/opt/mssql/backup/SINSA.bak'
    WITH INIT,
    CHECKSUM,
    NAME = 'Backup completo - SINSA',
    STATS = 10;

BACKUP DATABASE Sistema_Nomina
    TO DISK = '/var/opt/mssql/backup/Sistema_Nomina.bak'
    WITH INIT,
    CHECKSUM,
    NAME = 'Backup completo - Sistema_Nomina',
    STATS = 10;


RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Sistema_Nomina.bak'
    WITH CHECKSUM;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/LaboratorioBackup.bak'
    WITH CHECKSUM;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/SINSA.bak'
    WITH CHECKSUM;

RESTORE VERIFYONLY
    FROM DISK = '/var/opt/mssql/backup/Northwind.bak'
    WITH CHECKSUM;