-- =====================================================================
--  MS5 · Athena · base Glue "transporte_urbano" sobre el data lake en S3
--  (s3://transporte-datalake-et/catalogo/<tabla>/)
--
--  Las 8 tablas las crea el Glue Crawler "transporte-crawler" (una por
--  archivo del bucket): usuarios, conductores, vehiculos (MS1) ·
--  viajes, tarifas, paradas (MS2) · calificaciones, reportes (MS3).
--
--  Result location de Athena: s3://transporte-datalake-et/athena-results/
--  Todo lo de abajo se ejecutó y verificó en Athena (estado SUCCEEDED).
-- =====================================================================

-- =====================================================================
--  4 CONSULTAS que unen varias tablas (requisito: mínimo 4)
-- =====================================================================

-- 1) Ingreso por tipo de servicio y marca de vehículo:
--    viajes (MS2) JOIN vehiculos (MS1) JOIN tarifas (MS2)
SELECT ve.tipo_servicio,
       ve.marca,
       t.tarifa_base,
       count(*)                   AS viajes,
       round(avg(v.monto_total),2) AS ticket_promedio,
       round(sum(v.monto_total),2) AS ingreso_total
FROM transporte_urbano.viajes v
JOIN transporte_urbano.vehiculos ve ON v.vehiculo_id = ve.id
JOIN transporte_urbano.tarifas t    ON v.tarifa_id  = t.id
WHERE v.estado = 'finalizado'
GROUP BY ve.tipo_servicio, ve.marca, t.tarifa_base
ORDER BY ingreso_total DESC;

-- 2) Rating promedio por distrito de origen:
--    calificaciones (MS3) JOIN viajes (MS2)
SELECT v.distrito_origen        AS distrito,
       count(*)                 AS total_calificaciones,
       round(avg(c.rating),2)   AS rating_promedio
FROM transporte_urbano.calificaciones c
JOIN transporte_urbano.viajes v ON c.viaje_id = v.id
GROUP BY v.distrito_origen
ORDER BY rating_promedio DESC;

-- 3) Top 20 conductores por ingreso:
--    viajes (MS2) JOIN conductores (MS1)
SELECT co.id AS conductor_id,
       co.nombre, co.apellido, co.distrito_base,
       count(*)                    AS viajes,
       round(sum(v.monto_total),2) AS ingreso_total
FROM transporte_urbano.viajes v
JOIN transporte_urbano.conductores co ON v.conductor_id = co.id
WHERE v.estado = 'finalizado'
GROUP BY co.id, co.nombre, co.apellido, co.distrito_base
ORDER BY ingreso_total DESC
LIMIT 20;

-- 4) Satisfacción del pasajero por distrito donde vive:
--    usuarios (MS1) JOIN viajes (MS2) JOIN calificaciones (MS3)
SELECT u.distrito                   AS distrito_pasajero,
       count(DISTINCT v.id)         AS viajes,
       round(avg(c.rating),2)       AS rating_promedio,
       round(avg(v.monto_total),2)  AS ticket_promedio
FROM transporte_urbano.usuarios u
JOIN transporte_urbano.viajes v         ON v.pasajero_id = u.id
JOIN transporte_urbano.calificaciones c ON c.viaje_id    = v.id
GROUP BY u.distrito
ORDER BY rating_promedio DESC;

-- =====================================================================
--  2 VISTAS (requisito: mínimo 2) — definición tal como existe en Glue
-- =====================================================================

-- Ingreso promedio por distrito y hora del día (viajes finalizados)
CREATE OR REPLACE VIEW transporte_urbano.v_ingreso_hora_distrito AS
SELECT distrito_origen AS distrito,
       hour(CAST(iniciado_en AS timestamp)) AS hora,
       count(*) AS viajes,
       round(avg(monto_total), 2) AS ingreso_promedio
FROM transporte_urbano.viajes
WHERE estado = 'finalizado'
GROUP BY distrito_origen, hour(CAST(iniciado_en AS timestamp));

-- Rating de cada conductor: conductores (MS1) JOIN calificaciones (MS3)
CREATE OR REPLACE VIEW transporte_urbano.v_rating_conductor AS
SELECT co.id AS conductor_id, co.nombre, co.apellido,
       count(cal.viaje_id) AS calificaciones,
       round(avg(cal.rating), 2) AS rating_promedio
FROM transporte_urbano.conductores co
JOIN transporte_urbano.calificaciones cal ON cal.conductor_id = co.id
GROUP BY co.id, co.nombre, co.apellido;

-- Uso de las vistas
SELECT * FROM transporte_urbano.v_rating_conductor ORDER BY rating_promedio DESC LIMIT 10;
SELECT * FROM transporte_urbano.v_ingreso_hora_distrito ORDER BY ingreso_promedio DESC LIMIT 10;
