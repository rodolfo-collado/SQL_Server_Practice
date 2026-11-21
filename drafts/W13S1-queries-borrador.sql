USE PAGOS;
GO

-- Consulta los pagos antes de automatizar
SELECT MES,
       FORMA_P,
       COUNT(*)         AS CANTIDAD_PAGOS,
       SUM(IMPORTEPAGO) AS MONTO_TOTAL
FROM dbo.PAGOS
GROUP BY mes, FORMA_P
ORDER BY mes, FORMA_P;

-- Tipos de forma de pago
SELECT DISTINCT FORMA_P
FROM dbo.PAGOS;

-- Reporte mensual de ingresos por forma de pago.
-- Se conserva cada MES almacenado: no se asume un formato de fecha para MES.
-- La vista permite reutilizar el mismo CASE WHEN desde el Job.
GO
CREATE OR ALTER VIEW dbo.vw_W13_IngresosMensuales
AS
SELECT MES,
       SUM(CASE
               WHEN FORMA_P IN ('TARJETA CREDITO', 'TARJETA DEBITO', 'TARJETA_DEBITO') THEN IMPORTEPAGO
               ELSE 0 END)                                                                                            AS [Importe de Tarjetas],
       SUM(CASE
               WHEN FORMA_P LIKE 'CTA CTE DEBITO AUTOMATICO%' OR FORMA_P = 'DEBITO_AUT' THEN IMPORTEPAGO
               ELSE 0 END)                                                                                            AS [Importe de Débito Automático],
       SUM(CASE WHEN FORMA_P = 'SUCURSAL' THEN IMPORTEPAGO ELSE 0 END)                                                AS [Importe de Sucursal],
       SUM(CASE
               WHEN FORMA_P IS NULL OR (FORMA_P NOT IN ('TARJETA CREDITO', 'TARJETA DEBITO', 'TARJETA_DEBITO', 'DEBITO_AUT', 'SUCURSAL')
                   AND FORMA_P NOT LIKE 'CTA CTE DEBITO AUTOMATICO%') THEN IMPORTEPAGO
               ELSE 0 END)                                                                                            AS [Importe Restante],
       SUM(IMPORTEPAGO)                                                                                               AS [Importe Mensual]
FROM dbo.PAGOS
GROUP BY MES;
GO

SELECT *
FROM dbo.vw_W13_IngresosMensuales
ORDER BY MES;
GO

/*
    AUTOMATIZACIÓN DE LA SESIÓN 13
    Base real de esta práctica: PAGOS (el PowerPoint usa PAGOSDB).

    Antes de ejecutar la creación de Jobs:
    - Iniciar SQL Server Agent (no está disponible en SQL Server Express).
    - Configurar y probar SMTP desde SSMS > Management > Database Mail.
      Usar el perfil PERFIL_REPORTES_PAGOS o cambiar @PerfilCorreo abajo.
      No guardar credenciales SMTP en este archivo.
    - Ejecutar con una cuenta autorizada para crear Jobs, consultar PAGOS
      y usar el perfil de Database Mail. El propietario será quien cree el Job.
    - Si Database Mail XPs está deshabilitado, un administrador puede ejecutar:
      EXEC master.dbo.sp_configure 'show advanced options', 1;
      RECONFIGURE;
      EXEC master.dbo.sp_configure 'Database Mail XPs', 1;
      RECONFIGURE;

    Ambos Jobs se ejecutan diariamente con la hora del servidor.
    Cada Job valida y luego envía; un error de validación detiene el envío.
    La creación no inicia los Jobs inmediatamente. Los calendarios quedan activos.
    No se reemplazan Jobs existentes ni se borra su historial al repetir el script.

    La diapositiva 22 también pide evidencias de SSMS (General, Steps,
    Schedule e historial) y diagnosticar un error controlado. Este script
    cubre la vía T-SQL; las capturas se obtienen en la instancia del laboratorio.
*/
USE msdb;
GO

DECLARE @PerfilCorreo sysname = N'PERFIL_REPORTES_PAGOS';
DECLARE @FechaInicio int = CONVERT(int, CONVERT(char(8), GETDATE(), 112));
DECLARE @IdJob uniqueidentifier;
DECLARE @Validacion nvarchar(max) = N'
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM dbo.PAGOS)
    THROW 50001, ''La tabla PAGOS está vacía.'', 1;
IF EXISTS (
    SELECT 1 FROM dbo.PAGOS
    WHERE MES IS NULL OR FORMA_P IS NULL OR IMPORTEPAGO IS NULL
)
    THROW 50002, ''Hay campos obligatorios nulos en PAGOS.'', 1;
IF EXISTS (SELECT 1 FROM dbo.PAGOS WHERE IMPORTEPAGO < 0)
    THROW 50003, ''Hay importes negativos en PAGOS; revisar antes de enviar.'', 1;
PRINT ''Validación satisfactoria'';';

