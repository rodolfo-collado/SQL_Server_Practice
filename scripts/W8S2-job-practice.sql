SET NOCOUNT ON;

PRINT 'Inicio del proceso';

SELECT @@SERVERNAME  AS Servidor,
       DB_NAME()     AS BaseDeDatos,
       SUSER_NAME()  AS LoginActual,
       SYSDATETIME() AS FechaEjecucion;

PRINT 'Proceso finalizado';

