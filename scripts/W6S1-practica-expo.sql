-- ================================
-- === 1. NODO A: TechNova_Central ===
-- ================================

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
