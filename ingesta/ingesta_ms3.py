"""Contenedor de ingesta 03 · MS3 (MongoDB · calificaciones_db).
Pull del 100% de las 2 colecciones -> JSON (line-delimited) -> S3.
El formato JSON por línea (una fila por documento) lo lee bien Glue/Athena.
"""
import json
import os
import tempfile
from datetime import datetime, date
from pymongo import MongoClient
from comun import subir_a_s3, BD_HOST, BD_PASS

COLECCIONES = ["calificaciones", "reportes"]


def serializa(doc):
    doc["_id"] = str(doc.get("_id"))
    for k, v in list(doc.items()):
        if isinstance(v, (datetime, date)):
            doc[k] = v.isoformat() + ("Z" if isinstance(v, datetime) else "")
    return doc


def exportar(db, col):
    ruta = os.path.join(tempfile.gettempdir(), f"{col}.json")
    n = 0
    with open(ruta, "w", encoding="utf-8") as f:
        for doc in db[col].find({}):
            f.write(json.dumps(serializa(doc), ensure_ascii=False, default=str) + "\n")
            n += 1
    print(f"  {col}: {n:,} documentos")
    subir_a_s3(ruta, f"ms3/{col}.json")


def main():
    uri = f"mongodb://app_ms3:{BD_PASS}@{BD_HOST}:27017/calificaciones_db?authSource=calificaciones_db"
    cli = MongoClient(uri)
    db = cli.get_default_database()
    for c in COLECCIONES:
        exportar(db, c)
    print("Ingesta MS3 completa.")


if __name__ == "__main__":
    main()
