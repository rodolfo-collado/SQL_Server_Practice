-- 1. Crear base de datos de prueba
CREATE DATABASE EmpresaDB;
USE EmpresaDB;

-- 2. Crear esquemas
CREATE SCHEMA Ventas;
CREATE SCHEMA RRHH;

--3. Crear tablas en esquemas diferentes
CREATE TABLE Ventas.Clientes
(
    IdCliente INT PRIMARY KEY,
    Nombre    VARCHAR(100) NOT NULL,
    Telefono  VARCHAR(20),
    Correo    VARCHAR(100)
);

CREATE TABLE Ventas.Facturas
(
    IdFactura INT PRIMARY KEY,
    IdCliente INT  NOT NULL,
    Fecha     DATE NOT NULL,
    Total     DECIMAL(10, 2),
    CONSTRAINT FK_Facturas_Clientes
        FOREIGN KEY (IdCliente)
            REFERENCES Ventas.Clientes (IdCliente)
);

CREATE TABLE RRHH.Empleados
(
    IdEmpleado INT PRIMARY KEY,
    Nombre     VARCHAR(100) NOT NULL,
    Cargo      VARCHAR(50),
    Salario    DECIMAL(10, 2)
);

-- 4. Insertar datos de prueba
INSERT INTO Ventas.Clientes
VALUES (1, 'Ana López', '8888-1111', 'ana@correo.com'),
       (2, 'Carlos Pérez', '8888-2222', 'carlos@correo.com');

INSERT INTO RRHH.Empleados
VALUES (1, 'María Gómez', 'Gerente', 2500),
       (2, 'José Ruiz', 'Vendedor', 1200);
GO

SELECT *
FROM Ventas.Clientes;
SELECT *
FROM RRHH.Empleados;

-- 5. Crear usuarios
CREATE USER usuario_ventas WITHOUT LOGIN;
CREATE USER usuario_rrhh WITHOUT LOGIN;


-- 6. Crear roles y añadir usuarios
CREATE ROLE rol_ventas;
CREATE ROLE rol_rrhh;


ALTER ROLE rol_ventas
    ADD MEMBER usuario_ventas;

ALTER ROLE rol_rrhh
    ADD MEMBER usuario_rrhh;

-- 7. Dar permisos sobre esquemas
GRANT SELECT, INSERT
    ON SCHEMA::Ventas
    TO rol_ventas;


GRANT SELECT
    ON SCHEMA::RRHH
    TO rol_rrhh;

-- 8 Probar los permisos
EXECUTE AS USER = 'usuario_ventas';

SELECT *
FROM Ventas.Clientes;
SELECT *
FROM RRHH.Empleados;

REVERT;

-- 9. Permisos sobre una tabla específica
GRANT SELECT
    ON Ventas.Clientes
    TO usuario_rrhh;

-- 10. Quitar o negar permisos
REVOKE SELECT
    ON Ventas.Clientes
    FROM usuario_rrhh;

DENY DELETE
    ON SCHEMA::Ventas
    TO rol_ventas;

-- ===========================
-- === PRÁCTICA ESTUDIANTE ===
-- ===========================

-- 1. Crear un tercer esquema llamado inventario

CREATE SCHEMA Inventario;

-- 2. Crear las tablas Inventario.Categorias e Inventario.Productos y relacionarlas mediante una llave foránea

CREATE TABLE Inventario.Categorias
(
    CategoriaID     INT PRIMARY KEY,
    CategoriaNombre VARCHAR(60),
    Descripcion     VARCHAR(100)
)

CREATE TABLE Inventario.Productos
(
    ProductoID      INT PRIMARY KEY,
    ProductoNombre  VARCHAR(60),
    CategoriaID     INT FOREIGN KEY REFERENCES Inventario.Categorias,
    PrecioUnidad    DECIMAL,
    UnidadesEnStock INT,
)

-- 3. Registrar al menos 5 productos

INSERT INTO Inventario.Categorias (CategoriaID, CategoriaNombre, Descripcion)
VALUES (1, 'Bebidas', 'Bebidas frías y calientes'),
       (2, 'Snacks', 'Productos para picar'),
       (3, 'Limpieza', 'Productos de limpieza');

INSERT INTO Inventario.Productos
(ProductoID, ProductoNombre, CategoriaID, PrecioUnidad, UnidadesEnStock)
VALUES (1, 'Café', 1, 120.00, 25),
       (2, 'Té', 1, 80.00, 30),
       (3, 'Galletas', 2, 45.00, 50),
       (4, 'Papas Fritas', 2, 60.00, 40),
       (5, 'Detergente', 3, 150.00, 20);

SELECT *
FROM Inventario.Categorias;

SELECT *
FROM Inventario.Productos;

-- 4. Crear el usuario usuario_inventario y el rol_inventario

CREATE USER usuario_inventario WITHOUT LOGIN;
CREATE ROLE rol_inventario;

-- 5. Agregar usuario_inventario al rol_inventario

ALTER ROLE rol_inventario
    ADD MEMBER usuario_inventario;

-- 6. Conceder INSERT, SELECT y UPDATE sobre el esquema Inventario

GRANT SELECT, INSERT, UPDATE
    ON SCHEMA::Inventario
    TO rol_inventario;

-- 7. Impedir la operación DELETE

DENY DELETE
    ON SCHEMA::Inventario
    TO rol_inventario;

-- 8. UTiliza EXECUTE AS USER para demostrar una operación permitida y una operación rechazada

EXECUTE AS USER = 'usuario_inventario'

SELECT *
FROM Inventario.Categorias;

DELETE
FROM Inventario.Productos
WHERE ProductoID = 1;

REVERT;

-- 9. Adjunta captuars de cada proceso




