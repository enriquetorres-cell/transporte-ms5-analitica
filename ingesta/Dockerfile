FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY comun.py ingesta_ms1.py ingesta_ms2.py ingesta_ms3.py ./
# El script a correr se pasa por CMD en el docker-compose (ingesta_msN.py).
ENTRYPOINT ["python"]
CMD ["ingesta_ms1.py"]
