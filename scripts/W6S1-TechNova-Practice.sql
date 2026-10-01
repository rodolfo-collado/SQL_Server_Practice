-- ===================================
-- === 1. NODO A: TechNova_Central ===
-- ===================================

USE master;

CREATE DATABASE TechNova_Central;

USE TechNova_Central;

CREATE SCHEMA comercial;

CREATE SCHEMA ventas;

CREATE TABLE comercial.Clientes
(
    ClienteId     INT IDENTITY (1,1) PRIMARY KEY,
    RazonSocial   NVARCHAR(120)  NOT NULL,
    Contacto      NVARCHAR(100),
    Ciudad        NVARCHAR(80)   NOT NULL,
    Telefono      NVARCHAR(30),
    Correo        NVARCHAR(120),
    LimiteCredito DECIMAL(12, 2) NOT NULL,
    Activo        BIT            NOT NULL DEFAULT 1,

);

CREATE TABLE ventas.Pedidos
(
    PedidoID    INT IDENTITY (1001,1) PRIMARY KEY,
    ClienteID   INT            NOT NULL,
    FechaPedido DATE           NOT NULL,
    Estado      NVARCHAR(20)   NOT NULL,
    total       DECIMAL(12, 2) NOT NULL DEFAULT 0,
    CONSTRAINT FK_Pedidos_Clientes FOREIGN KEY (ClienteID)
        REFERENCES comercial.Clientes (ClienteID),
    CONSTRAINT CK_Pedidos_Estado
        CHECK (Estado IN ('Pendiente', 'Procesando', 'Facturado', 'Entregado', 'Cancelado'))
);

CREATE TABLE ventas.DetallePedido
(
    DetalleID      INT IDENTITY (1,1) PRIMARY KEY,
    PedidoID       INT            NOT NULL,
    ProductoID     INT            NOT NULL,
    Cantidad       INT            NOT NULL,
    PrecioUnitario DECIMAL(12, 2) NOT NULL,
    CONSTRAINT FK_Detalle_Pedido FOREIGN KEY (PedidoID)
        REFERENCES ventas.Pedidos (PedidoID),
    CONSTRAINT CK_Detalle_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Detalle_Precio CHECK (PrecioUnitario > 0)
);

-- ========================================
-- === 2. Datos de Prueba: Sede Central ===
-- ========================================


USE TechNova_Central;

INSERT INTO comercial.Clientes
    (RazonSocial, Contacto, Ciudad, Telefono, Correo, LimiteCredito)
VALUES ('Soluciones Empresariales, S.A.', 'Ana López', 'Managua', '2255-1001', 'ana.lopez@technova.test', 15000),
       ('Comercial Delta', 'Carlos Ruiz', 'León', '2311-2002', 'carlos.ruiz@technova.test', 10000),
       ('Grupo Innovación', 'María Torres', 'Masaya', '2522-3003', 'maria.torres@technova.test', 20000),
       ('Servicios Digitales Nicaragua', 'José Hernández', 'Granada', '2552-4004', 'jose.hernandez@technova.test',
        12000),
       ('Corporación Alfa', 'Laura Martínez', 'Managua', '2255-5005', 'laura.martinez@technova.test', 25000);


INSERT INTO ventas.Pedidos (ClienteID, FechaPedido, Estado, Total)
VALUES (1, '2026-09-10', 'Facturado', 0),
       (2, '2026-09-11', 'Procesando', 0),
       (3, '2026-09-12', 'Pendiente', 0),
       (1, '2026-09-13', 'Entregado', 0),
       (4, '2026-09-14', 'Procesando', 0),
       (5, '2026-09-15', 'Pendiente', 0);

INSERT INTO ventas.DetallePedido
    (PedidoID, ProductoID, Cantidad, PrecioUnitario)
