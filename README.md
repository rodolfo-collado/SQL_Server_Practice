# SQL Server Practice

Repositorio personal de prácticas de administración, seguridad, recuperación, procesamiento y distribución de datos con Microsoft SQL Server.

El repositorio contiene los scripts ejecutables. La documentación narrativa, las explicaciones paso a paso y las evidencias de ejecución se mantienen actualmente en las notas de Nexus y se incorporarán progresivamente aquí para conservar un respaldo reproducible del laboratorio.

## Entorno de trabajo

- SQL Server 2025 Developer Edition.
- Docker Engine sobre Arch Linux.
- DataGrip como cliente SQL.
- Dos instancias SQL Server dentro de la red Docker `sql-network-lab`:
  - `mssql-dev`: instancia principal/origen.
  - `mssql-lab`: instancia remota/destino.
- Puerto SQL Server utilizado dentro de la red: `1433`.

DataGrip permite cambiar la instancia desde la conexión asociada al archivo. La instrucción `USE` solamente cambia de base de datos dentro de la instancia seleccionada; no cambia de servidor.

## Topología distribuida

| Elemento | Ubicación | Propósito |
|---|---|---|
| `mssql-dev` | Instancia principal | Bases centrales, regiones 1 y 2, origen de consultas |
| `mssql-lab` | Instancia remota | Bases regionales 3, bodega y ventas sur |
| `SERVIDOR_REGION3` | Linked server registrado en `mssql-dev` | Acceso a `BD_REGION_3` |
| `SERVIDOR_BODEGA` | Linked server registrado en `mssql-dev` | Acceso a `TechNova_Bodega` |
| `SERVIDOR_VENTAS_SUR` | Linked server registrado en `mssql-dev` | Acceso a `Ventas_Sur` |
| `SRV_UAM_DISTRIBUIDO` | Práctica independiente de W3 | Primer ejercicio de linked server |

Los linked servers se configuran a nivel de instancia, normalmente desde `master` en `mssql-dev`. Las consultas distribuidas se ejecutan desde `mssql-dev` usando nombres de cuatro partes, por ejemplo:

```sql
SELECT TOP (10) *
FROM [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL];
```

## Orden de prácticas

| Etapa | Script | Tema principal |
|---|---|---|
| W1S2 | [`W1S2-Ejercicio-Guia.sql`](scripts/W1S2-Ejercicio-Guia.sql) | Verificación de instancia, base, tabla, login y usuario |
| W2S1 | [`W2S1-Ejercicio_Login.sql`](scripts/W2S1-Ejercicio_Login.sql) | Logins, usuarios, roles y pruebas de permisos sobre Northwind |
| W2S2 | [`W2S2-Mantenimiento_Respaldo_Recuperacion.sql`](scripts/W2S2-Mantenimiento_Respaldo_Recuperacion.sql) | `CHECKDB`, backup, `RESTORE VERIFYONLY`, pérdida simulada y restauración |
| W3S1 | [`W3S1-Esquemas-Tablas-Roles.sql`](scripts/W3S1-Esquemas-Tablas-Roles.sql) | Esquemas, tablas, relaciones, roles y permisos personalizados |
| W3S2 | [`W3S2-linked-servers.sql`](scripts/W3S2-linked-servers.sql) | Identidad remota, linked server, mapeo de logins y sinónimos |
| W4S1 | [`W4S1-base-datos-distribuidas-ventas.sql`](scripts/W4S1-base-datos-distribuidas-ventas.sql) | Bases `Ventas_Norte`/`Ventas_Sur` y consultas distribuidas |
| W5S2 | [`W5S2-practica-bulk-insert-cursores.sql`](scripts/W5S2-practica-bulk-insert-cursores.sql) | Carga masiva, cursores, segmentación y resúmenes diarios |
| W6S1 | [`W6S1-TechNova-Practice.sql`](scripts/W6S1-TechNova-Practice.sql) | Caso TechNova: ventas, bodega, seguridad, linked server y recuperación |
| W7S1 | [`W7S1-bases-regionales-practice.sql`](scripts/W7S1-bases-regionales-practice.sql) | Catálogo de antenas, fragmentación horizontal y reconstrucción |
| W7S2 | [`W7S2-consultas-distribuidas-bases-regionales.sql`](scripts/W7S2-consultas-distribuidas-bases-regionales.sql) | Consultas analíticas sobre las tres regiones |
| W8S1 | Scripts de documentación | Metadatos, diccionario, auditoría y trazabilidad |
| W8S2 | Scripts complementarios | Auditorías avanzadas y SQL Server Agent Job |

