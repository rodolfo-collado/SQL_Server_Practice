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

-- =========================================
-- === 6. Creación y asignación de Roles ===
-- =========================================

-- Permisos Operador Ventas (mssql-dev)
USE TechNova_Central;

CREATE ROLE rol_ventas;

GRANT SELECT ON comercial.Clientes TO rol_ventas;
GRANT INSERT ON ventas.DetallePedido TO rol_ventas;
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
VALUES (1, '2026-`09-10', 'Facturado', 0)

DROP TABLE ventas.Pedidos;

UPDATE ventas.Pedidos
SET Estado = 'Cancelado'
WHERE PedidoID = 1002;

REVERT;

-- Operador Inventario (mssql-lab)
EXECUTE AS USER = 'OperadorInventario'

SELECT *
FROM inventario.Productos;

INSERT INTO inventario.MovimientosInventario
    (ProductoID, FechaMovimiento, TipoMovimiento, Cantidad, Referencia)
values (1, '2026-09-03', 'Entrada', 34, 'PEDIDO-1003')

delete from inventario.Productos where ProductoID = 1;

REVERT;

-- Consulta Remota (mssql-lab)


-- ==============================================
-- === 8. Configuración del servidor enlazado ===
-- ==============================================


-- ======================================================
-- === 9. Consulta distribuida de pedidos y productos ===
-- ======================================================


-- ==========================================
-- === 10. Consulta de inventario crítico ===
-- ==========================================


-- =========================================
-- === 11. Abstracción mediante sinónimo ===
-- =========================================


-- =====================================================
-- === 12. Verificación de integridad y recuperación ===
-- =====================================================