VALUES (1001, 1, 2, 850.00),
       (1001, 4, 3, 25.00),
       (1002, 2, 1, 1200.00),
       (1002, 5, 2, 45.00),
       (1003, 3, 2, 650.00),
       (1003, 6, 5, 18.00),
       (1004, 1, 1, 850.00),
       (1004, 7, 2, 35.00),
       (1005, 8, 2, 240.00),
       (1005, 4, 4, 25.00),
       (1006, 2, 2, 1200.00),
       (1006, 6, 3, 18.00);

UPDATE P
SET Total = X.TotalPedido
FROM ventas.Pedidos AS P
         INNER JOIN
     (SELECT PedidoID, SUM(Cantidad * PrecioUnitario) AS TotalPedido
      FROM ventas.DetallePedido
      GROUP BY PedidoID) AS X ON P.PedidoID = X.PedidoID;

-- === Consultas de verificación ===

-- Cantidad de clientes
SELECT COUNT(*) AS Cantidad_Clientes
FROM comercial.Clientes;

-- Cantidad de pedidos
SELECT COUNT(*) AS Cantidad_Pedidos
FROM ventas.Pedidos;

-- Cantidad de detalles
SELECT COUNT(*) AS Cantidad_Detalles
FROM ventas.DetallePedido;

-- Verificación de  relaciones entre las 3 tablas
SELECT COUNT(DISTINCT c.ClienteID) AS Total_Clientes,
       COUNT(DISTINCT p.PedidoID)  AS Total_Pedidos,
       COUNT(DISTINCT d.DetalleID) AS Total_Detalles
FROM ventas.DetallePedido AS d
         INNER JOIN ventas.Pedidos AS p
                    ON p.PedidoID = d.PedidoID
         INNER JOIN comercial.Clientes AS c
                    ON c.ClienteId = p.ClienteID;

-- ==================================
-- === 3. Nodo B: TechNova_Bodega ===
-- ==================================

USE master;

CREATE DATABASE TechNova_Bodega;

USE TechNova_Bodega;

CREATE SCHEMA inventario;

CREATE TABLE inventario.Productos
(
    ProductoID     INT IDENTITY (1,1) PRIMARY KEY,
    NombreProducto NVARCHAR(120)  NOT NULL,
    Categoria      NVARCHAR(80)   NOT NULL,
    PrecioVenta    DECIMAL(12, 2) NOT NULL,
    Stock          INT            NOT NULL,
    StockMinimo    INT            NOT NULL,
    Activo         BIT            NOT NULL DEFAULT 1,
    CONSTRAINT CK_Productos_Precio CHECK (PrecioVenta > 0),
    CONSTRAINT CK_Productos_Stock CHECK (Stock >= 0)
);

CREATE TABLE inventario.MovimientosInventario
(
    MovimientoID    INT IDENTITY (1,1) PRIMARY KEY,
    ProductoID      INT          NOT NULL,
    FechaMovimiento DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    TipoMovimiento  NVARCHAR(20) NOT NULL,
    Cantidad        INT          NOT NULL,
    Referencia      NVARCHAR(100),
    CONSTRAINT FK_Movimientos_Producto FOREIGN KEY (ProductoID)
        REFERENCES inventario.Productos (ProductoID),
    CONSTRAINT CK_Movimiento_Tipo CHECK (TipoMovimiento IN ('Entrada', 'Salida')),
    CONSTRAINT CK_Movimiento_Cantidad CHECK (Cantidad > 0)
);

-- =======================================
-- === 4. Datos de Prueba: Sede Bodega ===
-- =======================================

USE TechNova_Bodega;

INSERT INTO inventario.Productos
    (NombreProducto, Categoria, PrecioVenta, Stock, StockMinimo)
VALUES ('Laptop Empresarial 15"', 'Computadoras', 850.00, 20, 5),
       ('Laptop Profesional 14"', 'Computadoras', 1200.00, 12, 4),
       ('Monitor LED 27"', 'Monitores', 650.00, 15, 5),
       ('Mouse Inalámbrico', 'Accesorios', 25.00, 50, 10),
       ('Teclado Mecánico', 'Accesorios', 45.00, 35, 10),
       ('Cable HDMI 2m', 'Accesorios', 18.00, 60, 15),
       ('Hub USB-C', 'Accesorios', 35.00, 25, 8),
       ('Router Empresarial', 'Redes', 240.00, 18, 5);


