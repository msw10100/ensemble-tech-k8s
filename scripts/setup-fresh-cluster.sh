#!/bin/bash

# Setup script for fresh cluster deployment
# This script configures kubectl and deploys ArgoCD with all our GitOps infrastructure

set -euo pipefail

CLUSTER_NAME="talos-ipv6-cluster"
OMNI_CONTEXT="default-1"
KUBECONFIG_FILE="$HOME/.kube/config"

echo "🚀 Setting up fresh cluster: $CLUSTER_NAME"

# Step 1: Download kubeconfig
echo "📥 Downloading kubeconfig..."
omnictl kubeconfig --cluster "$CLUSTER_NAME" --context="$OMNI_CONTEXT" > "$KUBECONFIG_FILE"
echo "✅ Kubeconfig downloaded to $KUBECONFIG_FILE"

# Step 2: Verify cluster connectivity
echo "🔗 Testing cluster connectivity..."
kubectl get nodes
echo "✅ Cluster is accessible"

# Step 3: Install ArgoCD
echo "🔄 Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Step 4: Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Step 5: Apply root GitOps application
echo "📋 Deploying GitOps root application..."
kubectl apply -f argocd/applications.yaml

# Step 6: Create GitHub repository secret
echo "🔐 Creating GitHub repository credentials..."
kubectl create secret generic github-repo-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/msw10100/ensemble-tech-k8s \
  --from-literal=password=${GH_TOKEN:-} \
  --from-literal=username=msw10100 \
  -n argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret github-repo-creds argocd.argoproj.io/secret-type=repository -n argocd

# Step 7: Create Cloudflare secret for cert-manager
echo "🌐 Creating Cloudflare API token secret..."
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=${CLOUDFLARE_TOKEN:-} \
  -n default --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "🎉 Fresh cluster setup complete!"
echo ""
echo "Next steps:"
echo "1. Port forward ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "2. Get ArgoCD admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "3. Monitor applications: kubectl get applications -A"
echo "4. Access ArgoCD UI: https://localhost:8080"
echo ""