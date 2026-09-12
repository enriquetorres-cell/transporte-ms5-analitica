"""MS5 · Microservicio analítico (Contrato Cero).
Ejecuta consultas SQL en AWS Athena sobre el catálogo Glue del data lake (S3).
Todas las rutas bajo el prefijo /ms5. Swagger en /ms5/docs.
"""
import os
import time
import boto3
from fastapi import FastAPI, HTTPException

PREFIX = "/ms5"
REGION = os.environ.get("AWS_REGION", "us-east-1")
ATHENA_DB = os.environ.get("ATHENA_DB", "transporte")
ATHENA_OUTPUT = os.environ["ATHENA_OUTPUT"]        # s3://.../athena-results/
WORKGROUP = os.environ.get("ATHENA_WORKGROUP", "primary")

app = FastAPI(
    title="MS5 - Analítico (Athena)",
    version="1.0.0",
    docs_url=f"{PREFIX}/docs",
    openapi_url=f"{PREFIX}/openapi.json",
)


@app.get(f"{PREFIX}/health")
def health():
    return {"status": "ok", "servicio": "ms5"}


def ejecutar_athena(sql: str):
    """Corre una query en Athena y devuelve filas como lista de dicts."""
    ath = boto3.client("athena", region_name=REGION)
    qid = ath.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": ATHENA_DB},
        ResultConfiguration={"OutputLocation": ATHENA_OUTPUT},
        WorkGroup=WORKGROUP,
    )["QueryExecutionId"]

    # Espera a que termine (con timeout).
    for _ in range(60):
        est = ath.get_query_execution(QueryExecutionId=qid)["QueryExecution"]["Status"]["State"]
        if est in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)
    if est != "SUCCEEDED":
        raise HTTPException(status_code=500, detail=f"Athena: consulta {est}")

    res = ath.get_query_results(QueryExecutionId=qid)
    filas = res["ResultSet"]["Rows"]
    if not filas:
        return []
    cols = [c["VarCharValue"] for c in filas[0]["Data"]]
    salida = []
    for fila in filas[1:]:
        vals = [d.get("VarCharValue") for d in fila["Data"]]
        salida.append(dict(zip(cols, vals)))
    return salida


@app.get(PREFIX + "/ingresos/por-hora-distrito")
def ingresos_por_hora_distrito():
    """Consulta estrella: ingreso promedio por hora del día y por distrito.
    Une viajes (MS2). Devuelve {total, items:[{distrito, hora, viajes, ingreso_promedio, ingreso_total}]}.
    """
    sql = """
        SELECT distrito_origen AS distrito,
               hour(from_iso8601_timestamp(solicitado_en)) AS hora,
               count(*)                 AS viajes,
               round(avg(monto_total),2) AS ingreso_promedio,
               round(sum(monto_total),2) AS ingreso_total
        FROM viajes
        WHERE estado = 'finalizado'
        GROUP BY distrito_origen, hour(from_iso8601_timestamp(solicitado_en))
        ORDER BY distrito, hora
    """
    items = ejecutar_athena(sql)
    for it in items:
        it["hora"] = int(it["hora"])
        it["viajes"] = int(it["viajes"])
        it["ingreso_promedio"] = float(it["ingreso_promedio"])
        it["ingreso_total"] = float(it["ingreso_total"])
    return {"total": len(items), "items": items}


@app.get(PREFIX + "/rating-por-distrito")
def rating_por_distrito():
    """Une calificaciones (MS3) con viajes (MS2): rating promedio por distrito de origen."""
    sql = """
        SELECT v.distrito_origen AS distrito,
               count(*)                AS calificaciones,
               round(avg(c.rating),2)  AS rating_promedio
        FROM calificaciones c
        JOIN viajes v ON c.viaje_id = v.id
        GROUP BY v.distrito_origen
        ORDER BY rating_promedio DESC
    """
    return {"items": ejecutar_athena(sql)}