INSERT INTO inventario.MovimientosInventario
    (ProductoID, FechaMovimiento, TipoMovimiento, Cantidad, Referencia)
VALUES (1, '2026-09-01', 'Entrada', 20, 'COMPRA-001'),
       (2, '2026-09-01', 'Entrada', 12, 'COMPRA-001'),
       (3, '2026-09-02', 'Entrada', 15, 'COMPRA-002'),
       (4, '2026-09-02', 'Entrada', 50, 'COMPRA-002'),
       (5, '2026-09-03', 'Entrada', 35, 'COMPRA-003'),
       (6, '2026-09-03', 'Entrada', 60, 'COMPRA-003'),
       (7, '2026-09-04', 'Entrada', 25, 'COMPRA-004'),
       (8, '2026-09-04', 'Entrada', 18, 'COMPRA-004'),
       (1, '2026-09-10', 'Salida', 2, 'PEDIDO-1001'),
       (4, '2026-09-10', 'Salida', 3, 'PEDIDO-1001'),
       (2, '2026-09-11', 'Salida', 1, 'PEDIDO-1002'),
       (5, '2026-09-11', 'Salida', 2, 'PEDIDO-1002');

-- === Consultas de verificación ===

-- Cantidad de productos y movimientos
SELECT COUNT(DISTINCT p.ProductoID)   AS Cantidad_Productos,
       COUNT(DISTINCT m.MovimientoID) AS Cantidad_Movimientos
FROM inventario.MovimientosInventario AS m
         INNER JOIN inventario.Productos P
                    ON m.ProductoID = P.ProductoID;

-- Consulta agrupada por tipo de movimiento
SELECT TipoMovimiento,
       COUNT(*) AS Cantidad_Movimientos
FROM inventario.MovimientosInventario
GROUP BY TipoMovimiento;

-- =========================================
-- === 5. Diseño de identidades y acceso ===
-- =========================================

-- Operador Ventas (mssql-dev)
USE master;

CREATE LOGIN Operador_Ventas
    WITH PASSWORD = 'VentasOperator2350@';

USE TechNova_Central

CREATE USER OperadorVentas
    FOR LOGIN Operador_Ventas;

-- Operador Inventario (mssql-lab)
USE master;

CREATE LOGIN Operador_Inventario
    WITH PASSWORD = 'InventarioOperator2350@';

USE TechNova_Bodega

CREATE USER OperadorInventario
    FOR LOGIN Operador_Inventario;

-- Consulta Remota (mssql-lab)
USE master;

CREATE LOGIN Consulta_Remota
    WITH PASSWORD = 'RemoteQuery2350@';

USE TechNova_Bodega

CREATE USER ConsultaRemota
    FOR LOGIN Consulta_Remota;

-- === Consultas de verificación ===

-- TechNova_Central (mssql-dev)
USE TechNova_Central;

SELECT sp.name AS Login_Name,
       dp.name AS User_Name
FROM master.sys.server_principals AS sp
         INNER JOIN sys.database_principals AS dp
                    ON sp.sid = dp.sid
WHERE sp.name = 'Operador_Ventas';

-- TechNova_Bodega (mssql-lab)
USE TechNova_Bodega;

SELECT sp.name AS Login_Name,
       dp.name AS User_Name
FROM master.sys.server_principals AS sp
         INNER JOIN sys.database_principals AS dp
                    ON sp.sid = dp.sid
WHERE sp.name IN (
                  'Operador_Inventario',
                  'Consulta_Remota'
    );

-- Ver loggins del servidor
USE master;
GO

