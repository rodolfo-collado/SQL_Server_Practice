USE master;
GO

-- Consultar el nombre local registrado.
SELECT @@SERVERNAME AS Nombre_Actual,
       SERVERPROPERTY('MachineName') AS Nombre_Maquina;

-- Cambiar solamente el registro del servidor local.
DECLARE @NombreActual sysname;
SELECT @NombreActual = name
FROM sys.servers
WHERE server_id = 0;

IF @NombreActual <> N'mssql-dev'
BEGIN
    EXEC sys.sp_dropserver @server = @NombreActual;
    EXEC sys.sp_addserver @server = N'mssql-dev', @local = N'local';
END;
GO