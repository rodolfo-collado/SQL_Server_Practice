USE PAGOS;
GO

-- Consultar los pagos y las formas de pago antes de automatizar.
SELECT MES,
       FORMA_P,
       COUNT(*)         AS CantidadPagos,
       SUM(IMPORTEPAGO) AS MontoTotal
FROM dbo.PAGOS
GROUP BY MES, FORMA_P
ORDER BY MES, FORMA_P;

SELECT DISTINCT FORMA_P
FROM dbo.PAGOS;

-- Reporte de ingresos por mes con CASE WHEN.
SELECT MES,
       SUM(CASE
               WHEN FORMA_P IN ('TARJETA CREDITO', 'TARJETA DEBITO', 'TARJETA_DEBITO')
                   THEN IMPORTEPAGO
               ELSE 0 END)                                             AS Tarjetas,
       SUM(CASE
               WHEN FORMA_P LIKE 'CTA CTE DEBITO AUTOMATICO%' OR FORMA_P = 'DEBITO_AUT'
                   THEN IMPORTEPAGO
               ELSE 0 END)                                             AS DebitoAutomatico,
       SUM(CASE WHEN FORMA_P = 'SUCURSAL' THEN IMPORTEPAGO ELSE 0 END) AS Sucursal,
       SUM(CASE
               WHEN FORMA_P NOT IN ('TARJETA CREDITO', 'TARJETA DEBITO', 'TARJETA_DEBITO', 'DEBITO_AUT', 'SUCURSAL')
                   AND FORMA_P NOT LIKE 'CTA CTE DEBITO AUTOMATICO%'
                   THEN IMPORTEPAGO
               ELSE 0 END)                                             AS Otros,
       SUM(IMPORTEPAGO)                                                AS TotalMensual
FROM dbo.PAGOS
GROUP BY MES
ORDER BY MES;
GO

/* EJECUCIÓN COMPLETA
   Ejecutar en mssql-dev (localhost,1433), con la base PAGOS y permisos de sa.
   Ya están configurados SQL Server Agent y Database Mail:
      Perfil: PERFIL_REPORTES_PAGOS
      Cuenta: CUENTA_REPORTES_PAGOS
      Remitente: rramirezc@uamv.edu.ni
      SMTP: smtp.gmail.com, puerto 587, TLS.
   La contraseña de aplicación ya está guardada en msdb; no se repite aquí.
   En otra instancia se debe configurar ese perfil antes de ejecutar los Jobs.

   El script elimina los dos nombres anteriores y recrea estos dos Jobs y su historial.
   Los deja programados a las 08:00 y 08:05, según la hora del servidor.
   Los sp_start_job del final están activos: ejecutar todo también envía ambos correos.
*/
USE msdb;
GO

-- Eliminar los nombres anteriores para que no sigan enviando reportes duplicados.
IF EXISTS (SELECT 1
           FROM dbo.sysjobs
           WHERE name = N'JOB_INGRESOS_MENSUALES')
    EXEC dbo.sp_delete_job @job_name = N'JOB_INGRESOS_MENSUALES';
IF EXISTS (SELECT 1
           FROM dbo.sysjobs
           WHERE name = N'JOB_REPORTE_PAGOS')
    EXEC dbo.sp_delete_job @job_name = N'JOB_REPORTE_PAGOS';

