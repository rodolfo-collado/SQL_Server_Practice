CREATE DATABASE ClientesDB;
GO

USE ClientesDB;
GO

CREATE TABLE [dbo].[Clientes]
(
    [id_cliente]     INT PRIMARY KEY,
    [nombre_cliente] VARCHAR(100) NOT NULL,
    [direccion]      VARCHAR(200) NULL,
    [telefono]       VARCHAR(20) NULL
);

INSERT INTO Clientes
VALUES (1, 'Juan Perez', 'Colonia Centro, Managua', '8888-1111');

INSERT INTO Clientes
VALUES (2, 'Maria Lopez', 'Lomas de Monserrat', '8888-2222');

SELECT *
FROM Clientes;

CREATE TABLE Auditoria_Clientes
(
    id_auditoria   INT IDENTITY PRIMARY KEY,
    accion         VARCHAR(20),
    nombre_cliente VARCHAR(100),
    fecha          DATETIME DEFAULT GETDATE()
);
GO

DROP TRIGGER IF EXISTS trg_auditoria_clientes;
GO

CREATE TRIGGER trg_auditoria_clientes
ON Clientes
AFTER INSERT
AS
BEGIN
    INSERT INTO Auditoria_Clientes (accion, nombre_cliente)
    SELECT 'INSERT', nombre_cliente
    FROM inserted;
END;
GO

INSERT INTO Clientes
VALUES (7, 'Cliente X', 'Bello Horizonte', '77778888');

DELETE
FROM Clientes
WHERE id_cliente = 7;

SELECT *
FROM Auditoria_Clientes;

CREATE TABLE Marcas
(
    id_marca     INT PRIMARY KEY,
    nombre_marca VARCHAR(50) NOT NULL
);

INSERT INTO Marcas
VALUES (1, 'Yamaha');

INSERT INTO Marcas
VALUES (2, 'Fender');

INSERT INTO Marcas
VALUES (3, 'Roland');

SELECT *
FROM Marcas;

CREATE TABLE Instrumentos
(
    id_instrumento INT PRIMARY KEY,
    nombre         VARCHAR(100),
    id_marca       INT,
    precio         DECIMAL(10, 2),
    CONSTRAINT FK_Marca FOREIGN KEY (id_marca)
        REFERENCES Marcas (id_marca)
);

CREATE TABLE Auditoria_Instrumentos
(
    id_instrumento INT IDENTITY PRIMARY KEY,
    accion         VARCHAR(20),
    nombre         VARCHAR(100),
    fecha          DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_auditoria_instrumentos
ON Instrumentos
AFTER INSERT
AS
BEGIN
    INSERT INTO Auditoria_Instrumentos (accion, nombre)
    SELECT 'INSERT', nombre
    FROM inserted;
END;
GO

SELECT *
FROM Instrumentos;

INSERT INTO Instrumentos
VALUES (3, 'Arpa', 2, 450);

SELECT *
FROM Auditoria_Instrumentos;

CREATE TABLE Auditoria_Update_Instrumentos
(
    id_auditoria    INT IDENTITY PRIMARY KEY,
    nombre_anterior VARCHAR(100),
    nombre_nuevo    VARCHAR(100),
    precio_anterior DECIMAL(10, 2),
    precio_nuevo    DECIMAL(10, 2),
    fecha           DATETIME DEFAULT GETDATE()
);
GO

-- Tabla faltante para registrar cambios de marca

CREATE TABLE Auditoria_Marca
(
    id_auditoria   INT IDENTITY PRIMARY KEY,
    instrumento    VARCHAR(100),
    marca_anterior INT,
    marca_nueva    INT,
    fecha          DATETIME DEFAULT GETDATE()
);
GO

CREATE TRIGGER trg_update_instrumentos
ON Instrumentos
AFTER UPDATE
AS
BEGIN
    INSERT INTO Auditoria_Update_Instrumentos
        (nombre_anterior, nombre_nuevo, precio_anterior, precio_nuevo)
    SELECT d.nombre,
           i.nombre,
           d.precio,
           i.precio
    FROM deleted d
    JOIN inserted i
        ON d.id_instrumento = i.id_instrumento;
END;
GO

UPDATE Instrumentos
SET precio = 550
WHERE id_instrumento = 3;

SELECT *
FROM Auditoria_Update_Instrumentos;
GO

-- Trigger: Evitar bajar demasiado los precios

CREATE TRIGGER trg_control_precio
    ON Instrumentos
    AFTER UPDATE
    AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted i
                        JOIN deleted d
                             ON i.id_instrumento = d.id_instrumento
               WHERE i.precio < d.precio * 0.5)
        BEGIN
            PRINT 'Error: No se puede reducir el precio más del 50%';
            ROLLBACK TRANSACTION;
        END
END;
GO

-- Trigger: Registrar cambios de marca
CREATE TRIGGER trg_update_marca
    ON Instrumentos
    AFTER UPDATE
    AS
BEGIN
    INSERT INTO Auditoria_Marca (instrumento, marca_anterior, marca_nueva)
    SELECT i.nombre,
           d.id_marca,
           i.id_marca
    FROM inserted i
             JOIN deleted d
                  ON i.id_instrumento = d.id_instrumento
    WHERE d.id_marca <> i.id_marca;
END;
GO

-- ¿ Y para SELECT? (alternativa REAL)
-- Opción 1
-- : Vista controlada

CREATE VIEW vw_Instrumentos_Publico
AS
SELECT nombre,
       precio,
       SYSTEM_USER AS usuario_bd,
       HOST_NAME() AS equipo,
       APP_NAME()  AS aplicacion,
       GETDATE()   AS fecha_consulta
FROM Instrumentos;
GO