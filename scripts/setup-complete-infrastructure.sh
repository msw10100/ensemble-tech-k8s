#!/bin/bash

# Complete infrastructure setup script incorporating all discoveries
# This script sets up a fresh Talos cluster with persistent storage on GCP

set -euo pipefail

source .env

echo "🚀 Setting up complete infrastructure with persistent storage..."
echo "Project: $GCP_PROJECT_ID"
echo "Zone: $GCP_ZONE"
echo ""

# Step 1: Create Talos instance with proper scopes
echo "📦 Step 1: Creating GCP instance with proper scopes..."
./scripts/create-talos-gcp-instance.sh

# Step 2: Setup IAM permissions
echo "🔐 Step 2: Configuring IAM permissions..."
sleep 10  # Brief pause to ensure instance is fully created
./scripts/setup-gcp-permissions.sh

# Step 3: Wait for machine registration
echo "⏳ Step 3: Waiting for machine to register with Omni..."
echo "This typically takes 2-3 minutes..."
sleep 180

# Step 4: Create cluster
echo "🏗️  Step 4: Creating Kubernetes cluster..."
omnictl cluster template sync --file cluster-template.yaml --context=$OMNI_CONTEXT

# Step 5: Wait for cluster to be ready
echo "⏳ Step 5: Waiting for cluster to be ready..."
sleep 120

# Step 6: Setup cluster
echo "🔧 Step 6: Setting up cluster with GitOps..."
./scripts/setup-fresh-cluster.sh

echo "🎉 Complete infrastructure setup finished!"
echo ""
echo "Next steps:"
echo "1. Update cluster-template.yaml with the new machine ID if needed"
echo "2. Run: kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-"
echo "3. Monitor applications: kubectl get applications -n argocd"
echo "4. Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"