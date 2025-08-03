# Deployment Guide

This guide provides step-by-step instructions for deploying a Talos Linux single-node cluster on GCP.

## Pre-Deployment Checklist

### Prerequisites

- [ ] Google Cloud SDK installed and configured
- [ ] omnictl CLI installed and authenticated
- [ ] kubectl installed
- [ ] GCP project created with billing enabled
- [ ] Siderolabs Omni account set up
- [ ] Talos image file available locally

### Access Verification

```bash
# Check all prerequisites
make prereqs

# Or check individually:
make check-deps
make gcp-auth
make omni-auth
```

### Important Notes

- This deployment creates an **IPv6-enabled dual-stack network** to resolve Sidero Omni connectivity issues
- The deployment uses **manual cluster creation** via Omni web interface (not Terraform)
- All resources are created in the `us-central1` region with IPv6 support

## Deployment Methods

### Quick Deployment (Recommended)

Uses the Makefile for a streamlined deployment:

```bash
# Full deployment workflow
make deploy
```

This command will:
1. Check prerequisites
2. Create IPv6-enabled VPC and subnet
3. Configure firewall rules for dual-stack networking
4. Create Talos instance with IPv6 support
5. Provide next steps for cluster creation

### Manual Step-by-Step Deployment

For more control over the deployment process:

```bash
# Create IPv6 network infrastructure
make create-network

# Set up firewall rules
make create-firewall

# Create Talos instance
make create-instance

# Check machine registration
make omni-machines
```

## Step-by-Step Deployment

### Step 1: Environment Setup

1. **Clone and navigate to the project:**
   ```bash
   cd /Users/michaelwatson/code/chorus-deployment
   ```

2. **Verify project structure:**
   ```bash
   make info
   ```

3. **Check prerequisites:**
   ```bash
   make prereqs
   ```

### Step 2: Prepare Talos Image

1. **Ensure Talos image is available:**
   ```bash
   ls -la talos-config/gcp-amd64-omni-witson-v1.10.1.raw.tar.gz
   ```

2. **Create storage bucket (if needed):**
   ```bash
   gsutil mb gs://$(gcloud config get-value project)-talos-images
   ```

### Step 3: Deploy IPv6 Infrastructure

1. **Start deployment:**
   ```bash
   make deploy
   ```

2. **Monitor deployment progress:**
   - Watch gcloud output for any errors
   - Network creation is typically instant
   - Instance creation takes 2-3 minutes

3. **Verify deployment:**
   ```bash
   make info
   ```

### Step 4: Wait for Machine Registration

1. **Monitor machine registration:**
   ```bash
   # Check machine status in Omni
   make omni-machines
   ```

2. **Expected output:**
   ```
   NAMESPACE   TYPE      ID           VERSION   ADDRESS                   CONNECTED   REBOOTS
   default     Machine   xxxx-xxxx    X         fdae:41e4:649b:9303:...   true        
   ```

3. **Verify IPv6 connectivity:**
   ```bash
   # Check instance details
   gcloud compute instances describe apollo-gcp-ipv6 --zone=us-central1-a \
     --format="value(name,status,networkInterfaces[0].networkIP,networkInterfaces[0].ipv6Address)"
   ```

### Step 5: Create Kubernetes Cluster

1. **Create cluster via Omni web interface:**
   ```bash
   make cluster-bootstrap
   ```
   
   This will show you the steps:
   - Go to https://witson.omni.siderolabs.io
   - Navigate to Clusters → Create Cluster
   - Name: `talos-ipv6-cluster`
   - Select your registered machine (with IPv6 address)
   - Configure as single-node (control plane + allow workloads)

2. **Wait for cluster bootstrap:**
   - Monitor cluster creation in Omni dashboard
   - Bootstrap typically takes 5-10 minutes
   - The node will show as "Ready" when complete

### Step 6: Configure kubectl Access

1. **Download kubeconfig:**
   ```bash
   make kubeconfig
   ```

2. **Verify cluster access:**
   ```bash
   make nodes
   ```

3. **Expected output:**
   ```
   NAME              STATUS   ROLES           AGE     VERSION
   apollo-gcp-ipv6   Ready    control-plane   5m      v1.32.3
   ```

   Note: The node has no taints, so it can run regular workloads.

### Step 7: Verify Cluster Health

