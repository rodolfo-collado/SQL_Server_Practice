/*******************************************************************************
 Northwind - reporte mensual y SQL Server Agent Job

 El reporte resume las ventas de Northwind por país del cliente.
 El procedimiento toma el mes anterior; si Northwind no tiene datos en ese mes
 (por ejemplo, porque es una base de ejemplo histórica), utiliza el último mes
 que sí tiene pedidos para que la ejecución de prueba produzca resultados.

 El job se ejecuta el día 1 de cada mes a las 02:00 y guarda el resultado en
 Northwind.dbo.ReporteVentasMensual. El archivo .bat exporta ese resultado a CSV.
*******************************************************************************/

USE Northwind;
GO

SET NOCOUNT ON;
GO

IF OBJECT_ID(N'dbo.ReporteVentasMensual', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.ReporteVentasMensual
        (
            ReporteID       BIGINT IDENTITY (1,1) NOT NULL
                CONSTRAINT PK_ReporteVentasMensual PRIMARY KEY,
            GeneradoEn      DATETIME2(0) NOT NULL
                CONSTRAINT DF_ReporteVentasMensual_GeneradoEn DEFAULT SYSDATETIME(),
            PeriodoInicio   DATE NOT NULL,
            PeriodoFin      DATE NOT NULL,
            PaisCliente     NVARCHAR(15) NOT NULL,
            Pedidos         INT NOT NULL,
            LineasPedido    INT NOT NULL,
            VentasNetas    DECIMAL(19, 2) NOT NULL,
            CONSTRAINT UQ_ReporteVentasMensual_PeriodoPais
                UNIQUE (PeriodoInicio, PaisCliente)
        );
    END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GenerarReporteVentasMensual
    @MesReferencia DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MesReportado DATE =
        DATEFROMPARTS(
            YEAR(COALESCE(@MesReferencia, DATEADD(MONTH, -1, GETDATE()))),
            MONTH(COALESCE(@MesReferencia, DATEADD(MONTH, -1, GETDATE()))),
            1
        );

    DECLARE @MesSiguiente DATE = DATEADD(MONTH, 1, @MesReportado);

    -- Northwind es una base histórica. Si el mes solicitado no tiene pedidos,
    -- se utiliza el último mes disponible para generar un reporte demostrable.
    IF NOT EXISTS
       (
           SELECT 1
           FROM dbo.Orders
           WHERE OrderDate >= @MesReportado
             AND OrderDate < @MesSiguiente
       )
        BEGIN
            SELECT @MesReportado = DATEFROMPARTS(YEAR(MAX(OrderDate)), MONTH(MAX(OrderDate)), 1)
            FROM dbo.Orders
            WHERE OrderDate IS NOT NULL;

            IF @MesReportado IS NULL
                THROW 51000, 'Northwind no contiene pedidos con fecha.', 1;

            SET @MesSiguiente = DATEADD(MONTH, 1, @MesReportado);
        END;

    DELETE FROM dbo.ReporteVentasMensual
    WHERE PeriodoInicio = @MesReportado;

    INSERT INTO dbo.ReporteVentasMensual
        (PeriodoInicio, PeriodoFin, PaisCliente, Pedidos, LineasPedido, VentasNetas)
    SELECT @MesReportado,
           DATEADD(DAY, -1, @MesSiguiente),
           COALESCE(c.Country, N'(Sin país)'),
           COUNT(DISTINCT o.OrderID),
           COUNT_BIG(od.OrderID),
           SUM(
               CONVERT(DECIMAL(19, 4), od.UnitPrice)
               * od.Quantity
               * (1 - CONVERT(DECIMAL(19, 4), od.Discount))
           )
    FROM dbo.Orders AS o
    INNER JOIN dbo.Customers AS c
        ON c.CustomerID = o.CustomerID
    INNER JOIN dbo.[Order Details] AS od
        ON od.OrderID = o.OrderID
    WHERE o.OrderDate >= @MesReportado
      AND o.OrderDate < @MesSiguiente
    GROUP BY COALESCE(c.Country, N'(Sin país)');

    SELECT ReporteID,
           GeneradoEn,
           PeriodoInicio,
           PeriodoFin,
           PaisCliente,
           Pedidos,
           LineasPedido,
           VentasNetas
    FROM dbo.ReporteVentasMensual
    WHERE PeriodoInicio = @MesReportado
    ORDER BY PaisCliente;
END;
GO

-- Prueba manual antes de depender del calendario del job.
EXEC dbo.usp_GenerarReporteVentasMensual;
GO

/*
    CONFIGURACIÓN DEL JOB EN SQL SERVER AGENT
    -----------------------------------------
    Se ejecuta en msdb y crea un job mensual el día 1 a las 02:00.
*/
USE msdb;
GO

DECLARE @JobId UNIQUEIDENTIFIER;
DECLARE @ScheduleId INT;

IF EXISTS
   (
       SELECT 1
       FROM msdb.dbo.sysjobs
       WHERE name = N'Northwind - Reporte mensual'
   )
    EXEC msdb.dbo.sp_delete_job
         @job_name = N'Northwind - Reporte mensual';

EXEC msdb.dbo.sp_add_job
     @job_name = N'Northwind - Reporte mensual',
     @enabled = 1,
     @description = N'Genera el resumen mensual de ventas de Northwind.',
     @owner_login_name = N'sa',
     @job_id = @JobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
     @job_id = @JobId,
     @step_name = N'Generar reporte en Northwind',
     @step_id = 1,
     @subsystem = N'TSQL',
     @database_name = N'Northwind',
     @command = N'EXEC dbo.usp_GenerarReporteVentasMensual;',
     @on_success_action = 1,
     @on_fail_action = 2;

EXEC msdb.dbo.sp_add_schedule
     @schedule_name = N'Northwind - Primer día de cada mes',
     @enabled = 1,
     @freq_type = 16,
     @freq_interval = 1,
     @freq_recurrence_factor = 1,
     @active_start_date = 20260101,
     @active_start_time = 020000,
     @schedule_id = @ScheduleId OUTPUT;

EXEC msdb.dbo.sp_attach_schedule
     @job_id = @JobId,
     @schedule_id = @ScheduleId;

EXEC msdb.dbo.sp_add_jobserver
     @job_id = @JobId,
     @server_name = N'(LOCAL)';
GO

-- Verificación de la configuración creada.
SELECT j.name AS JobName,
       j.enabled AS JobEnabled,
       s.name AS ScheduleName,
       s.freq_type AS FrequencyType,
       s.freq_interval AS DayOfMonth,
       s.active_start_time AS StartTime
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobschedules AS js
    ON js.job_id = j.job_id
INNER JOIN msdb.dbo.sysschedules AS s
    ON s.schedule_id = js.schedule_id
WHERE j.name = N'Northwind - Reporte mensual';
GO

/*
    Para probar el job manualmente, con SQL Server Agent activo:

    EXEC msdb.dbo.sp_start_job
         @job_name = N'Northwind - Reporte mensual';

    El archivo CSV se genera mediante scripts/exportar_reporte_northwind.bat.
    Un SQL Server Agent ejecutándose en Linux no puede ejecutar archivos .bat;
    en ese caso, ejecuta el .bat desde Windows Task Scheduler o usa cron con
    sqlcmd. El job T-SQL sí deja el reporte almacenado en Northwind.
*/