SELECT SP.name                                       AS Login_Name,
       SP.type_desc                                  AS Login_Type,
       SP.is_disabled                                AS Is_Disabled,
       SP.default_database_name                      AS Default_Database,
       SP.default_language_name                      AS Default_Language,
       SP.create_date                                AS Created_Date,
       SP.modify_date                                AS Modified_Date,
       SL.is_policy_checked                          AS Password_Policy_Checked,
       SL.is_expiration_checked                      AS Password_Expiration_Checked,
       SL.password_hash                              AS Password_Hash,
       LOGINPROPERTY(SP.name, 'IsLocked')            AS Is_Locked,
       LOGINPROPERTY(SP.name, 'BadPasswordCount')    AS Bad_Password_Count,
       LOGINPROPERTY(SP.name, 'DaysUntilExpiration') AS Days_Until_Expiration
FROM sys.server_principals AS SP
         LEFT JOIN sys.sql_logins AS SL
                   ON SL.principal_id = SP.principal_id
WHERE SP.type IN
      (
       'S', -- SQL_LOGIN
       'U', -- WINDOWS_LOGIN
       'G' -- WINDOWS_GROUP
          )
ORDER BY SP.name;

-- =========================================
-- === 6. Creación y asignación de Roles ===
-- =========================================

-- Permisos Operador Ventas (mssql-dev)
USE TechNova_Central;

CREATE ROLE rol_ventas;

GRANT SELECT ON comercial.Clientes TO rol_ventas;
GRANT SELECT, INSERT ON ventas.DetallePedido TO rol_ventas;
GRANT SELECT, INSERT ON ventas.Pedidos TO rol_ventas;

ALTER ROLE rol_ventas
    ADD MEMBER OperadorVentas;


-- Permisos Operador Inventario (mssql-lab)
USE TechNova_Bodega;

CREATE ROLE rol_inventario;

GRANT SELECT ON inventario.Productos TO rol_inventario;
GRANT SELECT, INSERT ON inventario.MovimientosInventario TO rol_inventario;

ALTER ROLE rol_inventario
    ADD MEMBER OperadorInventario;

-- Permisos Consulta Remota (mssql-lab)
USE TechNova_Bodega;

CREATE ROLE rol_consulta_remota;

GRANT SELECT ON inventario.Productos TO rol_consulta_remota;

ALTER ROLE rol_consulta_remota
    ADD MEMBER ConsultaRemota;

-- === Consultas de verificación ===

-- TechNova_Central (mssql-dev)
USE TechNova_Central;

SELECT r.name                         AS Role_Name,
       m.name                         AS Member_Name,
       p.permission_name              AS Permission,
       p.state_desc                   AS Permission_State,
       OBJECT_SCHEMA_NAME(p.major_id) AS Schema_Name,
       OBJECT_NAME(p.major_id)        AS Object_Name
FROM sys.database_role_members AS drm
         INNER JOIN sys.database_principals AS r
                    ON drm.role_principal_id = r.principal_id
         INNER JOIN sys.database_principals AS m
                    ON drm.member_principal_id = m.principal_id
         INNER JOIN sys.database_permissions AS p
                    ON p.grantee_principal_id = r.principal_id
WHERE r.name = 'rol_ventas'
ORDER BY r.name,
         Object_Name,
         Permission;

-- TechNova_Bodega (mssql-lab)
USE TechNova_Bodega;

SELECT r.name                         AS Role_Name,
       m.name                         AS Member_Name,
       p.permission_name              AS Permission,
       p.state_desc                   AS Permission_State,
       OBJECT_SCHEMA_NAME(p.major_id) AS Schema_Name,
       OBJECT_NAME(p.major_id)        AS Object_Name
FROM sys.database_role_members AS drm
         INNER JOIN sys.database_principals AS r
                    ON drm.role_principal_id = r.principal_id
         INNER JOIN sys.database_principals AS m
                    ON drm.member_principal_id = m.principal_id
         INNER JOIN sys.database_permissions AS p
                    ON p.grantee_principal_id = r.principal_id
WHERE r.name IN (
                 'rol_inventario',
                 'rol_consulta_remota'
    )
