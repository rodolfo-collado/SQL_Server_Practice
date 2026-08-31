RESTORE FILELISTONLY
FROM DISK = '/var/opt/mssql/backup/Northwind.bak';

RESTORE DATABASE Northwind
FROM DISK = '/var/opt/mssql/backup/Northwind.bak'
WITH
    MOVE 'Northwind'
        TO '/var/opt/mssql/data/Northwind.mdf',
    MOVE 'Northwind_log'
        TO '/var/opt/mssql/data/Northwind_log.ldf',
    RECOVERY;