1. **Check overall cluster status:**
   ```bash
   make status
   ```

2. **Check cluster health:**
   ```bash
   make health
   ```

3. **View system pods:**
   ```bash
   make pods
   ```

4. **Verify IPv6 functionality:**
   ```bash
   # Check if pods can reach external IPv6 addresses
   kubectl run test-ipv6 --image=busybox --rm -it --restart=Never \
     --kubeconfig=$HOME/.kube/config-talos-ipv6 \
     -- nslookup google.com
   ```

## Post-Deployment Configuration

### Install ArgoCD (Optional)

1. **Deploy ArgoCD:**
   ```bash
   make argocd-install
   ```

2. **Wait for pods to be ready:**
   ```bash
   kubectl get pods -n argocd --kubeconfig ~/.kube/config-talos-ipv6
   ```

3. **Access ArgoCD UI:**
   ```bash
   make argocd-port-forward
   # Access at https://localhost:8080
   ```

### Set Up Monitoring (Optional)

1. **Deploy basic monitoring:**
   ```bash
   # Example monitoring stack deployment
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/kube-state-metrics/master/examples/standard/cluster-role.yaml --kubeconfig ~/.kube/config-talos-ipv6
   ```

## Validation Tests

### Infrastructure Tests

```bash
# Test GCP instance accessibility
EXTERNAL_IP=$(gcloud compute instances describe apollo-gcp-ipv6 --zone=us-central1-a --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
nc -zv $EXTERNAL_IP 6443
nc -zv $EXTERNAL_IP 50000

# Test Omni connectivity
make omni-machines

# Test IPv6 connectivity
gcloud compute instances describe apollo-gcp-ipv6 --zone=us-central1-a \
  --format="value(networkInterfaces[0].ipv6Address)"
```

### Kubernetes Tests

```bash
# Test basic Kubernetes functionality
kubectl create deployment nginx --image=nginx --kubeconfig ~/.kube/config-talos-ipv6
kubectl expose deployment nginx --port=80 --kubeconfig ~/.kube/config-talos-ipv6
kubectl get pods --kubeconfig ~/.kube/config-talos-ipv6

# Clean up test
kubectl delete deployment nginx --kubeconfig ~/.kube/config-talos-ipv6
kubectl delete service nginx --kubeconfig ~/.kube/config-talos-ipv6
```

### Application Deployment Test

```bash
# Test application deployment
cat << EOF | kubectl apply -f - --kubeconfig ~/.kube/config-talos-ipv6
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world-service
spec:
  selector:
    app: hello-world
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
EOF

# Check deployment
kubectl get pods -l app=hello-world --kubeconfig ~/.kube/config-talos-ipv6
kubectl get svc hello-world-service --kubeconfig ~/.kube/config-talos-ipv6

# Test service connectivity
kubectl port-forward service/hello-world-service 8080:80 --kubeconfig ~/.kube/config-talos-ipv6 &
curl http://localhost:8080
kill %1  # Stop port-forward

# Clean up
kubectl delete deployment hello-world --kubeconfig ~/.kube/config-talos-ipv6
kubectl delete service hello-world-service --kubeconfig ~/.kube/config-talos-ipv6
```

## Deployment Variations

### Development Environment

For development with cost optimization:

```bash
# Use preemptible instance
echo 'enable_preemptible = true' >> terraform/terraform.tfvars
make deploy
```

### Production Environment

For production with enhanced security:

```bash
# Modify Makefile configuration or use custom commands
export MACHINE_TYPE="n2-standard-8"
export BOOT_DISK_SIZE="500GB"
export BOOT_DISK_TYPE="pd-ssd"

# Create production instance with larger specs
gcloud compute instances create apollo-gcp-ipv6-prod \
  --zone=us-central1-a \
  --machine-type=$MACHINE_TYPE \
  --network=talos-ipv6-vpc \
  --subnet=talos-ipv6-subnet \
  --image=talos-v1101-omni-ipv6 \
  --boot-disk-size=$BOOT_DISK_SIZE \
  --boot-disk-type=$BOOT_DISK_TYPE \
  --tags=talos-node \
  --stack-type=IPV4_IPV6 \
  --ipv6-network-tier=PREMIUM
```

### Multi-Region Deployment

To deploy in a different region:

