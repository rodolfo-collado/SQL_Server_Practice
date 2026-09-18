-- 1. Identificar la instancia, bases de datos y servidor.

SELECT @@SERVERNAME                                       AS ServerName,
       CAST(SERVERPROPERTY('MachineName') AS VARCHAR(50)) AS HostName;

SELECT name
FROM sys.databases
ORDER BY name;

SELECT name,
       provider,
       data_source,
       is_linked
FROM sys.servers;

-- 2. Crear las bases de datos.
-- mssql-dev
CREATE DATABASE Ventas_Norte;
-- mssql-lab
CREATE DATABASE Ventas_Sur;

-- 3. Crear un usuario con acceso a la base de datos Venta_Sur para el login remoto (mssql-lab)

USE Ventas_Sur;

CREATE USER UsuarioRemoto_UAM
FOR LOGIN LoginRemoto_UAM;

ALTER ROLE db_datareader
ADD MEMBER UsuarioRemoto_UAM;

-- 4. Crear tablas (Ventas_Norte) en mssql-dev

USE Ventas_Norte;

CREATE TABLE Clientes
(
    IdCliente INT PRIMARY KEY,
    Nombre    VARCHAR(100),
    Ciudad    VARCHAR(100)
);

CREATE TABLE Productos
(
    IdProducto INT PRIMARY KEY,
    Nombre     VARCHAR(100),
    Precio     DECIMAL(10, 2)
);

CREATE TABLE Ventas
(
    IdVenta   INT PRIMARY KEY,
    Fecha     DATE,
    IdCliente INT,
    FOREIGN KEY (IdCliente) REFERENCES Clientes (IdCliente)
);

-- 5. Crear tablas (Ventas_Sur) en mssql-lab

USE Ventas_Sur;

CREATE TABLE Clientes
(
    IdCliente INT PRIMARY KEY,
    Nombre    VARCHAR(100),
    Ciudad    VARCHAR(100)
);

CREATE TABLE Productos
(
    IdProducto INT PRIMARY KEY,
    Nombre     VARCHAR(100),
    Precio     DECIMAL(10, 2)
);

CREATE TABLE Ventas
(
    IdVenta   INT PRIMARY KEY,
    Fecha     DATE,
    IdCliente INT,
    FOREIGN KEY (IdCliente) REFERENCES Clientes (IdCliente)
);

-- 6. Insertar datos de clientes y productos en ambas instancias.

INSERT INTO Clientes
VALUES (1, 'Juan Perez', 'Managua');
INSERT INTO Clientes
VALUES (2, 'Maria Lopez', 'Masaya');

INSERT INTO Productos
VALUES (1, 'Laptop', 800);
INSERT INTO Productos
VALUES (2, 'Mouse', 20);


-- 7. Insertar Ventas_Norte en mssql-dev.

USE Ventas_Norte;

INSERT INTO Ventas
VALUES (1, '2026-01-10', 1);
INSERT INTO Ventas
VALUES (2, '2026-01-12', 2);


-- 8. Insertar Ventas_Sur en mssql-lab

USE Ventas_Sur;

INSERT INTO Ventas
VALUES (3, '2026-01-15', 1);
INSERT INTO Ventas
VALUES (4, '2026-01-18', 2);


-- 9. Consultas locales para cada instancia

-- mssql-dev
SELECT *
FROM Ventas_Norte.dbo.Ventas;
-- mssql-lab
SELECT *
FROM Ventas_Sur.dbo.Ventas;

-- 10. Consulta distribuida

SELECT *
FROM Ventas_Norte.dbo.Ventas
UNION
SELECT *
FROM [SRV_UAM_DISTRIBUIDO].[Ventas_Sur].[dbo].[Ventas];


-- 11. JOIN distribuido

USE Ventas_Norte;

SELECT v.IdVenta, v.Fecha, c.Nombre
FROM dbo.Ventas AS v
         JOIN dbo.Clientes AS c
              ON v.IdCliente = c.IdCliente

UNION

SELECT v.IdVenta, v.Fecha, c.Nombre
FROM [SRV_UAM_DISTRIBUIDO].[Ventas_Sur].[dbo].[Ventas] AS v
         JOIN [SRV_UAM_DISTRIBUIDO].[Ventas_Sur].[dbo].[Clientes] AS c
              ON v.IdCliente = c.IdCliente;

-- 12. Consulta con filtro

USE Ventas_Norte;

SELECT *
FROM (SELECT *
      FROM dbo.Ventas

      UNION

      SELECT *
      FROM [SRV_UAM_DISTRIBUIDO].[Ventas_Sur].[dbo].[Ventas]) AS VentasGlobal
WHERE Fecha > '2026-01-12';

