-- =====================================================================
--  MS5 · Athena · catálogo "transporte" sobre el data lake en S3
--  Reemplaza  <BUCKET>  por tu bucket (ej. transporte-datalake-et).
--
--  Opción A (recomendada): un Glue Crawler crea estas tablas solo.
--  Opción B: crea las tablas EXTERNAL a mano con el DDL de abajo.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS transporte;

-- ---------- Tablas externas (una por archivo del bucket) --------------
-- MS2 · viajes (CSV con encabezado)
CREATE EXTERNAL TABLE IF NOT EXISTS transporte.viajes (
  id int, pasajero_id int, conductor_id int, vehiculo_id int, tarifa_id int,
  estado string, metodo_pago string, distrito_origen string, distrito_destino string,
  direccion_origen string, direccion_destino string,
  distancia_km double, duracion_min int, monto_total double,
  solicitado_en string, iniciado_en string, finalizado_en string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar'=',','quoteChar'='"')
LOCATION 's3://<BUCKET>/ingesta/ms2/viajes/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- MS1 · usuarios (CSV)
CREATE EXTERNAL TABLE IF NOT EXISTS transporte.usuarios (
  id int, nombre string, apellido string, email string, telefono string,
  distrito string, fecha_nacimiento string, fecha_registro string, activo string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar'=',','quoteChar'='"')
LOCATION 's3://<BUCKET>/ingesta/ms1/usuarios/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- MS1 · conductores (CSV)
CREATE EXTERNAL TABLE IF NOT EXISTS transporte.conductores (
  id int, nombre string, apellido string, email string, telefono string,
  nro_licencia string, distrito_base string, fecha_ingreso string,
  calificacion_promedio double, activo string
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar'=',','quoteChar'='"')
LOCATION 's3://<BUCKET>/ingesta/ms1/conductores/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- MS3 · calificaciones (JSON por línea)
CREATE EXTERNAL TABLE IF NOT EXISTS transporte.calificaciones (
  viaje_id int, pasajero_id int, conductor_id int, rating int,
  comentario string, idioma string, distrito_origen string, distrito_destino string,
  creado_en string
)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://<BUCKET>/ingesta/ms3/calificaciones/';

-- =====================================================================
--  4 CONSULTAS que unen varias tablas (requisito: mínimo 4)
-- =====================================================================

-- 1) Consulta estrella: ingreso promedio por hora del día y por distrito (MS2)
SELECT distrito_origen AS distrito,
       hour(from_iso8601_timestamp(solicitado_en)) AS hora,
       count(*) AS viajes,
       round(avg(monto_total),2) AS ingreso_promedio,
       round(sum(monto_total),2) AS ingreso_total
FROM transporte.viajes
WHERE estado = 'finalizado'
GROUP BY distrito_origen, hour(from_iso8601_timestamp(solicitado_en))
ORDER BY distrito, hora;

-- 2) Rating promedio por distrito: calificaciones (MS3) JOIN viajes (MS2)
SELECT v.distrito_origen AS distrito,
       count(*) AS total_calificaciones,
       round(avg(c.rating),2) AS rating_promedio
FROM transporte.calificaciones c
JOIN transporte.viajes v ON c.viaje_id = v.id
GROUP BY v.distrito_origen
ORDER BY rating_promedio DESC;

-- 3) Top conductores por ingreso: viajes (MS2) JOIN conductores (MS1)
SELECT co.id AS conductor_id,
       co.nombre, co.apellido, co.distrito_base,
       count(*) AS viajes,
       round(sum(v.monto_total),2) AS ingreso_total
FROM transporte.viajes v
JOIN transporte.conductores co ON v.conductor_id = co.id
WHERE v.estado = 'finalizado'
GROUP BY co.id, co.nombre, co.apellido, co.distrito_base
ORDER BY ingreso_total DESC
LIMIT 20;

-- 4) Satisfacción del pasajero: usuarios (MS1) JOIN viajes JOIN calificaciones (MS3)
SELECT u.distrito AS distrito_pasajero,
       count(DISTINCT v.id) AS viajes,
       round(avg(c.rating),2) AS rating_promedio,
       round(avg(v.monto_total),2) AS ticket_promedio
FROM transporte.usuarios u
JOIN transporte.viajes v ON v.pasajero_id = u.id
JOIN transporte.calificaciones c ON c.viaje_id = v.id
GROUP BY u.distrito
ORDER BY rating_promedio DESC;

-- =====================================================================
--  2 VISTAS (requisito: mínimo 2)
-- =====================================================================

CREATE OR REPLACE VIEW transporte.v_ingreso_hora_distrito AS
SELECT distrito_origen AS distrito,
       hour(from_iso8601_timestamp(solicitado_en)) AS hora,
       count(*) AS viajes,
       round(avg(monto_total),2) AS ingreso_promedio
FROM transporte.viajes
WHERE estado = 'finalizado'
GROUP BY distrito_origen, hour(from_iso8601_timestamp(solicitado_en));

CREATE OR REPLACE VIEW transporte.v_rating_conductor AS
SELECT co.id AS conductor_id, co.nombre, co.apellido,
       count(*) AS calificaciones,
       round(avg(c.rating),2) AS rating_promedio
FROM transporte.calificaciones c
JOIN transporte.conductores co ON c.conductor_id = co.id
GROUP BY co.id, co.nombre, co.apellido;
