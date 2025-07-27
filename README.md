# Kafka-MongoDB API Demo

This project demonstrates a Python API that sends messages through Kafka and stores them in MongoDB. It's containerized using Docker and deployed to Kubernetes.

---

## Project Structure

```
.
├── app/                         # Python API app
│   ├── Dockerfile               # Builds the API image
│   ├── requirements.txt         # Python dependencies
│   └── src/
│       ├── kafka-api-server.py  # Flask app
│       └── kafka-frontend.html  # Frontend page
├── deploy/                      # Kubernetes manifests
│   ├── kafka-api.yaml           # Deployment & Service for the API
│   └── kafka-connect-config.yaml # Kafka Connect sink connector config
├── kafka-connect/
│   ├── Dockerfile               # Custom Kafka Connect image
│   └── plugins/
│       └── mongo-kafka-connect-2.0.0-all.jar
├── helm/                        # Helm chart value overrides
│   ├── kafka-values.yaml
│   └── mongodb-values.yaml
├── terraform/                   # Infra as Code (optional for EKS setup)
│   ├── main.tf
│   └── variables.tf
└── README.md
```


> **Note:** The `mongo-kafka-connect-2.0.0-all.jar` file in `kafka-connect/plugins/` is **not included** in this repository due to size.  
> You need to download the MongoDB Kafka Connector JAR from the [official MongoDB Kafka Connector releases](https://github.com/mongodb/mongo-kafka/releases) page and place it inside the `kafka-connect/plugins/` directory **before** building the Kafka Connect Docker image.

---

## How It Works

- Kafka topics receive messages (e.g., purchases).
- Kafka Connect (custom image to talk to MongoDB) pushes these messages to MongoDB.
- The Python API exposes an endpoint to write purchases through Kafka and return all purchases from MongoDB.
- A simple frontend allows basic interaction.

---

## Secrets

Secrets like the MongoDB URI are injected into the container using Kubernetes Secrets and environment variables (e.g., `MONGO_URI`).  
These values are not stored in version control.

---
# Build & Deploy

### Build the API Docker Image
```bash
cd app
docker build -t your-dockerhub-username/kafka-api:latest .
docker push your-dockerhub-username/kafka-api:latest
```
### Build the Kafka Connect Docker Image

# Place the MongoDB Kafka Connector JAR file (`mongo-kafka-connect-2.0.0-all.jar`) inside the `kafka-connect/plugins/` directory

```bash
cd kafka-connect
docker build -t your-dockerhub-username/kafka-connect:latest .
docker push your-dockerhub-username/kafka-connect:latest
```

# Deploy the Infrastructure and Application

# Create MongoDB credentials secret
```bash
kubectl create secret generic mongodb-creds \
  --from-literal=mongodb-root-password=<root-password> \
  --from-literal=mongodb-username=<mongodb-username> \
  --from-literal=mongodb-password=<mongodb-password> \
  --from-literal=mongodb-replica-set-key=<replica-set-key>
```
# Install MongoDB using Helm
```bash
helm install mongodb bitnami/mongodb -f helm/mongodb-values.yaml
```
# Create Kafka MongoDB user inside MongoDB
```bash
kubectl exec -it mongodb-0 -- mongosh -u root -p <root-password> --authenticationDatabase admin
```
# In the mongosh shell, run the following commands:
```bash
use <database-name>
db.createUser({
  user: "<kafka-connect-username>",
  pwd: "<kafka-connect-password>",
  roles: [ { role: "readWrite", db: "<database-name>" } ]
})
```
# Apply Kafka Connect configuration
```bash
kubectl apply -f deploy/kafka-connect-config.yaml
```
# Install Kafka using Helm
```bash
helm install kafka bitnami/kafka -f helm/kafka-values.yaml
```
# Create MongoDB connection secret for the app and Kafka Connect
```bash
kubectl create secret generic mongodb-connection \
  --from-literal=MONGO_URI='mongodb://<kafka-connect-username>:<kafka-connect-password>@mongodb-0.mongodb-headless.default.svc.cluster.local:27017,mongodb-1.mongodb-headless.default.svc.cluster.local:27017,mongodb-arbiter-0.mongodb-arbiter-headless.default.svc.cluster.local:27017/?replicaSet=rs0&authSource=<auth-database>'
```
# Register the MongoDB Sink Connector with Kafka Connect
```bash
kubectl exec -it deployment/kafka-connect -- /bin/sh
```
# Inside the Kafka Connect pod shell, run:
```bash
curl -X POST http://localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "mongo-sink",
    "config": {
      "connector.class": "com.mongodb.kafka.connect.MongoSinkConnector",
      "tasks.max": "1",
      "topics": "<topic-name>",
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false",
      "connection.uri": "'"$MONGO_URI"'",
      "database": "<database-name>",
      "collection": "<collection-name>",
      "document.id.strategy": "com.mongodb.kafka.connect.sink.processor.id.strategy.BsonOidStrategy"
    }
  }'
```
# Deploy your API and frontend
```bash
kubectl apply -f deploy/
```

**Note**: This assumes your Kubernetes cluster has Helm installed and configured, and that your Docker images are pushed to registries accessible by your cluster.

---