IF NOT EXISTS (SELECT 1 FROM dbo.sysmail_profile WHERE name = @PerfilCorreo)
    THROW 50004, 'Configure el perfil de Database Mail indicado en @PerfilCorreo.', 1;
IF NOT EXISTS (
    SELECT 1 FROM sys.configurations
    WHERE name = N'Database Mail XPs' AND value_in_use = 1
)
    THROW 50005, 'Database Mail XPs está deshabilitado.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.sysjobs
    WHERE name IN (N'JOB_INGRESOS_MENSUALES', N'JOB_REPORTE_PAGOS')
)
    THROW 50006, 'Ya existe uno de los Jobs. Revíselo en SSMS antes de volver a crear ambos.', 1;

-- CSV con encabezado explícito: evita la fila de guiones que genera sqlcmd.
-- Los textos van entre comillas y las comillas internas se duplican.
DECLARE @ConsultaIngresos nvarchar(max) = N'
SET NOCOUNT ON;
SELECT CSV
FROM (
    SELECT 0 AS ORDEN, NULL AS MES,
        CAST(N''MES,Importe de Tarjetas,Importe de Débito Automático,Importe de Sucursal,Importe Restante,Importe Mensual'' AS nvarchar(1000)) AS CSV
    UNION ALL
    SELECT 1, MES,
        N''"'' + REPLACE(CONVERT(nvarchar(100), MES), N''"'', N''""'') + N''",''
        + CONVERT(nvarchar(100), [Importe de Tarjetas]) + N'',''
        + CONVERT(nvarchar(100), [Importe de Débito Automático]) + N'',''
        + CONVERT(nvarchar(100), [Importe de Sucursal]) + N'',''
        + CONVERT(nvarchar(100), [Importe Restante]) + N'',''
        + CONVERT(nvarchar(100), [Importe Mensual])
    FROM dbo.vw_W13_IngresosMensuales
) AS REPORTE
ORDER BY ORDEN, MES;';

DECLARE @ConsultaPagos nvarchar(max) = N'
SET NOCOUNT ON;
SELECT CSV
FROM (
    SELECT 0 AS ORDEN, NULL AS MES, CAST(NULL AS nvarchar(4000)) AS FORMA_P,
        CAST(N''MES,FORMA_P,CANTIDAD_PAGOS,MONTO_TOTAL'' AS nvarchar(4000)) AS CSV
    UNION ALL
    SELECT 1, MES, CONVERT(nvarchar(4000), FORMA_P),
        N''"'' + REPLACE(CONVERT(nvarchar(100), MES), N''"'', N''""'') + N''","''
        + REPLACE(CONVERT(nvarchar(1000), FORMA_P), N''"'', N''""'') + N''",''
        + CONVERT(nvarchar(100), COUNT(*)) + N'',''
        + CONVERT(nvarchar(100), SUM(IMPORTEPAGO))
    FROM dbo.PAGOS
    GROUP BY MES, FORMA_P
) AS REPORTE
ORDER BY ORDEN, MES, FORMA_P;';

-- Construir los comandos con literales escapados: @query se ejecuta
-- en otra sesión y no puede acceder a las variables locales de este lote.
DECLARE @EnvioIngresos nvarchar(max) = N'
SET NOCOUNT ON;
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = N''' + REPLACE(@PerfilCorreo, '''', '''''') + N''',
    @recipients = N''rramirezc@uamv.edu.ni'',
    @copy_recipients = N''darwing.jaime@uamv.edu.ni'',
    @subject = N''Práctica W13 - Reporte mensual de ingresos'',
    @body = N''Adjunto el reporte de ingresos por mes y categoría de pago de PAGOS, calculado con CASE WHEN.'',
    @execute_query_database = N''PAGOS'',
    @query = N''' + REPLACE(@ConsultaIngresos, '''', '''''') + N''',
    @attach_query_result_as_file = 1,
    @query_attachment_filename = N''ingresos_mensuales.csv'',
    @query_result_header = 0,
    @query_result_separator = '','',
    @query_result_no_padding = 1,
    @exclude_query_output = 1,
    @append_query_error = 0;';

DECLARE @EnvioPagos nvarchar(max) = N'
SET NOCOUNT ON;
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = N''' + REPLACE(@PerfilCorreo, '''', '''''') + N''',
    @recipients = N''darwing.jaime@uamv.edu.ni'',
    @subject = N''Práctica W13 - Resumen de pagos por mes y forma de pago'',
    @body = N''Adjunto el resumen de la práctica guiada: MES, FORMA_P, cantidad de pagos y monto total.'',
    @execute_query_database = N''PAGOS'',
    @query = N''' + REPLACE(@ConsultaPagos, '''', '''''') + N''',
    @attach_query_result_as_file = 1,
    @query_attachment_filename = N''reporte_pagos.csv'',
    @query_result_header = 0,
    @query_result_separator = '','',
    @query_result_no_padding = 1,
    @exclude_query_output = 1,
    @append_query_error = 0;';

