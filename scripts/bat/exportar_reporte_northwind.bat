@echo off
setlocal EnableExtensions

REM Exporta el ultimo reporte generado por Northwind a CSV.
REM Uso por defecto: exportar_reporte_northwind.bat localhost,1433
REM Autenticacion:
REM   -E si no se definen NORTHWIND_SQL_USER y NORTHWIND_SQL_PASSWORD.
REM   -U/-P si se definen ambas variables de entorno.

set "SERVER=%~1"
if not defined SERVER set "SERVER=localhost,1433"

set "DATABASE=Northwind"
set "OUTPUT_DIR=%~dp0..\reports\northwind"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
set "OUTPUT_FILE=%OUTPUT_DIR%\reporte_northwind_%STAMP%.csv"

set "QUERY=SET NOCOUNT ON; SELECT N'PeriodoInicio',N'PeriodoFin',N'PaisCliente',N'Pedidos',N'LineasPedido',N'VentasNetas' UNION ALL SELECT CONVERT(nvarchar(10),PeriodoInicio,23),CONVERT(nvarchar(10),PeriodoFin,23),PaisCliente,CONVERT(nvarchar(20),Pedidos),CONVERT(nvarchar(20),LineasPedido),CONVERT(nvarchar(40),VentasNetas) FROM dbo.ReporteVentasMensual WHERE ReporteID=(SELECT MAX(ReporteID) FROM dbo.ReporteVentasMensual);"

where sqlcmd >nul 2>&1
if errorlevel 1 (
    echo ERROR: sqlcmd no esta disponible en PATH.
    exit /b 1
)

if defined NORTHWIND_SQL_USER if defined NORTHWIND_SQL_PASSWORD (
    sqlcmd -S "%SERVER%" -d "%DATABASE%" -U "%NORTHWIND_SQL_USER%" -P "%NORTHWIND_SQL_PASSWORD%" -C -W -h-1 -s "," -Q "%QUERY%" -o "%OUTPUT_FILE%"
) else (
    sqlcmd -S "%SERVER%" -d "%DATABASE%" -E -C -W -h-1 -s "," -Q "%QUERY%" -o "%OUTPUT_FILE%"
)

if errorlevel 1 (
    echo ERROR: no se pudo exportar el reporte.
    exit /b 1
)

echo Reporte generado: %OUTPUT_FILE%
exit /b 0
