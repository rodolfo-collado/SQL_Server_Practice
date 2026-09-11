-- ===================================================================
-- === Práctica de linkeo de servidores (instancias) de SQL Server ===
-- ===================================================================

-- 1. Descubrir IP del servidor, del cliente y puerto de la instancia

SELECT CONNECTIONPROPERTY('local_net_address')  AS ServerIP,
       CONNECTIONPROPERTY('local_tcp_port')     AS ServerPort,
       CONNECTIONPROPERTY('client_net_address') AS ClientIP;

-- Pasos 2 y 3 en guía.


-- ==========================================================================
-- === Fase 0.5: Preparación de la identidad remota (mssql-lab | destino) ===
-- ==========================================================================

-- 1. Creación del Login de puente remota
USE master

CREATE LOGIN [LoginRemoto_UAM]
    WITH PASSWORD = 'PasswordSeguro123!',
    CHECK_POLICY = ON;

-- 2. Conexión a la base de datos objetivo
CREATE DATABASE BaseDatosDestino;
USE [BaseDatosDestino];

-- 3. Creación del usuario de base de datos
CREATE USER [UsuarioRemoto_UAM]
    FOR LOGIN [LoginRemoto_UAM];

-- 4. Asignación de permisos de lectura (Principio de mínimo privilegio)
ALTER ROLE [db_datareader]
    ADD MEMBER [UsuarioRemoto_UAM];

-- 5. Creación de la tabla remota
CREATE TABLE dbo.Estudiantes
(
    ID     INT PRIMARY KEY,
    NOMBRE VARCHAR(100) NOT NULL,
    CIUDAD VARCHAR(100) NOT NULL,
    EDAD   INT          NOT NULL
);

-- 6. Insersión de los datos a la tabla
INSERT INTO dbo.Estudiantes (ID, NOMBRE, CIUDAD, EDAD)
VALUES (1, 'Ana', 'Managua', 20),
       (2, 'Carlos', 'León', 19),
       (3, 'María', 'Managua', 17),
       (4, 'José', 'Managua', 22);

-- Verificación de datos
SELECT *
FROM dbo.Estudiantes;


-- =======================================================
-- === Fase 1: Registro del servidor enlazado (origen) ===
-- =======================================================

-- 1. Ejecución del proceso `sp_addlinkedserver` para conectar con la otra instancia
USE master;

EXEC master.dbo.sp_addlinkedserver
     @server = N'SRV_UAM_DISTRIBUIDO',
     @srvproduct = N'',
     @provider = N'MSOLEDBSQL',
     @datasrc = N'mssql-lab,1433',
     @provstr = N'Encrypt=Optional';

-- =======================================================================
-- === Fase 2: Configuración del mapeo de seguridad (origen | destino) ===
-- =======================================================================

-- 1. Creación del login para mapeo de credenciales en la destino
CREATE LOGIN EstudianteLocal
    WITH PASSWORD = 'LocalPassword123!';

-- 2. Ejecución del mapeo de credenciales
EXEC master.dbo.sp_addlinkedsrvlogin
     @rmtsrvname = N'SRV_UAM_DISTRIBUIDO',
     @useself = N'false',
     @locallogin = N'EstudianteLocal',
     @rmtuser = N'LoginRemoto_UAM',
     @rmtpassword = N'PasswordSeguro123!';

-- (test) borrar servidor enlazado
EXEC master.dbo.sp_dropserver
     @server = N'SRV_UAM_DISTRIBUIDO',
     @droplogins = 'droplogins';

-- (test) Ver registro del servidor enlazado
SELECT name,
       provider,
       data_source,
       provider_string
FROM sys.servers
WHERE name = 'SRV_UAM_DISTRIBUIDO';

-- ===============================================================
-- === Fase 3: Implementación de sinónimos e interoperabilidad ===
-- ===============================================================

-- 1. Crear base de datos de origen
CREATE DATABASE BaseDatosOrigen;
USE BaseDatosOrigen;


-- 2. Crear synonym con BaseDatosOrigen
CREATE SYNONYM dbo.Estudiantes_Remotos
    FOR [SRV_UAM_DISTRIBUIDO].[BaseDatosDestino].[dbo].[Estudiantes];

-- 3. Prueba de integridad del synonym
SELECT *
FROM dbo.Estudiantes_Remotos;

-- 4. Consulta de prueba
SELECT ID, NOMBRE, CIUDAD, EDAD
FROM dbo.Estudiantes_Remotos
WHERE CIUDAD = 'Managua'
  AND EDAD >= 18;

-- (test) Probar conexión remota sin synonym
SELECT *
FROM [SRV_UAM_DISTRIBUIDO].[BaseDatosDestino].[dbo].[Estudiantes];

