#!/bin/bash

# Port forward PostgreSQL for local development
# Usage: ./scripts/port-forward-postgres.sh
# Connects to: localhost:5432
# Credentials: postgres/strongpassword

echo "🐘 Starting PostgreSQL port forward..."
echo "Connection details:"
echo "  Host: localhost"
echo "  Port: 5432"
echo "  Username: postgres"
echo "  Password: strongpassword"
echo "  Database: postgres"
echo ""
echo "Example connection: psql -h localhost -p 5432 -U postgres -d postgres"
echo ""
echo "Press Ctrl+C to stop port forwarding"

kubectl port-forward -n postgres svc/postgresql 5432:5432