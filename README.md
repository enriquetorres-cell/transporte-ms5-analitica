# transporte-ms5-analitica (P5)

Parte de **Data Science** del proyecto de transporte urbano · CS2032.
Dos piezas:

```
ingesta/   · 3 contenedores Docker (pull) que leen las 3 bases y suben archivos a S3
ms5/       · microservicio analítico (FastAPI) que consulta Athena  (prefijo /ms5)
athena/    · 4 consultas con JOIN + 2 vistas (verificadas en Athena)
```

> **Despliegue completo del proyecto en AWS (paso a paso):** ver la
> [guía principal](https://github.com/Limepal/MS1-Usuarios-y-Conductores#readme): paso 4 (MS5) y paso 8 (data lake).

## Arquitectura

```
mv-bd (privada)              mv-ingesta (pública)             S3 (data lake)        Athena / Glue
 postgres ─┐                  ingesta01 (MS1) ─► usuarios, conductores, vehiculos (.csv) ─┐
 mysql    ─┼──(pull 100%)──►  ingesta02 (MS2) ─► viajes, tarifas, paradas (.csv)          ─┼─► s3://<bucket>/catalogo/<tabla>/ ─► crawler ─► Glue (transporte_urbano) ─► Athena ─► MS5 (/ms5)
 mongo    ─┘                  ingesta03 (MS3) ─► calificaciones, reportes (.json)         ─┘
```

---

## Para el HITO 1 (50% de Data Science)

El enunciado pide para el 50%: **MV de ingesta configurada + bucket S3 creado + al menos 1 contenedor de ingesta funcionando con datos cargados en S3.** Con esto lo cumples:

### 1. Crear el bucket S3

```bash
export S3_BUCKET=transporte-datalake-et      # nombre único global
aws s3 mb s3://$S3_BUCKET --region us-east-1
```

### 2. En la MV de ingesta (`mv-ingesta`), clonar y configurar

```bash
git clone https://github.com/enriquetorres-cell/transporte-ms5-analitica.git
cd transporte-ms5-analitica/ingesta
export S3_BUCKET=transporte-datalake-et
export BD_PASS=...   # clave de las bases (pídela al equipo; no va en el repo)
# Credenciales de S3: las da el rol LabInstanceProfile de la MV (no hace falta pegar llaves).
# Solo si la MV no tiene rol: export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...
```

> `mv-ingesta` está en `sg-prod`, así que **alcanza a `mv-bd`** (10.0.2.85) en los
> puertos de las 3 bases.

### 3. Correr los 3 contenedores de ingesta

```bash
docker compose up --build
```

Cada uno lee su base y sube los archivos. Verifica en S3:

```bash
aws s3 ls s3://$S3_BUCKET/catalogo/ --recursive
```

Debe listar `usuarios/usuarios.csv`, `viajes/viajes.csv`, `calificaciones/calificaciones.json`, etc.
(una carpeta por tabla: así el crawler crea una tabla por archivo).
**Con esto ya cumples el 50%** (ingesta + S3 + datos cargados).

---

## Para el HITO 2 (completo)

### 4. Catálogo Glue

```bash
aws glue create-database --database-input Name=transporte_urbano
aws glue create-crawler --name transporte-crawler --role LabRole --database-name transporte_urbano \
  --targets '{"S3Targets":[{"Path":"s3://<BUCKET>/catalogo/"}]}'
aws glue start-crawler --name transporte-crawler
```

- Crawler **`transporte-crawler`** sobre `s3://transporte-datalake-et/catalogo/<tabla>/`
  → base Glue **`transporte_urbano`**, una tabla por archivo (8 tablas: usuarios, conductores,
  vehiculos, viajes, tarifas, paradas, calificaciones, reportes).

### 5. Athena: 4 consultas + 2 vistas

Abre **Athena**, configura el *query result location* (`s3://transporte-datalake-et/athena-results/`)
y corre [`athena/consultas.sql`](athena/consultas.sql): 4 consultas que unen 2–3 tablas de
distintos microservicios y las 2 vistas (`v_ingreso_hora_distrito`, `v_rating_conductor`)
tal como existen en Glue. Todas verificadas en Athena.

### 6. MS5 (microservicio analítico)

Corre en mv-prod-a y mv-prod-b (ver `transporte-infra/docker-compose.prod.yml` en el repo de MS1).

```bash
cd ms5
docker build -t ms5img .
docker run -d --name ms5 --network host --restart unless-stopped \
  -e GLUE_DATABASE=transporte_urbano \
  -e ATHENA_OUTPUT=s3://transporte-datalake-et/athena-results/ \
  ms5img
curl http://localhost:8005/ms5/health
```

Sin llaves AWS: boto3 usa el rol `LabInstanceProfile` de la MV, que se renueva solo.

Endpoints:
- `GET /ms5/health`
- `GET /ms5/docs` (Swagger)
- `GET /ms5/ingresos/por-hora-distrito?distrito=` — **consulta estrella** (la usa el frontend)
- `GET /ms5/conductores/rating-por-distrito` — conductores JOIN calificaciones (la usa el frontend)
- `GET /ms5/conductores/rating-por-antiguedad` — conductores JOIN viajes JOIN calificaciones
- `GET /ms5/rutas/top-distritos?minimo=50` — viajes JOIN calificaciones
- `GET /ms5/vistas/rating-conductor?limit=10` — lee la **vista** `v_rating_conductor`
- `GET /ms5/vistas/ingreso-hora-distrito?limit=10` — lee la **vista** `v_ingreso_hora_distrito`

---

## Diagrama E/R del catálogo

Del DDL en `athena/consultas.sql`, las tablas del catálogo se relacionan así (referencias lógicas):

```
usuarios.id ──< viajes.pasajero_id
conductores.id ──< viajes.conductor_id
viajes.id ──< calificaciones.viaje_id
```
