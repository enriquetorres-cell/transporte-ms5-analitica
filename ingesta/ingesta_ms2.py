"""Contenedor de ingesta 02 · MS2 (MySQL · viajes_db).
Pull del 100% de las 3 tablas -> CSV -> S3.
"""
import csv
import os
import tempfile
import mysql.connector
from comun import subir_a_s3, BD_HOST, BD_PASS

TABLAS = ["tarifas", "viajes", "paradas"]


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
    subir_a_s3(ruta, f"{tabla}/{tabla}.csv")


def main():
    cn = mysql.connector.connect(
        host=BD_HOST, database="viajes_db", user="app_ms2", password=BD_PASS
    )
    cur = cn.cursor()
    for t in TABLAS:
        exportar(cur, t)
    cur.close(); cn.close()
    print("Ingesta MS2 completa.")


if __name__ == "__main__":
    main()