```bash
# Create network in different region
export REGION="us-west1"
export ZONE="us-west1-a"

gcloud compute networks subnets create talos-ipv6-subnet-west \
  --network=talos-ipv6-vpc \
  --region=$REGION \
  --range=10.2.0.0/16 \
  --stack-type=IPV4_IPV6 \
  --ipv6-access-type=EXTERNAL

# Create instance in new region
gcloud compute instances create apollo-gcp-ipv6-west \
  --zone=$ZONE \
  --machine-type=n2-standard-4 \
  --network=talos-ipv6-vpc \
  --subnet=talos-ipv6-subnet-west \
  --image=talos-v1101-omni-ipv6 \
  --boot-disk-size=250GB \
  --boot-disk-type=pd-standard \
  --tags=talos-node \
  --stack-type=IPV4_IPV6 \
  --ipv6-network-tier=PREMIUM
```

## Network Configuration

### IPv6 Support for Sidero Omni Connectivity

If you experience connectivity issues between your GCP nodes and Sidero Omni (especially IPv6-related), you may need to enable IPv6 support:

#### Create IPv6-Enabled Network

The default GCP network only supports IPv4. To enable IPv6:

```bash
# Create custom VPC with IPv6 support
gcloud compute networks create talos-ipv6-vpc --subnet-mode=custom

# Create IPv6-enabled subnet
gcloud compute networks subnets create talos-ipv6-subnet \
  --network=talos-ipv6-vpc \
  --region=us-central1 \
  --range=10.1.0.0/16 \
  --stack-type=IPV4_IPV6 \
  --ipv6-access-type=EXTERNAL

# Create necessary firewall rules
gcloud compute firewall-rules create talos-ipv6-internal \
  --network talos-ipv6-vpc \
  --allow tcp,udp,icmp \
  --source-ranges 10.1.0.0/16

gcloud compute firewall-rules create talos-ipv6-api \
  --network talos-ipv6-vpc \
  --allow tcp:50000 \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules create talos-ipv6-k8s \
  --network talos-ipv6-vpc \
  --allow tcp:6443 \
  --source-ranges 0.0.0.0/0
```

#### Using IPv6 Network in Deployment

To deploy on the IPv6-enabled network, update your Terraform variables:

```bash
# Add to terraform/terraform.tfvars
network = "talos-ipv6-vpc"
subnet = "talos-ipv6-subnet"
```

#### Verify IPv6 Configuration

```bash
# Check subnet stack type
gcloud compute networks subnets describe talos-ipv6-subnet \
  --region=us-central1 \
  --format="value(stackType,externalIpv6Prefix)"

# Check instance IPv6 assignment
gcloud compute instances describe apollo-gcp-1 \
  --zone=us-central1-a \
  --format="value(networkInterfaces[0].ipv6Address)"
```

## Troubleshooting Deployment Issues

### Common Issues During Deployment

1. **Terraform authentication errors:**
   ```bash
   gcloud auth application-default login
   make gcp-auth
   ```

2. **GCP API not enabled:**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

3. **Quota exceeded:**
   ```bash
   gcloud compute project-info describe --project=$(gcloud config get-value project)
   # Check quotas and request increases if needed
   ```

4. **Image upload failures:**
   ```bash
   # Check Talos image file exists
   ls -la talos-config/gcp-amd64-omni-witson-v1.10.1.raw.tar.gz
   
   # Check storage permissions
   gsutil ls
   ```

5. **Sidero Omni connectivity issues:**
   ```bash
   # Check if network supports IPv6
   gcloud compute networks subnets list --filter="name~default" \
     --format="table(name,region,stackType)"
   
   # If IPv4_ONLY, consider using IPv6-enabled network (see Network Configuration section)
   ```

### Verification Commands

```bash
# Check deployment status
make tf-output
make instance-info
make omni-machines
make status

# Get detailed information
make info
```

## Next Steps

After successful deployment:

1. **Review the README.md** for ongoing management
2. **Check the troubleshooting guide** for common issues
3. **Explore the Makefile** for available commands
4. **Set up monitoring and alerting** as needed
5. **Configure backup procedures** for important data
6. **Review security settings** and harden as required

## Cleanup

To completely remove the deployment:

```bash
# Full teardown
make teardown
```

This will remove all GCP resources including:
- Compute instances
- Talos images  
- Firewall rules
- IPv6-enabled subnets
- Custom VPC network