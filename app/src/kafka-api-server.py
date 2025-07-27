from flask import Flask, request, jsonify, send_from_directory
from kafka import KafkaProducer
from pymongo import MongoClient
import json
import os

app = Flask(__name__)

producer = KafkaProducer(
    bootstrap_servers='kafka:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

mongo_url = os.getenv('MONGO_URI')
mongo = MongoClient(mongo_url)
db = mongo['shop']
collection = db['purchases']

@app.route('/')
def frontend():
    return send_from_directory('.', 'kafka-frontend.html')

@app.route('/purchase', methods=['POST'])
def handle_purchase():
    item = request.form['item']
    price = float(request.form['price'])

    purchase = {
        'item': item,
        'price': price
    }

    producer.send('api-purchases', value=purchase)
    producer.flush()

    return jsonify({'message': 'Purchase sent to Kafka!', 'purchase': purchase}), 200

@app.route('/list', methods=['GET'])
def handle_list():
    items = list(collection.find({}, {'_id': 0}))

    return jsonify({'items': items}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
