"""Contenedor de ingesta 01 · MS1 (PostgreSQL · usuarios_db).
Pull del 100% de las 3 tablas -> CSV -> S3.
"""
import csv
import os
import tempfile
import psycopg2
from comun import subir_a_s3, BD_HOST, BD_PASS

TABLAS = ["usuarios", "conductores", "vehiculos"]


def exportar(cur, tabla):
    cur.execute(f"SELECT * FROM {tabla}")
    cols = [d[0] for d in cur.description]
    ruta = os.path.join(tempfile.gettempdir(), f"{tabla}.csv")
    with open(ruta, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(cols)
        n = 0
        for fila in cur:
            w.writerow(fila)
            n += 1
    print(f"  {tabla}: {n:,} filas")
    subir_a_s3(ruta, f"ms1/{tabla}.csv")


def main():
    cn = psycopg2.connect(
        host=BD_HOST, dbname="usuarios_db", user="app_ms1", password=BD_PASS
    )
    cur = cn.cursor()
    for t in TABLAS:
        exportar(cur, t)
    cur.close(); cn.close()
    print("Ingesta MS1 completa.")


if __name__ == "__main__":
    main()
