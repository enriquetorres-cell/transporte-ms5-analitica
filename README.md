# transporte-ms5-analitica (P5)

Parte de **Data Science** del proyecto de transporte urbano · CS2032.
Dos piezas:

```
ingesta/   · 3 contenedores Docker (pull) que leen las 3 bases y suben archivos a S3
ms5/       · microservicio analítico (FastAPI) que consulta Athena  (prefijo /ms5)
athena/    · DDL del catálogo + 4 consultas con JOIN + 2 vistas
```

## Arquitectura

```
mv-bd (privada)              mv-ingesta (pública)             S3 (data lake)        Athena / Glue
 postgres ─┐                  ingesta01 (MS1) ─► ms1/*.csv ─┐
 mysql    ─┼──(pull 100%)──►  ingesta02 (MS2) ─► ms2/*.csv ─┼─► s3://<bucket>/ingesta/ ─► catálogo Glue ─► MS5 (/ms5)
 mongo    ─┘                  ingesta03 (MS3) ─► ms3/*.json ─┘
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
git clone https://github.com/<tu-usuario>/transporte-ms5-analitica.git
cd transporte-ms5-analitica/ingesta
export S3_BUCKET=transporte-datalake-et
# credenciales AWS del Learner Lab (para poder subir a S3):
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...
```

> `mv-ingesta` está en `sg-prod`, así que **alcanza a `mv-bd`** (10.0.2.85) en los
> puertos de las 3 bases. La clave de las bases es `Transporte2026`.

### 3. Correr los 3 contenedores de ingesta

```bash
docker compose up --build
```

Cada uno lee su base y sube los archivos. Verifica en S3:

```bash
aws s3 ls s3://$S3_BUCKET/ingesta/ --recursive
```

Debe listar `ms1/usuarios.csv`, `ms2/viajes.csv`, `ms3/calificaciones.json`, etc.
**Con esto ya cumples el 50%** (ingesta + S3 + datos cargados).

---

## Para el HITO 2 (completo)

### 4. Catálogo Glue

- Consola AWS → **Glue** → Crawlers → crear uno que apunte a `s3://<bucket>/ingesta/`
  y escriba en la base `transporte`. Ejecutarlo → crea una tabla por carpeta.
- (Alternativa) crear las tablas a mano con el DDL de [`athena/consultas.sql`](athena/consultas.sql).

### 5. Athena: 4 consultas + 2 vistas

Abre **Athena**, configura el *query result location* (`s3://<bucket>/athena-results/`)
y corre [`athena/consultas.sql`](athena/consultas.sql): trae 4 consultas con JOIN
entre tablas y crea 2 vistas.

### 6. MS5 (microservicio analítico)

```bash
cd ms5
docker build -t <tu-usuario>/transporte-ms5:1.0 .
docker run -d --name ms5 -p 8005:8005 \
  -e ATHENA_DB=transporte \
  -e ATHENA_OUTPUT=s3://$S3_BUCKET/athena-results/ \
  -e AWS_ACCESS_KEY_ID=... -e AWS_SECRET_ACCESS_KEY=... -e AWS_SESSION_TOKEN=... \
  <tu-usuario>/transporte-ms5:1.0
curl http://localhost:8005/ms5/health
```

Endpoints:
- `GET /ms5/health`
- `GET /ms5/docs` (Swagger)
- `GET /ms5/ingresos/por-hora-distrito` — **consulta estrella** (la usa el frontend)
- `GET /ms5/rating-por-distrito`

Publica la imagen y avísale a P1 el nombre/tag para el `docker-compose.prod.yml`.

---

## Diagrama E/R del catálogo

Del DDL en `athena/consultas.sql`, las tablas del catálogo se relacionan así (referencias lógicas):

```
usuarios.id ──< viajes.pasajero_id
conductores.id ──< viajes.conductor_id
viajes.id ──< calificaciones.viaje_id
```
