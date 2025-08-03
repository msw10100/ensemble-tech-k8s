# Chorus Deployment - Talos Linux on GCP with IPv6

This project provides infrastructure and automation for deploying single-node Talos Linux Kubernetes clusters on Google Cloud Platform (GCP) with IPv6 support, managed through Siderolabs Omni.

## Overview

This deployment creates a cost-effective, single-node Kubernetes cluster with **IPv6 dual-stack networking** to resolve Sidero Omni connectivity issues. The cluster leverages Talos Linux's security and immutability features while being centrally managed through Omni.

### Key Features

- **IPv6 Support**: Dual-stack networking resolves Omni connectivity issues
- **Secure**: Immutable, API-driven OS with no SSH access
- **Simple**: Single-node design eliminates HA complexity for prototypes
- **Managed**: Centralized control through Omni dashboard
- **Cost-effective**: Minimal infrastructure for development/testing (~$150-200/month)

## Architecture

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────┐
│   Siderolabs    │    │       GCP            │    │    Local Dev    │
│     Omni        │◄──►│ IPv6 Dual-Stack     │◄──►│   Environment   │
│   Management    │    │ Talos + K8s Node    │    │                 │
└─────────────────┘    └──────────────────────┘    └─────────────────┘
                            │                            │
                            │ 2600:1900:4001:8a9::/64   │
                            │ 10.1.0.0/16               │
                            └────────────────────────────┘
```

## Project Structure

```
.
├── README.md                     # This file
├── Makefile                     # Deployment automation
├── scripts/
│   └── cluster-operations.sh    # Cluster management operations
├── talos-config/
│   ├── README.md               # Talos configuration guide
│   ├── omniconfig.yaml         # Omni CLI configuration
│   ├── machine-config.yaml.template  # Template for Omni connection
│   └── gcp-amd64-omni-witson-v1.10.1.raw.tar.gz  # Talos Linux image
├── argocd/                     # Kubernetes manifests for ArgoCD
└── docs/                       # Comprehensive documentation
    ├── deployment-guide.md     # Detailed deployment instructions
    ├── architecture.md         # System architecture
    └── troubleshooting.md      # Common issues and solutions
```

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# kubectl
brew install kubectl

# omnictl (Siderolabs Omni CLI)
curl -Lo omnictl https://github.com/siderolabs/omni/releases/latest/download/omnictl-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64
chmod +x omnictl && sudo mv omnictl /usr/local/bin/
```

### GCP Setup

1. **Authenticate and configure project**:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   gcloud services enable compute.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

### Omni Setup

1. **Access Omni Dashboard**: Navigate to https://witson.omni.siderolabs.io
2. **Configure CLI**: The `omniconfig.yaml` file is already configured for the `witson` context
3. **Verify Access**:
   ```bash
   omnictl get machines --context=default-1
   ```

## Quick Start

### 1. Check Prerequisites
```bash
make prereqs
```

### 2. Deploy IPv6 Infrastructure
```bash
make deploy
```
This creates:
- IPv6-enabled VPC (`talos-ipv6-vpc`) 
- Dual-stack subnet (`talos-ipv6-subnet`)
- Firewall rules for both IPv4 and IPv6
- Talos instance with IPv6 support

### 3. Create Cluster
```bash
# Show cluster creation instructions
make cluster-bootstrap

# Follow the web UI instructions, then download kubeconfig
make kubeconfig
```

### 4. Verify Cluster
```bash
make status
make health
make nodes
```

## Configuration

### Instance Specifications

- **Instance Type**: n2-standard-4 (4 vCPUs, 16GB RAM)
- **Boot Disk**: 250GB standard persistent disk
- **Region**: us-central1
- **Zone**: us-central1-a
- **Network**: IPv6 dual-stack support

### Network Configuration

The deployment creates:
- **VPC**: `talos-ipv6-vpc` (custom mode)
- **Subnet**: `talos-ipv6-subnet` (10.1.0.0/16 + IPv6)
- **IPv6 Range**: `2600:1900:4001:8a9:0:0:0:0/64`
- **Firewall Rules**:
  - Port 6443: Kubernetes API Server (IPv4/IPv6)
  - Port 50000: Talos API (IPv4/IPv6)
  - Internal traffic: Full access within VPC

## Management Commands

### Infrastructure Operations
```bash
make deploy              # Full deployment workflow
make create-network      # Create IPv6 VPC and subnet
make create-firewall     # Set up firewall rules
make create-instance     # Create Talos instance
make teardown           # Destroy all infrastructure
```

### Cluster Operations
```bash
make status             # Show overall cluster status
make health             # Check cluster health
make nodes              # Show Kubernetes nodes
make pods               # Show all pods
make omni-machines      # List machines in Omni
make omni-clusters      # List clusters in Omni
```

### Application Management
```bash
make argocd-install     # Install ArgoCD
make argocd-port-forward # Access ArgoCD UI
```

## IPv6 Benefits

This deployment resolves common Sidero Omni connectivity issues by providing:

1. **Dual-stack networking**: Both IPv4 and IPv6 connectivity
2. **Direct IPv6 communication**: Bypasses IPv4 NAT limitations
3. **Improved Omni connectivity**: Reliable connection to Sidero services
4. **Future-proof networking**: Native IPv6 support for modern applications

## Cluster Information

- **Cluster Name**: `talos-ipv6-cluster`
- **Node Name**: `apollo-gcp-ipv6`
- **Kubernetes Version**: v1.32.3
- **Talos Version**: v1.10.1
- **CNI**: Flannel
- **Kubeconfig**: `~/.kube/config-talos-ipv6`

## Troubleshooting

### Quick Diagnostics
```bash
make info               # Show deployment information
make status             # Check cluster status
./scripts/cluster-operations.sh health  # Detailed health check
```

### IPv6 Connectivity Issues
```bash
# Check IPv6 address assignment
gcloud compute instances describe apollo-gcp-ipv6 --zone=us-central1-a \
  --format="value(networkInterfaces[0].ipv6Address)"

# Verify subnet configuration
gcloud compute networks subnets describe talos-ipv6-subnet \
  --region=us-central1 --format="value(stackType,externalIpv6Prefix)"
```

See `docs/troubleshooting.md` for comprehensive troubleshooting guides.

## Cost Management

### Monthly Estimates
- **Compute**: n2-standard-4 (~$97/month)
- **Storage**: 250GB standard disk (~$25/month)  
- **Network**: External IP + egress (~$10-30/month)
- **Total**: ~$132-152/month

### Optimization Tips
- Monitor usage with `make info`
- Use `make teardown` when not needed
- Consider smaller instance types for development

## Security

### Network Security
- Custom VPC with controlled access
- Firewall rules restricted to necessary ports
- IPv6 provides additional security through address space complexity

### Access Control
- No SSH access (API-only management)
- All communication encrypted
- Omni-managed certificates and secrets

## Support and Documentation

- **Deployment Guide**: `docs/deployment-guide.md`
- **Architecture**: `docs/architecture.md`
- **Troubleshooting**: `docs/troubleshooting.md`
- **Talos Linux**: https://www.talos.dev/docs/
- **Siderolabs Omni**: https://omni.siderolabs.com/docs/

## License

This project is licensed under the MIT License - see the LICENSE file for details.