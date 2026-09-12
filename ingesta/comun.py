"""Utilidades compartidas por los 3 contenedores de ingesta.
Estrategia PULL: leen el 100% de los registros de una tabla/colección,
generan un archivo (CSV/JSON) y lo suben a un bucket S3.
"""
import os
import boto3

S3_BUCKET = os.environ["S3_BUCKET"]            # obligatorio
S3_PREFIX = os.environ.get("S3_PREFIX", "ingesta")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# La IP privada de mv-bd y la clave son las mismas de docker-compose.bd.yml.
BD_HOST = os.environ.get("BD_HOST", "10.0.2.85")
BD_PASS = os.environ.get("BD_PASS", "Transporte2026")


def subir_a_s3(ruta_local, nombre_destino):
    """Sube un archivo al bucket, bajo <S3_PREFIX>/<nombre_destino>."""
    s3 = boto3.client("s3", region_name=REGION)
    clave = f"{S3_PREFIX}/{nombre_destino}"
    s3.upload_file(ruta_local, S3_BUCKET, clave)
    print(f"OK  s3://{S3_BUCKET}/{clave}")
    return clave
