FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY kafka-api-server.py .
COPY kafka-frontend.html .

EXPOSE 5000

CMD ["python", "kafka-api-server.py"]
