/*******************************************************************************
 UNIVERSIDAD AMERICANA (UAM) - ADMINISTRACIÓN Y GESTIÓN DE BASES DE DATOS
 Sesión 15: Extracción Automatizada de Metadatos, Búsqueda por Patrones y Trazabilidad
 Caso de Estudio: Base de Datos Northwind (Laboratorio Ampliado de Gobernanza de Datos)
 Indicadores de Logro: ILE3.1, ILE3.2 (RAAE3) | ILE1.2 (Seguridad y Calidad)
*******************************************************************************/

SET
    NOCOUNT ON;
GO

USE Northwind;
GO

-- ============================================================================
-- SECCIÓN 1: PROPIEDADES EXTENDIDAS (MS_Description) Y ANÁLISIS DE BRECHA
-- ============================================================================

-- 1.1 Asignación de descripciones de negocio embebidas en Northwind
EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Catálogo general de clientes internacionales de Northwind Traders.',
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
     @value = N'Ciudad de ubicación del cliente para análisis geográfico de ventas.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Customers',
     @level2type = N'COLUMN', @level2name = N'City';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Encabezado de órdenes de compra procesadas por la empresa.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Orders';

EXEC sys.sp_addextendedproperty
     @name = N'MS_Description',
     @value = N'Fecha y hora de emisión del pedido por parte del cliente.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Orders',
     @level2type = N'COLUMN', @level2name = N'OrderDate';
GO

-- comprobar extended properties
SELECT *
FROM sys.extended_properties;

-- 1.2 Auditoría de Brecha de Documentación (Columnas Faltantes de Descripción)
-- Permite al DBA identificar qué porcentaje del esquema carece de documentación
SELECT t.name                       AS [Tabla],
       C.name                       AS [Columna_Sin_Documentacion],
       ty.name                      AS [Tipo_Dato],
       '❌ Pendiente por documentar' AS [Estado_Gobernanza]
FROM sys.tables t
         INNER JOIN sys.columns C
                    ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
         LEFT JOIN sys.extended_properties ep
                   ON ep.major_id = C.object_id
                       AND ep.minor_id = C.column_id
                       AND ep.name = 'MS_Description'
WHERE ep.value IS NULL
ORDER BY t.name, C.column_id;
GO

-- 1.3 Mantenimiento de Metadatos: Actualizar o Eliminar Propiedades
-- Ejemplo de actualización:

EXEC sys.sp_updateextendedproperty
     @name = N'MS_Description',
     @value = N'Ciudad principal de entrega para la orden de compra.',
     @level0type = N'SCHEMA', @level0name = N'dbo',
     @level1type = N'TABLE', @level1name = N'Orders',
     @level2type = N'COLUMN', @level2name = N'ShipCity';

GO


-- ============================================================================
-- SECCIÓN 2: BÚSQUEDA DE COLUMNAS POR PATRÓN DE NOMBRE (Wildcard Search)
-- Permite explorar la arquitectura física cuando no se conoce la estructura
-- ============================================================================

-- Ejercicio 2.1: Buscar todas las columnas de Identificadores/Claves (*ID*)
SELECT t.name       AS [Tabla],
       C.name       AS [Columna_ID],
       ty.name      AS [Tipo_Dato],
       C.max_length AS [Longitud_Bytes],
       CASE
           WHEN C.is_nullable = 1 THEN 'NULL'
           ELSE 'NOT NULL'
           END      AS [Nulabilidad]
FROM sys.tables t
         INNER JOIN sys.columns C ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
WHERE C.name LIKE '%ID%'
ORDER BY C.name, t.name;
GO

-- Ejercicio 2.2: Buscar columnas de Auditoría Fechas y Tiempos (*Date* / *Time*)
SELECT t.name  AS [Tabla],
       C.name  AS [Columna_Fecha],
       ty.name AS [Tipo_Dato]
FROM sys.tables t
         INNER JOIN sys.columns C
                    ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
WHERE C.name LIKE '%Date%'
   OR C.name LIKE '%Time%'
ORDER BY t.name;
GO

-- Ejercicio 2.3: Buscar columnas de Ubicación Geográfica (*City*, *Address*, *Country*, *Region*)
SELECT t.name       AS [Tabla],
       C.name       AS [Columna_Ubicacion],
       ty.name      AS [Tipo_Dato],
       C.max_length AS [Longitud]
FROM sys.tables t
         INNER JOIN sys.columns C
                    ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
WHERE C.name LIKE '%City%'
   OR C.name LIKE '%Address%'
   OR C.name LIKE '%Country%'
   OR C.name LIKE '%Region%'
ORDER BY C.name, t.name;
GO

-- Ejercicio 2.4: Buscar columnas Financieras y de Precios (*Price*, *Cost*, *Freight*, *Discount*)
SELECT t.name      AS [Tabla],
       C.name      AS [Columna_Financiera],
       ty.name     AS [Tipo_Dato],
       C.precision AS [PRECISION],
       C.scale     AS [Escala]
FROM sys.tables t
         INNER JOIN sys.columns C
                    ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
WHERE C.name LIKE '%Price%'
   OR C.name LIKE '%Cost%'
   OR C.name LIKE '%Freight%'
   OR C.name LIKE '%Discount%'
   OR C.name LIKE '%Amount%'
