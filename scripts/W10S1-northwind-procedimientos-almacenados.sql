/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM) - ADMINISTRACIÓN Y GESTIÓN DE BASES DE DATOS
 Sesión 15: Objetos Programables - Funciones (UDFs) y Procedimientos Almacenados
 Resultado de Aprendizaje: RAAE4 | Indicador de Logro: ILE4.1
 Base de Datos de Referencia: Northwind / Esquema General de Ventas y Consumo
*******************************************************************************/

SET NOCOUNT ON;
GO

USE Northwind;
GO

-- ============================================================================
-- SECCIÓN 1: FUNCIONES ESCALARES (SCALAR FUNCTIONS - ufn_)
-- Retornan un único valor (numérico, fecha, texto) procesado en el servidor
-- ============================================================================

-- 1.1 Función Escalar: Calcular el Total Neto de una Línea de Pedido (con descuento)
CREATE OR ALTER FUNCTION dbo.ufn_CalcularMontoNetoLinea(
    @UnitPrice DECIMAL(18, 2),
    @Quantity INT,
    @Discount REAL
)
    RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @MontoNeto DECIMAL(18, 2);
    SET @MontoNeto = (@UnitPrice * @Quantity) * (1.0 - CAST(@Discount AS DECIMAL(18, 2)));
    RETURN ISNULL(@MontoNeto, 0.00);
END;
GO

-- Ejemplo de uso de la Función Escalar en una consulta SELECT:
SELECT TOP (10) OrderID,
                ProductID,
                UnitPrice,
                Quantity,
                Discount,
                dbo.ufn_CalcularMontoNetoLinea(UnitPrice, Quantity, Discount) AS TotalNetoLinea
FROM [Order Details]
ORDER BY OrderID;
GO


-- 1.2 Función Escalar: Categorización de Clientes según su Nivel de Compras
CREATE OR ALTER FUNCTION dbo.ufn_CategorizarCliente(
    @CustomerID NCHAR(5)
)
    RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @TotalComprado DECIMAL(18, 2);
    DECLARE @Categoria VARCHAR(20);

    SELECT @TotalComprado = SUM(od.UnitPrice * od.Quantity * (1 - od.Discount))
    FROM Orders o
             INNER JOIN [Order Details] od ON o.OrderID = od.OrderID
    WHERE o.CustomerID = @CustomerID;

    IF @TotalComprado IS NULL
        SET @Categoria = 'SIN COMPRAS';
    ELSE
        IF @TotalComprado >= 50000
            SET @Categoria = 'CLIENTE VIP';
        ELSE
            IF @TotalComprado >= 15000
                SET @Categoria = 'CLIENTE FRECUENTE';
            ELSE
                SET @Categoria = 'CLIENTE REGULAR';

    RETURN @Categoria;
END;
GO

-- Ejemplo de uso:
SELECT CustomerID,
       CompanyName,
       dbo.ufn_CategorizarCliente(CustomerID) AS CategoriaCliente
FROM Customers;
GO


-- ============================================================================
-- SECCIÓN 2: FUNCIONES DE TABLA EN LÍNEA (INLINE TABLE-VALUED FUNCTIONS - ufn_)
-- Retornan el conjunto de resultados de una consulta SELECT parametrizada
-- ============================================================================

-- 2.1 Función de Tabla en Línea: Historial de Pedidos por Cliente y Rango de Fechas
CREATE OR ALTER FUNCTION dbo.ufn_ObtenerPedidosCliente(
    @CustomerID NCHAR(5),
    @FechaInicio DATETIME,
    @FechaFin DATETIME
)
    RETURNS TABLE
        AS
        RETURN(SELECT o.OrderID,
                      o.OrderDate,
                      o.ShippedDate,
                      o.ShipCity,
                      o.ShipCountry,
                      COUNT(od.ProductID)                                                         AS CantidadProductos,
                      SUM(dbo.ufn_CalcularMontoNetoLinea(od.UnitPrice, od.Quantity, od.Discount)) AS TotalPedido
               FROM Orders o
                        INNER JOIN [Order Details] od ON o.OrderID = od.OrderID
               WHERE o.CustomerID = @CustomerID
                 AND o.OrderDate BETWEEN @FechaInicio AND @FechaFin
               GROUP BY o.OrderID, o.OrderDate, o.ShippedDate, o.ShipCity, o.ShipCountry);
GO

-- Ejemplo de consulta a la Función de Tabla en Línea:
SELECT *
FROM dbo.ufn_ObtenerPedidosCliente('ALFKI', '1996-01-01', '1998-12-31');
GO


-- ============================================================================
-- SECCIÓN 3: FUNCIONES DE TABLA MULTISENTENCIA (MULTI-STATEMENT TVFs - ufn_)
-- Permiten lógica compleja, tablas temporales de retorno y múltiples sentencias
-- ============================================================================

CREATE OR ALTER FUNCTION dbo.ufn_ReporteResumenProductos()
    RETURNS @Reporte TABLE
                     (
                         ProductID    INT,
                         ProductName  NVARCHAR(40),
                         CategoryName NVARCHAR(15),
                         UnitPrice    DECIMAL(18, 2),
                         UnitsInStock INT,
                         EstadoStock  VARCHAR(25)
                     )
AS
BEGIN
    INSERT INTO @Reporte
    SELECT p.ProductID,
           p.ProductName,
           c.CategoryName,
           p.UnitPrice,
           p.UnitsInStock,
           CASE
               WHEN p.UnitsInStock = 0 THEN '🔴 AGOTADO'
               WHEN p.UnitsInStock <= p.ReorderLevel THEN '🟡 REORDEN REQUERIDA'
               ELSE '🟢 STOCK ADECUADO'
               END AS EstadoStock
    FROM Products p
             INNER JOIN Categories c ON p.CategoryID = c.CategoryID;

    RETURN;
