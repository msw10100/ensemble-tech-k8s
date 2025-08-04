#!/bin/bash

# Setup required GCP IAM permissions for Talos cluster with persistent storage
# This script must be run after creating the GCP instance

set -euo pipefail

source .env

echo "🔐 Setting up GCP IAM permissions for persistent storage..."

# Get the default compute service account
SERVICE_ACCOUNT=$(gcloud compute instances describe apollo-gcp-talos --zone=$GCP_ZONE --format="value(serviceAccounts[0].email)")

echo "📋 Found compute service account: $SERVICE_ACCOUNT"

# Grant compute storage admin role for CSI driver
echo "🚀 Granting compute.storageAdmin role..."
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member=serviceAccount:$SERVICE_ACCOUNT \
    --role=roles/compute.storageAdmin

echo "✅ IAM permissions configured successfully!"
echo ""
echo "The compute service account now has the following roles:"
gcloud projects get-iam-policy $GCP_PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:$SERVICE_ACCOUNT"