#!/bin/bash

# Port forward MinIO for local development
# Usage: ./scripts/port-forward-minio.sh
# S3 API: localhost:9000
# Console UI: localhost:9001

echo "🪣 Starting MinIO port forward..."
echo "Connection details:"
echo "  S3 API: localhost:9000"
echo "  Console UI: http://localhost:9001"
echo "  Access Key: minio"
echo "  Secret Key: strongpassword"
echo ""
echo "S3 Endpoint: http://localhost:9000"
echo "Console UI: Open http://localhost:9001 in your browser and login with minio/strongpassword"
echo ""
echo "Press Ctrl+C to stop port forwarding"

kubectl port-forward -n minio svc/minio 9000:9000 9001:9001