## Flujo principal de W5: carga masiva y cursores

La práctica crea la base `Practica_Bulk_Cursores` y carga los archivos de tráfico mediante `BULK INSERT`:

- `trfJunio26.txt`.
- `trfJulio26.txt`.
- `trfAgosto26.txt`.

Los archivos deben existir dentro del contenedor SQL Server en:

```text
/var/opt/mssql/backup/practica-bulk-insert/
```

El script crea y utiliza las siguientes tablas:

- `CONSUMO_ABONADOS`: tabla principal cargada desde los archivos.
- `CONSUMO_ABONADOS_SEGMENTADO`: clasificación por tipo de consumo.
- `RESUMEN_CONSUMO_DIARIO`: agregados por día.
- `COMPARATIVO_CONSUMO_DIARIO`: variación de consumo respecto al día anterior.

El cursor de segmentación clasifica cada fila como `SIN CONSUMO`, `CONSUMO BAJO`, `CONSUMO MEDIO` o `CONSUMO ALTO`. Para reducir el costo de millones de inserciones individuales, acumula las filas en lotes de 10.000 antes de insertarlas.

Después se crea el índice `IX_CONSUMO_ABONADOS_DIA` sobre `DIA`, con columnas incluidas para acelerar el cursor que genera el resumen diario. El script espera obtener 92 filas diarias para el conjunto de datos utilizado.

## Flujo principal de W7: bases regionales

La base central es `Practica_Bulk_Cursores` en `mssql-dev`. Allí viven:

- `CONSUMO_ABONADOS`.
- `ANTENAS`.
- `ANTENAS_AMBIGUAS`.
- `ANTENAS_UNICAS`.

La topología regional es:

| Base | Instancia | Contenido |
|---|---|---|
| `BD_REGION_1` | `mssql-dev` | Zonas `CAPITAL` y `SUR ORIENTE` |
| `BD_REGION_2` | `mssql-dev` | Zonas `OCCIDENTE` y `ZONA NORTE` |
| `BD_REGION_3` | `mssql-lab` | Zonas `ZONA CENTRO` y `REGIONES AUTONOMAS` |

El orden recomendado es:

1. Ejecutar en `mssql-dev` las secciones de carga, inspección, normalización e integración de antenas.
2. Ejecutar en `mssql-dev` la creación de `BD_REGION_1`, `BD_REGION_2` y sus tablas `CONSUMO_REGIONAL`.
3. Ejecutar en `mssql-lab` la creación de `BD_REGION_3`, `CONSUMO_REGIONAL`, `LoginRegion3`, `UsuarioRegion3` y sus permisos.
4. Crear y probar desde `mssql-dev` el linked server `SERVIDOR_REGION3`.
5. Desde `mssql-dev`, insertar los fragmentos 1 y 2 localmente.
6. Desde `mssql-dev`, insertar el fragmento 3 en:

   ```sql
   [SERVIDOR_REGION3].[BD_REGION_3].[dbo].[CONSUMO_REGIONAL]
   ```

7. Validar que los totales centrales y distribuidos coincidan.
8. Ejecutar [`W7S2-consultas-distribuidas-bases-regionales.sql`](scripts/W7S2-consultas-distribuidas-bases-regionales.sql) desde `mssql-dev`.

El `JOIN` con `ANTENAS_UNICAS` se realiza en la base central. Por eso `BD_REGION_3` no necesita una copia de `ANTENAS`: recibe los registros de consumo ya enriquecidos con la columna `ZONA`.

Para recargar las regiones 1 y 2 se pueden vaciar las tablas locales con `TRUNCATE TABLE`. Para la tabla remota se debe ejecutar el `TRUNCATE` directamente en `mssql-lab` o utilizar `DELETE` mediante el linked server. No se debe truncar `CONSUMO_ABONADOS` ni `ANTENAS` durante una recarga regional.

### Dependencias conocidas de W7

Las secciones de validación y reconstrucción global utilizan directamente `SERVIDOR_REGION3`. Algunas consultas analíticas de `W7S1` utilizan el sinónimo `syn_REGION_3`, que se crea en [`W8S1bases-regionales-documentacion.sql`](scripts/W8S1bases-regionales-documentacion.sql). Si se ejecuta W7 antes de W8, esas consultas deben utilizar directamente el nombre de cuatro partes o ejecutarse después de crear el sinónimo.

## Caso TechNova

[`W6S1-TechNova-Practice.sql`](scripts/W6S1-TechNova-Practice.sql) implementa dos nodos:

