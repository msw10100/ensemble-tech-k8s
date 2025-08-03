#!/bin/bash

# Port forward RabbitMQ for local development
# Usage: ./scripts/port-forward-rabbitmq.sh
# AMQP: localhost:5672
# Management UI: localhost:15672

echo "🐰 Starting RabbitMQ port forward..."
echo "Connection details:"
echo "  AMQP Host: localhost"
echo "  AMQP Port: 5672"
echo "  Management UI: http://localhost:15672"
echo "  Username: rabbitmq"
echo "  Password: strongpassword"
echo ""
echo "Example AMQP connection: amqp://rabbitmq:strongpassword@localhost:5672/"
echo "Management UI: Open http://localhost:15672 in your browser and login with rabbitmq/strongpassword"
echo ""
echo "Press Ctrl+C to stop port forwarding"

kubectl port-forward -n rabbitmq svc/rabbitmq 5672:5672 15672:15672