ORDER BY t.name;
GO


-- ============================================================================
-- SECCIÓN 3: AUDITORÍA DE CONSISTENCIA Y CALIDAD EN TIPOS DE DATOS
-- Detecta si una misma columna conceptual tiene diferentes tipos o longitudes
-- ============================================================================

SELECT c.name                                                                   AS [Nombre_Columna_Repetida],
       COUNT(DISTINCT t.object_id)                                              AS [Total_Tablas_Donde_Aparece],
       COUNT(DISTINCT ty.name)                                                  AS [Variaciones_Tipo_Dato],
       COUNT(DISTINCT C.max_length)                                             AS [Variaciones_Longitud],
       STRING_AGG(CONCAT(t.name, ' (', ty.name, ' ', C.max_length, ')'), ' | ') AS [Detalle_Por_Tabla]
FROM sys.tables t
         INNER JOIN sys.columns C
                    ON t.object_id = C.object_id
         INNER JOIN sys.types ty ON C.user_type_id = ty.user_type_id
GROUP BY C.name
HAVING COUNT(DISTINCT t.object_id)
    > 1
   AND (COUNT(DISTINCT ty.name)
            > 1
    OR COUNT(DISTINCT C.max_length)
            > 1)
ORDER BY [Total_Tablas_Donde_Aparece] DESC;
GO


-- ============================================================================
-- SECCIÓN 4: AUDITORÍA COMPLETA DE RESTRICCIONES (PK, FK, CHECK, DEFAULT)
-- ============================================================================

-- 4.1 Mapeo de Claves Primarias y Claves Foráneas por Tabla
SELECT tp.name AS [Tabla_Origen],
       cp.name AS [Columna_Origen_FK],
       fk.name AS [Nombre_Restriccion_FK],
       tr.name AS [Tabla_Destino_PK],
       cr.name AS [Columna_Destino_PK]
FROM sys.foreign_keys fk
         INNER JOIN sys.foreign_key_columns fkc
                    ON fk.object_id = fkc.constraint_object_id
         INNER JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
         INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
         INNER JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
         INNER JOIN sys.columns cr
                    ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
ORDER BY tp.name, cp.name;
GO

-- 4.2 Restricciones de Dominio (CHECK) y Valores Por Defecto (DEFAULT)
SELECT t.name                               AS [Tabla],
       o.name                               AS [Nombre_Restriccion],
       o.type_desc                          AS [Tipo_Restriccion],
       C.name                               AS [Columna_Asociada],
       ISNULL(cc.definition, dc.definition) AS [Regla_o_Valor_Defecto]
FROM sys.objects o
         INNER JOIN sys.tables t
                    ON o.parent_object_id = t.object_id
         LEFT JOIN sys.check_constraints cc ON o.object_id = cc.object_id
         LEFT JOIN sys.default_constraints dc ON o.object_id = dc.object_id
         LEFT JOIN sys.columns C ON o.parent_object_id = C.object_id
    AND (cc.parent_column_id = C.column_id OR dc.parent_column_id = C.column_id)
WHERE o.type IN ('C', 'D') -- C: CHECK, D: DEFAULT
ORDER BY t.name, o.type_desc;
GO


-- ============================================================================
-- SECCIÓN 5: AUDITORÍA DE INFRAESTRUCTURA DE CONEXIÓN Y SINÓNIMOS
-- ============================================================================

-- 5.1 Servidores Enlazados configurados en la instancia
SELECT server_id   AS [ID_Servidor],
       NAME        AS [Nombre_Servidor_Enlazado],
       product     AS [Producto],
       provider    AS [Proveedor_OLEDB],
       data_source AS [Origen_Datos_IP_Instancia],
       is_linked   AS [Es_Enlazado],
       modify_date AS [Ultima_Modificacion]
FROM sys.servers
WHERE is_linked = 1;
GO

-- 5.2 Sinónimos registrados para abstracción de objetos
USE Ventas_Norte;

SELECT s.name             AS [Sinonimo_Local],
       s.base_object_name AS [Objeto_Remoto_Referenciado],
       s.create_date      AS [Fecha_Creacion]
FROM sys.synonyms s;
GO

-- ============================================================================
-- SECCIÓN 6: ANÁLISIS DE IMPACTO Y TRAZABILIDAD (sys.sql_expression_dependencies)
-- ============================================================================

-- Identificar qué Objetos (Vistas, SPs, Funciones) dependen de tablas clave
SELECT o.name                                        AS [Objeto_Consumidor_Northwind],
       o.type_desc                                   AS [Tipo_Objeto],
       d.referenced_entity_name                      AS [Entidad_Referenciada_Dependiente],
       ISNULL(d.referenced_database_name, DB_NAME()) AS [Base_Datos_Destino]
FROM sys.sql_expression_dependencies d
         INNER JOIN sys.objects o
                    ON d.referencing_id = o.object_id
WHERE d.referenced_entity_name IN ('Customers', 'Orders', 'Order Details', 'Products', 'Suppliers')
ORDER BY o.name, D.referenced_entity_name;
GO