END;
GO

-- Ejemplo de uso:
SELECT *
FROM dbo.ufn_ReporteResumenProductos()
WHERE EstadoStock LIKE '%REORDEN%';
GO


-- ============================================================================
-- SECCIÓN 4: PROCEDIMIENTOS ALMACENADOS (STORED PROCEDURES - usp_)
-- Encapsulan lógica de procesamiento, parámetros de entrada/salida y seguridad
-- ============================================================================

-- 4.1 Procedimiento Almacenado: Registro Transaccional de un Nuevo Producto
CREATE OR ALTER PROCEDURE dbo.usp_RegistrarProducto @ProductName NVARCHAR(40),
                                                    @SupplierID INT,
                                                    @CategoryID INT,
                                                    @UnitPrice DECIMAL(18, 2),
                                                    @UnitsInStock INT,
                                                    @NuevoProductID INT OUTPUT -- Parámetro de salida
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación de existencia previa
    IF EXISTS (SELECT 1 FROM Products WHERE ProductName = @ProductName)
        BEGIN
            RAISERROR ('El producto con el nombre proporcionado ya se encuentra registrado.', 16, 1);
            RETURN;
        END;

    INSERT INTO Products (ProductName, SupplierID, CategoryID, UnitPrice, UnitsInStock, Discontinued)
    VALUES (@ProductName, @SupplierID, @CategoryID, @UnitPrice, @UnitsInStock, 0);

    SET @NuevoProductID = SCOPE_IDENTITY();

    PRINT 'Producto registrado exitosamente con ID: ' + CAST(@NuevoProductID AS VARCHAR(10));
END;
GO

-- Ejemplo de ejecución del SP con parámetro OUTPUT:
DECLARE @ID_Generado INT;

EXEC dbo.usp_RegistrarProducto
     @ProductName = N'Café Matagalpa Gourmet',
     @SupplierID = 1,
     @CategoryID = 1,
     @UnitPrice = 15.50,
     @UnitsInStock = 100,
     @NuevoProductID = @ID_Generado OUTPUT;

SELECT @ID_Generado AS ID_Producto_Registrado;
GO


-- ============================================================================
-- SECCIÓN 5: PROCEDIMIENTOS ALMACENADOS CON TRY...CATCH Y TRANSACCIONES
-- Garantizan ACID e Integridad de Negocio
-- ============================================================================

CREATE OR ALTER PROCEDURE dbo.usp_ProcesarTransferenciaStock @ProductID_Origen INT,
                                                             @ProductID_Destino INT,
                                                             @CantidadTransferir INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar que el producto de origen tenga stock suficiente
        DECLARE @StockOrigen INT;
        SELECT @StockOrigen = UnitsInStock FROM Products WHERE ProductID = @ProductID_Origen;

        IF @StockOrigen IS NULL OR @StockOrigen < @CantidadTransferir
            BEGIN
                RAISERROR ('Stock insuficiente o producto de origen no existe.', 16, 1);
            END;

        -- 2. Descontar stock del origen
        UPDATE Products
        SET UnitsInStock = UnitsInStock - @CantidadTransferir
        WHERE ProductID = @ProductID_Origen;

        -- 3. Aumentar stock en el destino
        UPDATE Products
        SET UnitsInStock = UnitsInStock + @CantidadTransferir
        WHERE ProductID = @ProductID_Destino;

        -- Confirmar transacciones
        COMMIT TRANSACTION;
        PRINT 'Transferencia de stock procesada correctamente.';

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- Ejemplo de uso
EXEC dbo.usp_ProcesarTransferenciaStock
    @ProductID_Origen = 999999,
    @ProductID_Destino = 2,
    @CantidadTransferir = 5;

-- ============================================================================
-- SECCIÓN 6: AUDITORÍA DE METADATOS Y TRAZABILIDAD (sys.objects, sys.parameters)
-- Extracción automatizada de información sobre funciones y procedimientos
-- ============================================================================

SELECT o.name                                            AS [Nombre_Objeto],
       o.type_desc                                       AS [Tipo_Objeto],
       o.create_date                                     AS [Fecha_Creacion],
       o.modify_date                                     AS [Ultima_Modificacion],
       p.name                                            AS [Parametro],
       t.name                                            AS [Tipo_Dato_Parametro],
       p.max_length                                      AS [Longitud_Bytes],
       CASE WHEN p.is_output = 1 THEN 'SÍ' ELSE 'NO' END AS [Es_Output]
FROM sys.objects o
         LEFT JOIN sys.parameters p ON o.object_id = p.object_id
         LEFT JOIN sys.types t ON p.user_type_id = t.user_type_id
WHERE o.type IN ('FN', 'IF', 'TF', 'P') -- FN: Scalar, IF: Inline TVF, TF: Table TVF, P: Stored Proc
  AND o.is_ms_shipped = 0
ORDER BY o.type, o.name, p.parameter_id;
GO

-- ============================================================================
-- Restauracion de base de datos Northwind
-- ============================================================================
USE master;
GO

ALTER DATABASE Northwind
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

RESTORE DATABASE Northwind
    FROM DISK = '/var/opt/mssql/backup/Northwind_mssql-dev.bak'
    WITH REPLACE, STATS = 10;

ALTER DATABASE Northwind
    SET MULTI_USER;