- `TechNova_Central` en `mssql-dev`, con esquemas `comercial` y `ventas`.
- `TechNova_Bodega` en `mssql-lab`, con esquema `inventario`.

Incluye:

- Clientes, pedidos y detalles de pedidos.
- Productos y movimientos de inventario.
- `Operador_Ventas`, `Operador_Inventario` y `Consulta_Remota`.
- Roles de ventas, inventario y consulta remota.
- Pruebas de mínimo privilegio.
- Linked server `SERVIDOR_BODEGA`.
- Consultas distribuidas, sinónimo y consulta de inventario crítico.
- Backup, simulación de pérdida y restauración en ambos nodos.

## Documentación técnica y automatización

Los scripts de W8 documentan y auditan bases existentes mediante las vistas de catálogo `sys.*` y propiedades extendidas `MS_Description`.

- [`W8S1-northwind-queries-documentacion.sql`](scripts/W8S1-northwind-queries-documentacion.sql): propiedades extendidas de Northwind, diccionario de datos, servidores enlazados, sinónimos y dependencias.
- [`W8S1-ventas-norte-sur-documentacion.sql`](scripts/W8S1-ventas-norte-sur-documentacion.sql): documentación de `Ventas_Norte` y `Ventas_Sur`, linked server, sinónimo y vista global.
- [`W8S1bases-regionales-documentacion.sql`](scripts/W8S1bases-regionales-documentacion.sql): diccionario, auditoría, sinónimo `syn_REGION_3`, dependencias y descripción de la fragmentación regional.
- [`W8S2-complemento-northwind-documentacion.sql`](scripts/W8S2-complemento-northwind-documentacion.sql): análisis de brechas, búsqueda por patrones, consistencia de tipos, restricciones, infraestructura y trazabilidad.
- [`W8S2-job-northwind-mensual.sql`](scripts/W8S2-job-northwind-mensual.sql): procedimiento `usp_GenerarReporteVentasMensual`, tabla de resultados y SQL Server Agent Job mensual.
- [`exportar_reporte_northwind.bat`](scripts/bat/exportar_reporte_northwind.bat): exportación del reporte mensual a CSV.

El job de Northwind se configura en `msdb` para ejecutarse el primer día de cada mes a las 02:00. También incluye una ejecución manual de prueba.

## Recomendaciones de ejecución

- Seleccionar explícitamente la conexión `@mssql-dev` o `@mssql-lab` en DataGrip antes de cada bloque.
- Ejecutar `sp_addlinkedserver`, `sp_addlinkedsrvlogin` y `sp_testlinkedserver` desde `master` de la instancia origen.
- Crear usuarios dentro de la base de datos destino; un login de servidor por sí solo no concede permisos sobre las tablas.
- Usar roles de base de datos como `db_datareader` y `db_datawriter` para el laboratorio. Evitar `sysadmin` salvo para administración explícita.
- Revisar los comandos de creación antes de repetir una práctica: varios scripts fueron diseñados para una ejecución inicial y no todos son completamente idempotentes.
- Los comandos `DROP`, `DELETE`, `TRUNCATE`, `RESTORE ... WITH REPLACE` y `sp_dropserver` son operaciones de laboratorio; confirmar el objetivo antes de ejecutarlos.
- Las rutas `/var/opt/mssql/...` corresponden al sistema de archivos del contenedor, no necesariamente al host.
- Las contraseñas escritas en los scripts son credenciales de laboratorio. No deben reutilizarse en producción ni exponerse fuera del entorno de práctica.

## Verificación mínima

Antes de considerar una práctica terminada, registrar:

1. Instancia y base de datos desde las que se ejecutó cada bloque.
2. Creación de tablas, usuarios, roles y linked servers.
3. Conteos de filas y consultas de validación.
4. Resultado de `sp_testlinkedserver` cuando corresponda.
5. Evidencia de permisos permitidos y rechazados.
6. Resultado de backups, restauraciones y verificaciones de integridad.
7. Comparación de totales antes y después de una fragmentación.

## Documentación futura

La documentación detallada de las prácticas está organizada actualmente en Nexus, incluyendo explicaciones, decisiones, logs y capturas de DataGrip. La intención es migrarla gradualmente al repositorio, junto con evidencias reproducibles, para que cada script tenga:

- objetivo y prerrequisitos;
- orden de ejecución por instancia;
- explicación de los bloques importantes;
- resultados esperados;
- consultas de validación;
- problemas encontrados y solución aplicada.

La carpeta `scripts/` es la fuente ejecutable del laboratorio; el README funciona como mapa general y guía de reproducción.