-- Crear ambos Jobs en una transacción para no dejar una instalación parcial.
BEGIN TRY
    BEGIN TRANSACTION;

    -- JOB 1: ingresos mensuales con CASE WHEN, integrante + copia al profesor.
    EXEC dbo.sp_add_job
        @job_name = N'JOB_INGRESOS_MENSUALES',
        @enabled = 1,
        @description = N'Ingresos de PAGOS por MES y categoría. CSV al integrante con copia al profesor.',
        @job_id = @IdJob OUTPUT;

    EXEC dbo.sp_add_jobstep
        @job_id = @IdJob,
        @step_name = N'01_Validar_Pagos',
        @subsystem = N'TSQL',
        @database_name = N'PAGOS',
        @command = @Validacion,
        @on_success_action = 3, -- Continuar al siguiente paso.
        @on_fail_action = 2;    -- Terminar con error, sin enviar.

    EXEC dbo.sp_add_jobstep
        @job_id = @IdJob,
        @step_name = N'02_Enviar_Ingresos_CSV',
        @subsystem = N'TSQL',
        @database_name = N'PAGOS',
        @command = @EnvioIngresos,
        @retry_attempts = 0, -- Evitar reenvíos automáticos desde Agent.
        @on_success_action = 1,
        @on_fail_action = 2;

    EXEC dbo.sp_add_jobschedule
        @job_id = @IdJob,
        @name = N'SCH_W13_INGRESOS_DIARIO_0800',
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_date = @FechaInicio,
        @active_start_time = 80000;

    EXEC dbo.sp_add_jobserver @job_id = @IdJob;

    -- JOB 2: resumen de la práctica guiada, enviado directamente al profesor.
    EXEC dbo.sp_add_job
        @job_name = N'JOB_REPORTE_PAGOS',
        @enabled = 1,
        @description = N'Práctica guiada: validar PAGOS y enviar resumen por MES y FORMA_P al profesor.',
        @job_id = @IdJob OUTPUT;

    EXEC dbo.sp_add_jobstep
        @job_id = @IdJob,
        @step_name = N'01_Validar_Pagos',
        @subsystem = N'TSQL',
        @database_name = N'PAGOS',
        @command = @Validacion,
        @on_success_action = 3,
        @on_fail_action = 2;

    EXEC dbo.sp_add_jobstep
        @job_id = @IdJob,
        @step_name = N'02_Enviar_Resumen_CSV',
        @subsystem = N'TSQL',
        @database_name = N'PAGOS',
        @command = @EnvioPagos,
        @retry_attempts = 0,
        @on_success_action = 1,
        @on_fail_action = 2;

    EXEC dbo.sp_add_jobschedule
        @job_id = @IdJob,
        @name = N'SCH_W13_PAGOS_DIARIO_0805',
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_date = @FechaInicio,
        @active_start_time = 80500;

    EXEC dbo.sp_add_jobserver @job_id = @IdJob;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- PRUEBA MANUAL: ejecutar por separado cuando el perfil SMTP esté probado.
-- Cada inicio vuelve a generar y encolar un correo para sus destinatarios.
-- EXEC msdb.dbo.sp_start_job @job_name = N'JOB_INGRESOS_MENSUALES';
-- EXEC msdb.dbo.sp_start_job @job_name = N'JOB_REPORTE_PAGOS';

-- EVIDENCIA: historial de ambos Jobs (step_id = 0 es el resultado global).
SELECT TOP (30)
       j.name, h.step_id, h.step_name,
       h.run_status, h.run_date, h.run_time, h.message
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobhistory AS h ON j.job_id = h.job_id
WHERE j.name IN (N'JOB_INGRESOS_MENSUALES', N'JOB_REPORTE_PAGOS')
ORDER BY h.instance_id DESC;

-- Éxito del Job significa correo encolado, no entrega al buzón.
-- Revisar sent_status y, si falla SMTP, el registro de Database Mail.
-- sent significa que SMTP aceptó el mensaje; comprobar recepción en el buzón.
SELECT TOP (20)
       mailitem_id, recipients, copy_recipients, subject,
       sent_status, send_request_date, sent_date
FROM msdb.dbo.sysmail_allitems
WHERE subject IN (N'Práctica W13 - Reporte mensual de ingresos',
                  N'Práctica W13 - Resumen de pagos por mes y forma de pago')
ORDER BY mailitem_id DESC;

SELECT TOP (20)
       e.log_date, e.event_type, e.mailitem_id, e.description
FROM msdb.dbo.sysmail_event_log AS e
INNER JOIN msdb.dbo.sysmail_allitems AS m ON m.mailitem_id = e.mailitem_id
WHERE m.subject IN (N'Práctica W13 - Reporte mensual de ingresos',
                    N'Práctica W13 - Resumen de pagos por mes y forma de pago')
ORDER BY e.log_id DESC;

-- ERROR CONTROLADO: ejecutar solo esta instrucción en una consulta separada.
-- No cambia datos ni envía correo. Equivale a la salida de un Step fallido.
-- THROW 50010, 'Error controlado W13: comprobar diagnóstico del mensaje.', 1;
