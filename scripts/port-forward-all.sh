#!/bin/bash

# Port forward all services for local development
# Usage: ./scripts/port-forward-all.sh
# This runs all port forwards in parallel

echo "🚀 Starting all service port forwards..."
echo ""
echo "Services will be available at:"
echo "  PostgreSQL: localhost:5432 (postgres/strongpassword)"
echo "  Redis: localhost:6379"
echo "  RabbitMQ AMQP: localhost:5672 (rabbitmq/strongpassword)"
echo "  RabbitMQ Management: http://localhost:15672 (rabbitmq/strongpassword)"
echo ""
echo "Press Ctrl+C to stop all port forwarding"
echo ""

# Function to clean up background jobs on exit
cleanup() {
    echo ""
    echo "🛑 Stopping all port forwards..."
    jobs -p | xargs kill
    exit 0
}

# Set up trap to clean up on exit
trap cleanup SIGINT SIGTERM

# Start all port forwards in background
kubectl port-forward -n postgres svc/postgresql 5432:5432 &
kubectl port-forward -n redis svc/redis 6379:6379 &
kubectl port-forward -n rabbitmq svc/rabbitmq 5672:5672 15672:15672 &

# Wait for all background jobs
wait