ORDER BY r.name,
         Object_Name,
         Permission;

-- ==================================================
-- === 7. Pruebas de permisos y mínimo privilegio ===
-- ==================================================

-- Operador Ventas (mssql-dev)
EXECUTE AS USER = 'OperadorVentas';

SELECT *
FROM comercial.Clientes;

INSERT INTO ventas.Pedidos (ClienteID, FechaPedido, Estado, total)
VALUES (1, '2026-09-10', 'Facturado', 0)

DELETE
FROM ventas.Pedidos
WHERE PedidoID = 2003;

DROP TABLE ventas.Pedidos;

UPDATE ventas.Pedidos
SET Estado = 'Cancelado'
WHERE PedidoID = 1002;

REVERT;

-- Operador Inventario (mssql-lab)
USE TechNova_Bodega;

EXECUTE AS USER = 'OperadorInventario'

SELECT *
FROM inventario.Productos;

INSERT INTO inventario.MovimientosInventario
    (ProductoID, FechaMovimiento, TipoMovimiento, Cantidad, Referencia)
VALUES (1, '2026-09-03', 'Entrada', 34, 'PEDIDO-1003')

DELETE
FROM inventario.MovimientosInventario
WHERE Referencia = 'PEDIDO-1003';

REVERT;

-- Consulta Remota (mssql-lab)
USE TechNova_Bodega;

EXECUTE AS USER = 'ConsultaRemota';

SELECT *
FROM inventario.Productos;

INSERT INTO inventario.Productos
    (NombreProducto, Categoria, PrecioVenta, Stock, StockMinimo)
VALUES ('Lenovo Thinkpad T14 gen 2', 'Computadoras', 600, 40, 10)

REVERT;

-- ==============================================
-- === 8. Configuración del servidor enlazado ===
-- ==============================================
USE master;

SELECT CONNECTIONPROPERTY('local_net_address')  AS ServerIP,
       CONNECTIONPROPERTY('local_tcp_port')     AS ServerPort,
       CONNECTIONPROPERTY('client_net_address') AS ClientIP;

IF EXISTS
    (SELECT 1
     FROM sys.servers
     WHERE name = N'SERVIDOR_BODEGA')
    BEGIN
        EXEC master.dbo.sp_dropserver
             @server = N'SERVIDOR_BODEGA',
             @droplogins = N'droplogins';
    END


EXEC master.dbo.sp_addlinkedserver
     @server = N'SERVIDOR_BODEGA',
     @srvproduct = N'',
     @provider = N'MSOLEDBSQL',
     @datasrc = N'mssql-lab,1433',
     @provstr = N'Encrypt=Optional;TrustServerCertificate=Yes;User ID=Consulta_Remota;UID=Consulta_Remota',
     @catalog = N'TechNova_Bodega';

EXEC master.dbo.sp_addlinkedsrvlogin
     @rmtsrvname = N'SERVIDOR_BODEGA',
     @useself = N'False',
     @locallogin = 'Operador_Ventas',
     @rmtuser = N'Consulta_Remota',
     @rmtpassword = N'RemoteQuery2350@';

EXEC master.dbo.sp_droplinkedsrvlogin
     @rmtsrvname = N'SERVIDOR_BODEGA',
     @locallogin = NULL;

-- Probar conexión con el servidor
EXEC master.dbo.sp_testlinkedserver N'SERVIDOR_BODEGA';


-- Verificar logins
SELECT s.name                  AS Servidor,
       sp.name                 AS LoginLocal,
       ll.remote_name          AS LoginRemoto,
       ll.uses_self_credential AS UsaCredencialesPropias
FROM sys.linked_logins AS ll
         INNER JOIN sys.servers AS s
                    ON ll.server_id = s.server_id
         LEFT JOIN sys.server_principals AS sp
                   ON ll.local_principal_id = sp.principal_id
WHERE s.name = N'SERVIDOR_BODEGA';


