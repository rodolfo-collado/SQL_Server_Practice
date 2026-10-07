/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM) - ADMINISTRACIÓN Y GESTIÓN DE BASES DE DATOS
 Sesión 15: Extracción Automatizada de Metadatos y Diccionario de Datos
 Caso de Estudio: Base de Datos Northwind (Gobernanza, Trazabilidad y Metadatos)
 Indicadores de Logro: ILE3.1, ILE3.2 (RAAE3) | ILE1.2 (Seguridad)
*******************************************************************************/

SET NOCOUNT ON;
GO

USE Northwind;
GO

-- ============================================================================
-- SECCIÓN 1: ASIGNACIÓN DE PROPIEDADES EXTENDIDAS (MS_Description)
-- Documentación técnica de negocio embebida en la base de datos Northwind
-- ============================================================================

-- 1.1 Documentación en la Tabla Customers
EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Catálogo general de clientes internacionales de la empresa Northwind Traders.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Customers';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Código alfanumérico único de 5 caracteres que identifica al cliente.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Customers',
     @level2type = N'COLUMN', @level2name = N'CustomerID';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Nombre oficial o razón social de la empresa cliente.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Customers',
     @level2type = N'COLUMN', @level2name = N'CompanyName';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Ciudad de ubicación del cliente para análisis geográfico de ventas.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Customers',
     @level2type = N'COLUMN', @level2name = N'City';
GO

-- 1.2 Documentación en la Tabla Orders
EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Encabezado de órdenes de compra procesadas por Northwind.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Orders';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Fecha y hora de emisión del pedido por parte del cliente.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Orders',
     @level2type = N'COLUMN', @level2name = N'OrderDate';
GO

-- 1.3 Documentación de Sinónimos e Interoperabilidad (Si existen enlaces externos)
IF OBJECT_ID(N'dbo.syn_PedidosRemotos', N'SN') IS NOT NULL
    BEGIN
        EXEC sys.sp_addextendedproperty
             @name = N'MS_Description',
             @value = N'Sinónimo local que referencia a la tabla Orders en una instancia remota de Northwind.',
             @level0type = N'SCHEMA', @level0name = N'dbo',
             @level1type = N'SYNONYM', @level1name = N'syn_PedidosRemotos';
    END;
GO

-- Consulta de Verificación

SELECT *
FROM sys.extended_properties;

-- ============================================================================
-- SECCIÓN 2: DICCIONARIO DE DATOS AUTOMATIZADO CON VISTAS DE CATÁLOGO (sys.*)
-- Genera el reporte completo de la estructura física de Northwind
-- ============================================================================

SELECT DB_NAME()                                                             AS [Base_Datos],
       t.name                                                                AS [Tabla],
       c.column_id                                                           AS [Orden],
       c.name                                                                AS [Columna],
       ty.name                                                               AS [Tipo_Dato],
       c.max_length                                                          AS [Longitud_Bytes],
       CASE WHEN c.is_nullable = 1 THEN 'SÍ' ELSE 'NO' END                   AS [Permite_Nulos],
       ISNULL(CAST(ep.value AS VARCHAR(250)), '⚠️ Sin descripción asignada') AS [Descripcion_Negocio]
FROM sys.tables t
         INNER JOIN sys.columns c
                    ON t.object_id = c.object_id
         INNER JOIN sys.types ty
                    ON c.user_type_id = ty.user_type_id
         LEFT JOIN sys.extended_properties ep
                   ON ep.major_id = c.object_id
                       AND ep.minor_id = c.column_id
                       AND ep.name = 'MS_Description'
WHERE t.name IN ('Customers', 'Orders', 'Order Details', 'Products', 'Suppliers', 'Categories')
ORDER BY t.name, c.column_id;
GO

-- ============================================================================
-- SECCIÓN 3: AUDITORÍA DE INFRAESTRUCTURA DE CONEXIÓN Y SINÓNIMOS
-- ============================================================================

-- 3.1 Auditar Servidores Enlazados configurados en la instancia
SELECT server_id   AS [ID_Servidor],
       name        AS [Nombre_Servidor_Enlazado],
       product     AS [Producto],
       provider    AS [Proveedor_OLEDB],
       data_source AS [Origen_Datos_IP_Instancia],
       is_linked   AS [Es_Enlazado],
       modify_date AS [Ultima_Modificacion]
FROM sys.servers
WHERE is_linked = 1;
GO

-- 3.2 Auditar Sinónimos registrados en Northwind
SELECT s.name             AS [Sinonimo_Local],
       s.base_object_name AS [Objeto_Remoto_Referenciado],
       s.create_date      AS [Fecha_Creacion]
FROM sys.synonyms s;
GO

-- ============================================================================
-- SECCIÓN 4: TRACELOG Y MAPEO DE DEPENDENCIAS (sys.sql_expression_dependencies)
-- Inspección de Vistas Nativas de Northwind (Invoices, Customer and Suppliers by City)
-- ============================================================================

SELECT o.name                                        AS [Objeto_Consumidor_Northwind],
       o.type_desc                                   AS [Tipo_Objeto],
       d.referenced_entity_name                      AS [Tabla_Referenciada_Dependiente],
       ISNULL(d.referenced_database_name, DB_NAME()) AS [Base_Datos_Destino]
FROM sys.sql_expression_dependencies d
         INNER JOIN sys.objects o
                    ON d.referencing_id = o.object_id
WHERE d.referenced_entity_name IN ('Customers', 'Orders', 'Order Details', 'Products')
ORDER BY o.name, d.referenced_entity_name;
GO
