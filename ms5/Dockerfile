FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
EXPOSE 8005
ENV AWS_REGION=us-east-1
# Uvicorn escucha en 0.0.0.0:8005; el prefijo /ms5 lo pone la app.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8005"]