-- Verificar datos del servidor
SELECT name        AS SERVIDOR_ENLAZADO,
       provider    AS PROVEEDOR,
       data_source AS ORIGEN,
       catalog     AS BASE_REMOTA
FROM sys.servers
WHERE name = N'SERVIDOR_BODEGA';



-- ======================================================
-- === 9. Consulta distribuida de pedidos y productos ===
-- ======================================================
USE TechNova_Central;
SELECT SUSER_SNAME() AS LoginActual,
       USER_NAME()   AS UsuarioActual,
       DB_NAME()     AS BaseDatosActual;


WITH ProductosBodega AS
         (SELECT ProductoID,
                 NombreProducto,
                 PrecioVenta,
                 Stock,
                 StockMinimo
          FROM [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos])
SELECT P.PedidoID,
       P.FechaPedido,
       C.RazonSocial,
       PR.NombreProducto,
       D.Cantidad,
       D.PrecioUnitario,
       D.Cantidad * D.PrecioUnitario AS Subtotal
FROM ventas.Pedidos AS P
         INNER JOIN comercial.Clientes AS C
                    ON C.ClienteID = P.ClienteID
         INNER JOIN ventas.DetallePedido AS D
                    ON D.PedidoID = P.PedidoID
         INNER JOIN ProductosBodega AS PR
                    ON PR.ProductoID = D.ProductoID
ORDER BY P.PedidoID,
         D.DetalleID;

-- UNION ALL complementario: unifica en un mismo reporte líneas de pedidos
-- locales y productos críticos remotos. No sustituye al JOIN anterior.
SELECT TipoRegistro,
       Identificador,
       FechaRegistro,
       Descripcion,
       Cantidad,
       PrecioUnitario,
       Subtotal
FROM (SELECT N'PEDIDO'                                              AS TipoRegistro,
             CONVERT(NVARCHAR(20), P.PedidoID)                      AS Identificador,
             P.FechaPedido                                          AS FechaRegistro,
             C.RazonSocial + N' / ' + PR.NombreProducto             AS Descripcion,
             D.Cantidad,
             D.PrecioUnitario,
             CONVERT(DECIMAL(12, 2), D.Cantidad * D.PrecioUnitario) AS Subtotal
      FROM ventas.Pedidos AS P
               INNER JOIN comercial.Clientes AS C
                          ON C.ClienteID = P.ClienteID
               INNER JOIN ventas.DetallePedido AS D
                          ON D.PedidoID = P.PedidoID
               INNER JOIN [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos] AS PR
                          ON PR.ProductoID = D.ProductoID
      UNION ALL
      SELECT N'INVENTARIO_CRITICO',
             CONVERT(NVARCHAR(20), PR.ProductoID),
             CONVERT(DATE, NULL),
             PR.NombreProducto,
             PR.Stock,
             PR.PrecioVenta,
             CONVERT(DECIMAL(12, 2), NULL)
      FROM [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos] AS PR
      WHERE PR.Stock <= PR.StockMinimo
        AND PR.Activo = 1) AS ResumenUnificado
ORDER BY TipoRegistro,
         Identificador;

-- ==========================================
-- === 10. Consulta de inventario crítico ===
-- ==========================================

-- Productos con stock mínimo y por debajo.
SELECT ProductoID,
       NombreProducto,
       Categoria,
       PrecioVenta,
       Stock,
       StockMinimo,
       StockMinimo - Stock AS UnidadesPorReponer
FROM [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos]
WHERE Stock <= StockMinimo
  AND Activo = 1
ORDER BY UnidadesPorReponer DESC,
         ProductoID;


-- =========================================
-- === 11. Abstracción mediante sinónimo ===
-- =========================================

USE master;


IF DB_ID(N'TechNova_Sinonimos') IS NULL
CREATE DATABASE TechNova_Sinonimos;

USE TechNova_Sinonimos;

IF NOT EXISTS
    (SELECT 1
     FROM sys.schemas
     WHERE name = N'reportes')
    EXEC (N'CREATE SCHEMA reportes AUTHORIZATION dbo');