-- JOB 1: REPORTE_INGRESOS_MENSUALES_RESUMIDOS, columnas por categoría.
IF EXISTS (SELECT 1
           FROM dbo.sysjobs
           WHERE name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS')
    EXEC dbo.sp_delete_job @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS';

EXEC dbo.sp_add_job
     @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS',
     @enabled = 1,
     @description = N'Ingresos resumidos por categoría: correo HTML y CSV a Gabriel con copia a Darwing.';

EXEC dbo.sp_add_jobstep
     @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS',
     @step_name = N'01_Enviar_Correo_HTML',
     @subsystem = N'TSQL',
     @database_name = N'PAGOS',
     @command = N'SET NOCOUNT ON;
DECLARE @html nvarchar(max);
SET @html = N''<html><body style="font-family:Arial,sans-serif;color:#243247;">
<h2 style="color:#176b87;">REPORTE_INGRESOS_MENSUALES_RESUMIDOS</h2>
<p>Adjunto encontrará el reporte CSV de la práctica de la sesión 13.</p>
<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
<tr style="background-color:#176b87;color:white;"><th>Mes</th><th>Tarjetas</th><th>Débito automático</th><th>Sucursal</th><th>Otros</th><th>Total mensual</th></tr>''
+ CAST((
    SELECT td = MES, '''',
            td = Tarjetas, '''',
            td = DebitoAutomatico, '''',
            td = Sucursal, '''',
            td = Otros, '''',
            td = TotalMensual
    FROM (
        SELECT MES,
               SUM(CASE WHEN FORMA_P IN (''TARJETA CREDITO'', ''TARJETA DEBITO'', ''TARJETA_DEBITO'')
                        THEN IMPORTEPAGO ELSE 0 END) AS Tarjetas,
               SUM(CASE WHEN FORMA_P LIKE ''CTA CTE DEBITO AUTOMATICO%'' OR FORMA_P = ''DEBITO_AUT''
                        THEN IMPORTEPAGO ELSE 0 END) AS DebitoAutomatico,
               SUM(CASE WHEN FORMA_P = ''SUCURSAL'' THEN IMPORTEPAGO ELSE 0 END) AS Sucursal,
               SUM(CASE WHEN FORMA_P NOT IN (''TARJETA CREDITO'', ''TARJETA DEBITO'', ''TARJETA_DEBITO'', ''DEBITO_AUT'', ''SUCURSAL'')
                             AND FORMA_P NOT LIKE ''CTA CTE DEBITO AUTOMATICO%''
                        THEN IMPORTEPAGO ELSE 0 END) AS Otros,
               SUM(IMPORTEPAGO) AS TotalMensual
        FROM dbo.PAGOS
        GROUP BY MES
    ) AS Reporte
    ORDER BY MES
    FOR XML PATH(''tr''), TYPE
) AS nvarchar(max))
+ N''</table><p style="color:#64748b;">Administración de Bases de Datos · UAM</p>
</body></html>'';

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = N''PERFIL_REPORTES_PAGOS'',
    @from_address = N''rramirezc@uamv.edu.ni'',
    @recipients = N''gsorozco@uamv.edu.ni'',
    @copy_recipients = N''darwing.jaime@uamv.edu.ni'',
    @subject = N''Práctica W13 - REPORTE_INGRESOS_MENSUALES_RESUMIDOS'',
    @body = @html,
    @body_format = ''HTML'',
    @execute_query_database = N''PAGOS'',
    @query = N''SET NOCOUNT ON;
SELECT MES,
       SUM(CASE WHEN FORMA_P IN (''''TARJETA CREDITO'''', ''''TARJETA DEBITO'''', ''''TARJETA_DEBITO'''')
                THEN IMPORTEPAGO ELSE 0 END) AS Tarjetas,
       SUM(CASE WHEN FORMA_P LIKE ''''CTA CTE DEBITO AUTOMATICO%'''' OR FORMA_P = ''''DEBITO_AUT''''
                THEN IMPORTEPAGO ELSE 0 END) AS DebitoAutomatico,
       SUM(CASE WHEN FORMA_P = ''''SUCURSAL'''' THEN IMPORTEPAGO ELSE 0 END) AS Sucursal,
       SUM(CASE WHEN FORMA_P NOT IN (''''TARJETA CREDITO'''', ''''TARJETA DEBITO'''', ''''TARJETA_DEBITO'''', ''''DEBITO_AUT'''', ''''SUCURSAL'''')
                     AND FORMA_P NOT LIKE ''''CTA CTE DEBITO AUTOMATICO%''''
                THEN IMPORTEPAGO ELSE 0 END) AS Otros,
       SUM(IMPORTEPAGO) AS TotalMensual
FROM dbo.PAGOS
GROUP BY MES
ORDER BY MES;'',
    @attach_query_result_as_file = 1,
    @query_attachment_filename = N''REPORTE_INGRESOS_MENSUALES_RESUMIDOS.csv'',
    @query_result_separator = '','',
    @query_result_no_padding = 1,
    @exclude_query_output = 1;',
     @on_success_action = 1,
     @on_fail_action = 2;

EXEC dbo.sp_add_jobschedule
     @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS',
     @name = N'SCH_REPORTE_INGRESOS_MENSUALES_RESUMIDOS_DIARIO',
     @freq_type = 4, -- Diario.
     @freq_interval = 1, -- Cada día.
     @active_start_time = 80000;

EXEC dbo.sp_add_jobserver @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS';
GO

-- JOB 2: REPORTE_INGRESOS_MENSUALES, formas de pago en una misma columna.
IF EXISTS (SELECT 1
           FROM dbo.sysjobs
           WHERE name = N'REPORTE_INGRESOS_MENSUALES')
    EXEC dbo.sp_delete_job @job_name = N'REPORTE_INGRESOS_MENSUALES';

EXEC dbo.sp_add_job
     @job_name = N'REPORTE_INGRESOS_MENSUALES',
     @enabled = 1,
     @description = N'Ingresos por MES y FORMA_P: validación, correo HTML y CSV solo a Darwing.';

-- La guía pide validar antes de enviar: si falla, termina el Job.
EXEC dbo.sp_add_jobstep
     @job_name = N'REPORTE_INGRESOS_MENSUALES',
     @step_name = N'01_Validacion',
     @subsystem = N'TSQL',
     @database_name = N'PAGOS',
     @command = N'IF NOT EXISTS (SELECT 1 FROM dbo.PAGOS)
    THROW 50001, ''La tabla PAGOS está vacía.'', 1;
IF EXISTS (SELECT 1 FROM dbo.PAGOS
           WHERE MES IS NULL OR FORMA_P IS NULL OR IMPORTEPAGO IS NULL)
    THROW 50002, ''Hay campos obligatorios nulos.'', 1;
PRINT ''Validación satisfactoria'';',
     @on_success_action = 3, -- Ir al paso de envío.
     @on_fail_action = 2; -- Terminar con error.

EXEC dbo.sp_add_jobstep
     @job_name = N'REPORTE_INGRESOS_MENSUALES',
     @step_name = N'02_Enviar_Correo_HTML',
     @subsystem = N'TSQL',
     @database_name = N'PAGOS',
     @command = N'SET NOCOUNT ON;
DECLARE @html nvarchar(max);
SET @html = N''<html><body style="font-family:Arial,sans-serif;color:#243247;">
<h2 style="color:#176b87;">REPORTE_INGRESOS_MENSUALES</h2>
<p>Adjunto encontrará el reporte CSV de la práctica de la sesión 13.</p>
<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
<tr style="background-color:#176b87;color:white;"><th>Mes</th><th>Forma de pago</th><th>Cantidad</th><th>Monto total</th></tr>''
+ CAST((
    SELECT td = MES, '''',
           td = FORMA_P, '''',
           td = CantidadPagos, '''',
           td = MontoTotal
    FROM (
        SELECT MES, FORMA_P,
               COUNT(*) AS CantidadPagos,
               SUM(IMPORTEPAGO) AS MontoTotal
        FROM dbo.PAGOS
        GROUP BY MES, FORMA_P
    ) AS Reporte
    ORDER BY MES, FORMA_P
    FOR XML PATH(''tr''), TYPE
) AS nvarchar(max))
+ N''</table><p style="color:#64748b;">Administración de Bases de Datos · UAM</p>
</body></html>'';

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = N''PERFIL_REPORTES_PAGOS'',
    @from_address = N''rramirezc@uamv.edu.ni'',
    @recipients = N''darwing.jaime@uamv.edu.ni'',
    @subject = N''Práctica W13 - REPORTE_INGRESOS_MENSUALES'',
    @body = @html,
    @body_format = ''HTML'',
    @execute_query_database = N''PAGOS'',
    @query = N''SET NOCOUNT ON;
SELECT MES, FORMA_P,
       COUNT(*) AS CantidadPagos,
       SUM(IMPORTEPAGO) AS MontoTotal
FROM dbo.PAGOS
GROUP BY MES, FORMA_P
ORDER BY MES, FORMA_P;'',
    @attach_query_result_as_file = 1,
    @query_attachment_filename = N''REPORTE_INGRESOS_MENSUALES.csv'',
    @query_result_separator = '','',
    @query_result_no_padding = 1,
    @exclude_query_output = 1;',
     @on_success_action = 1,
     @on_fail_action = 2;

EXEC dbo.sp_add_jobschedule
     @job_name = N'REPORTE_INGRESOS_MENSUALES',
     @name = N'SCH_REPORTE_INGRESOS_MENSUALES_DIARIO',
     @freq_type = 4, -- Diario.
     @freq_interval = 1, -- Cada día.
     @active_start_time = 80500;

EXEC dbo.sp_add_jobserver @job_name = N'REPORTE_INGRESOS_MENSUALES';
GO

-- Envío inmediato: cada inicio genera un correo. Comentar estas líneas si solo se quieren crear los Jobs.
EXEC msdb.dbo.sp_start_job @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS';
EXEC msdb.dbo.sp_start_job @job_name = N'REPORTE_INGRESOS_MENSUALES';

-- Evidencia de ejecución: también puede verse desde Jobs > View History.
EXEC msdb.dbo.sp_help_jobhistory @job_name = N'REPORTE_INGRESOS_MENSUALES_RESUMIDOS';
EXEC msdb.dbo.sp_help_jobhistory @job_name = N'REPORTE_INGRESOS_MENSUALES';

-- El éxito del Job indica que el correo se encoló; revisar también el envío SMTP.
SELECT TOP (20) mailitem_id,
                sent_status,
                recipients,
                copy_recipients,
                subject,
                send_request_date,
                sent_date
FROM msdb.dbo.sysmail_allitems
WHERE subject LIKE N'Práctica W13 - %'
ORDER BY mailitem_id DESC;

-- Comprobar que SQL Server Agent esté en ejecución para cumplir los horarios.
SELECT servicename, status_desc
FROM sys.dm_server_services
WHERE servicename LIKE N'SQL Server Agent%';
