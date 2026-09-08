-- ====================================
-- === MISIÓN 1: CREAR LA IDENTIDAD ===
-- ====================================

USE master;

CREATE LOGIN Analista
    WITH PASSWORD = 'analizer_SQL2026!#';

USE Northwind;

CREATE USER Analista FOR LOGIN Analista;

ALTER ROLE db_datareader ADD MEMBER Analista;

-- ==> PRUEBAS

-- SELECT

SELECT CategoryName AS Categoria, Description AS Descripcion
FROM Categories AS c;

-- INSERT

INSERT INTO Customers (CustomerID, CompanyName, Country)
VALUES ('TEST1', 'Empresa Prueba', 'Nicaragua');

-- UPDATE

UPDATE Customers
SET CompanyName = 'Nuevo Nombre'
WHERE CustomerID = 'TEST1';

-- DELETE

DELETE
FROM Customers
WHERE CustomerID = 'TEST1';

-- CREATE TABLE

CREATE TABLE Prueba
(
    id     INT PRIMARY KEY,
    Nombre VARCHAR(100),
    fecha  DATETIME2
)

-- ALTER TABLE

ALTER TABLE Prueba
    ADD edad INT;

-- DROP TABLE

DROP TABLE Prueba;


-- ========================================
-- === MISIÓN 2: EXPLORACIÓN AUTORIZADA ===
-- ========================================

-- 1. Encuentra 5 clientes y muestra su nombre y país

SELECT TOP 5 CompanyName AS Nombre, Country AS País
FROM Customers;

-- 2. Identifica los 5 productos más caros

SELECT TOP 5 ProductName AS Nombre_Producto, UnitPrice AS Precio
FROM Products
ORDER BY UnitPrice DESC;

-- 3. ¿Cuántos productos existen ?

SELECT COUNT(*) AS Cantidad_Productos
FROM Products;

-- 4. Calcula el precio promedio de los productos

SELECT AVG(UnitPrice) AS Precio_Promedio
FROM Products;

-- 5. Encuentra cuántos clientes existen por país

SELECT Country, COUNT(*) AS TotalClientes
FROM Customers
GROUP BY Country
ORDER BY TotalClientes DESC;


-- =============================================
-- === MISIÓN 3: INTENTO DE ACCESO PROHIBIDO ===
-- =============================================

-- 1. Agregar un nuevo registro

INSERT INTO Categories (CategoryName, Description, Picture)
VALUES ('Nicaraguan Food',
        'Gallopinto, nacatamal, indio viejo, Baho',
        NULL);

-- 2. Modificar un registro

UPDATE Categories
SET CategoryName = 'Nica Food'
WHERE CategoryName = 'Nicaraguan Food';

-- 3. Borrar un registro

DELETE
FROM Categories
WHERE CategoryName = 'Nica Food';

-- 4. Crear una tabla

CREATE TABLE Prueba2
(
    Id            INT PRIMARY KEY,
    Cliente       VARCHAR(100),
    FechaRegistro DATETIME2
);

-- 5. Modificar una tabla

ALTER TABLE Prueba
    ADD Pais VARCHAR(50);

-- 6. Eliminar una tabla

DROP TABLE Prueba;


-- ===========================================
-- === MISIÓN 4: AUDITORÍA DE  PRIVILEGIOS ===
-- ===========================================

-- Consulta de verificación de roles

SELECT DP1.name AS DatabaseRoleName, ISNULL(DP2.name, 'No hay miembros') AS DatabaseUserName
FROM sys.database_role_members AS DRM
         RIGHT OUTER JOIN sys.database_principals AS DP1 ON DRM.role_principal_id = DP1.principal_id
         LEFT OUTER JOIN sys.database_principals AS DP2 ON DRM.member_principal_id = DP2.principal_id
WHERE DP2.name = 'Analista';