IF NOT EXISTS
    (SELECT 1
     FROM sys.database_principals
     WHERE name = N'OperadorVentas')
CREATE USER OperadorVentas FOR LOGIN Operador_Ventas;

IF OBJECT_ID(N'reportes.ProductosBodega', N'SN') IS NULL
    EXEC (N'CREATE SYNONYM [reportes].[ProductosBodega]
          FOR [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos]');

GRANT SELECT ON OBJECT::[reportes].[ProductosBodega] TO OperadorVentas;

-- Referencia directa de cuatro partes (Ejecutar desde OperadorVentas)
USE TechNova_Central;

SELECT TOP (5) ProductoID,
               NombreProducto,
               Stock,
               StockMinimo
FROM [SERVIDOR_BODEGA].[TechNova_Bodega].[inventario].[Productos]
ORDER BY ProductoID;

-- La misma consulta utilizando el sinónimo (Ejecutar desde OperadorVentas)
USE TechNova_Sinonimos

SELECT TOP (5) ProductoID,
               NombreProducto,
               Stock,
               StockMinimo
FROM [reportes].[ProductosBodega]
ORDER BY ProductoID;


-- =====================================================
-- === 12. Verificación de integridad y recuperación ===
-- =====================================================

-- === mssql-dev ===
USE master;


-- Backup de TechNova_Central
DBCC CHECKDB ('TechNova_Central') WITH NO_INFOMSGS;

BACKUP DATABASE TechNova_Central
    TO DISK = '/var/opt/mssql/backup/TechNova_Central.bak'
    WITH INIT,
    NAME = 'Backup completo - TechNova_Central',
    STATS = 10;

-- Verificación
RESTORE VERIFYONLY FROM DISK = '/var/opt/mssql/backup/TechNova_Central.bak';

-- Simular pérdida de datos
USE TechNova_Central

ALTER TABLE ventas.DetallePedido
    DROP CONSTRAINT FK_Detalle_Pedido;

DROP TABLE ventas.Pedidos;

-- Restaurar base de datos desde archivo .bak
USE master;

ALTER DATABASE TechNova_Central
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE TechNova_Central
    FROM DISK = '/var/opt/mssql/backup/TechNova_Central.bak'
    WITH REPLACE,
    STATS = 10;

ALTER DATABASE TechNova_Central
    SET MULTI_USER;

-- Verificar la restauración
USE TechNova_Central

SELECT *
FROM ventas.Pedidos;

DBCC CHECKDB ('TechNova_Central') WITH NO_INFOMSGS;


-- === mssql-lab ===
USE master;

-- Backup de TechNova_Bodega (mssql-lab)
DBCC CHECKDB ('TechNova_Bodega') WITH NO_INFOMSGS;

BACKUP DATABASE TechNova_Bodega
    TO DISK = '/var/opt/mssql/backup/TechNova_Bodega.bak'
    WITH INIT,
    NAME = 'Backup completo - TechNova_Central',
    STATS = 10;

-- Verificación
RESTORE VERIFYONLY FROM DISK = '/var/opt/mssql/backup/TechNova_Bodega.bak';

-- Simular pérdida de datos
USE TechNova_Bodega;

ALTER TABLE inventario.MovimientosInventario
    DROP CONSTRAINT FK_Movimientos_Producto;

DROP TABLE inventario.Productos;

-- Restaurar bases de datos desde archivo .bak
USE master;

ALTER DATABASE TechNova_Bodega
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE TechNova_Bodega
    FROM DISK = '/var/opt/mssql/backup/TechNova_Bodega.bak'
    WITH REPLACE,
    STATS = 10;

ALTER DATABASE TechNova_Bodega
    SET MULTI_USER;

-- Verificar la restauración

USE TechNova_Bodega;

SELECT *
FROM inventario.Productos;

DBCC CHECKDB ('TechNova_Bodega') WITH NO_INFOMSGS;


