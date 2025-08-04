# Infrastructure Setup Guide

This guide documents the complete setup of a Talos Kubernetes cluster on GCP with persistent storage and GitOps using ArgoCD.

## Prerequisites

- GCP project with billing enabled
- Omni account and context configured
- `gcloud`, `kubectl`, and `omnictl` CLI tools installed
- Domain configured with Cloudflare (for DNS challenges)

## Key Infrastructure Components

### Core Infrastructure
- **Talos Linux**: v1.10.1 (bare-metal Kubernetes distribution)
- **Kubernetes**: v1.32.3
- **ArgoCD**: GitOps continuous delivery
- **GCP**: IPv6 dual-stack networking with compute-rw scopes

### Applications Managed by ArgoCD
1. **cert-manager**: v1.16.1 with ACME Let's Encrypt
2. **nginx-ingress**: v4.12.0 with GCP LoadBalancer
3. **letsencrypt-issuer**: Staging and production issuers with Cloudflare DNS-01
4. **gcp-csi-driver**: Persistent disk storage for GCP
5. **storage-classes**: Standard and SSD storage classes
6. **postgresql**: Database with persistent storage
7. **redis**: In-memory cache with persistence
8. **rabbitmq**: Message queue with persistent storage
9. **minio**: S3-compatible object storage
10. **under-construction**: Demo website

## Critical Setup Requirements

### 1. GCP Instance Scopes
The GCP instance **must** be created with proper OAuth scopes:
```bash
--scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write
```

### 2. IAM Permissions
The default compute service account needs `roles/compute.storageAdmin`:
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:SERVICE_ACCOUNT_EMAIL \
    --role=roles/compute.storageAdmin
```

### 3. Storage Classes
Use `Immediate` volume binding mode to avoid chicken-and-egg scheduling issues:
```yaml
volumeBindingMode: Immediate
```

### 4. Single-Node Cluster
Remove control-plane taint to allow pod scheduling:
```bash
kubectl taint nodes NODE_NAME node-role.kubernetes.io/control-plane:NoSchedule-
```

## Quick Setup

### Option 1: Complete Automated Setup
```bash
./scripts/setup-complete-infrastructure.sh
```

### Option 2: Manual Step-by-Step
```bash
# 1. Create instance with proper scopes
./scripts/create-talos-gcp-instance.sh

# 2. Configure IAM permissions
./scripts/setup-gcp-permissions.sh

# 3. Wait for Omni registration (2-3 minutes)
omnictl get machines --context=default-1

# 4. Update cluster template with machine ID
# Edit cluster-template.yaml

# 5. Create cluster
omnictl cluster template sync --file cluster-template.yaml --context=default-1

# 6. Setup cluster with GitOps
./scripts/setup-fresh-cluster.sh

# 7. Remove control-plane taint
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
```

## Environment Variables (.env)
```bash
GCP_PROJECT_ID=your-project-id
GCP_ZONE=us-central1-a
GCP_MACHINE_TYPE=n2-standard-4
CLUSTER_NAME=talos-ipv6-cluster
OMNI_CONTEXT=default-1
CLOUDFLARE_API_TOKEN=your-cloudflare-token
```

## Networking
- **VPC**: talos-ipv6-vpc with dual-stack IPv4/IPv6
- **Subnet**: talos-ipv6-subnet (10.1.0.0/24, dual-stack)
- **Firewall**: Allows HTTP, HTTPS, SSH, and Kubernetes API

## Storage Architecture
- **CSI Driver**: GCP Compute Persistent Disk v1.15.3
- **Storage Classes**: 
  - `standard` (default): pd-standard disks
  - `standard-rwo`: pd-standard with immediate binding
  - `ssd`: pd-ssd high-performance disks
- **Persistent Volumes**: Automatically provisioned by CSI driver

## Troubleshooting

### Storage Issues
1. **PVCs stuck in Pending**: Check IAM permissions and storage class binding mode
2. **CSI driver fails**: Verify compute scopes and service account roles
3. **Permission denied**: Ensure `roles/compute.storageAdmin` is granted

### Scheduling Issues
1. **Pods stuck in Pending**: Remove control-plane taint
2. **Storage-dependent pods failing**: Check PVC status and CSI driver logs

### ArgoCD Issues
1. **SSH authentication failed**: Use HTTPS repository URLs
2. **Applications not syncing**: Check repository credentials and paths

## Monitoring and Access

### ArgoCD UI
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Application Status
```bash
kubectl get applications -n argocd
kubectl get pods --all-namespaces
kubectl get pvc --all-namespaces
```

### Port Forwarding for Development
```bash
./scripts/port-forward-all.sh
```

## File Structure
```
chorus-deployment/
├── argocd/                          # GitOps applications
│   ├── 01-cert-manager/
│   ├── 02-nginx-ingress/
│   ├── 03-letsencrypt-issuer/
│   ├── 04-under-construction/
│   ├── 05-gcp-csi-driver/
│   ├── 06-storage-classes/
│   ├── 07-postgresql/
│   ├── 08-redis/
│   ├── 09-rabbitmq/
│   └── 10-minio/
├── scripts/                         # Automation scripts
│   ├── create-talos-gcp-instance.sh
│   ├── setup-gcp-permissions.sh
│   ├── setup-complete-infrastructure.sh
│   └── setup-fresh-cluster.sh
├── .env                            # Environment variables
├── cluster-template.yaml          # Omni cluster definition
└── INFRASTRUCTURE-SETUP.md        # This guide
```

## Security Considerations
- Service account uses least-privilege IAM roles
- TLS certificates automatically managed by cert-manager
- Secrets stored in Kubernetes and excluded from git
- Network policies restrict pod-to-pod communication
- Shielded VM features disabled for Talos compatibility