#!/bin/bash

# Port forward Redis for local development
# Usage: ./scripts/port-forward-redis.sh
# Connects to: localhost:6379

echo "🔴 Starting Redis port forward..."
echo "Connection details:"
echo "  Host: localhost"
echo "  Port: 6379"
echo ""
echo "Example connection: redis-cli -h localhost -p 6379"
echo ""
echo "Press Ctrl+C to stop port forwarding"

kubectl port-forward -n redis svc/redis 6379:6379