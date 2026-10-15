-- Listar servers a nivel de instancia
SELECT *
FROM sys.servers;

-- Listar logins de de la instancia
SELECT *
FROM sys.sql_logins;

-- Comprueba que existe el usuario en la base de datos
USE BaseDatosDestino;

SELECT name,
       type_desc,
       sid
FROM sys.database_principals
WHERE name = 'UsuarioRemoto_UAM';
