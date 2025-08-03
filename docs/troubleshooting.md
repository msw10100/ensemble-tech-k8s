# Troubleshooting Guide

This guide covers common issues and solutions for the Talos Linux GCP deployment.

## Common Issues

### 1. Machine Not Appearing in Omni

**Symptoms:**
- Instance is running in GCP but not visible in Omni dashboard
- No machine registration events

**Possible Causes:**
- Incorrect join token in machine-config.yaml
- Network connectivity issues (firewall rules)
- Instance boot problems

**Solutions:**

1. **Check join token:**
   ```bash
   # Verify the join token in machine-config.yaml matches Omni
   cat talos-config/machine-config.yaml | grep jointoken
   ```

2. **Verify firewall rules:**
   ```bash
   gcloud compute firewall-rules list --filter="name:omni*"
   # Should show rule allowing UDP port 51821
   ```

3. **Check instance startup:**
   ```bash
   # Get instance startup logs
   make instance-logs
   # or
   gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE
   ```

4. **Verify network connectivity:**
   ```bash
   # Test from your local machine
   nc -zv witson.siderolink.omni.siderolabs.io 443
   ```

### 2. Cluster Bootstrap Fails

**Symptoms:**
- Machine is registered but cluster creation fails
- Kubernetes API not responding

**Possible Causes:**
- Insufficient resources
- Network configuration issues
- Certificate problems

**Solutions:**

1. **Check machine resources:**
   ```bash
   omnictl get machine MACHINE_ID --context=default -o yaml
   # Verify machine has enough CPU/RAM
   ```

2. **Verify external IP configuration:**
   ```bash
   # Check that controlplane.yaml has correct external IP
   grep -A 5 -B 5 "35.224.5.144" talos-config/controlplane.yaml
   ```

3. **Check cluster events:**
   ```bash
   omnictl get cluster talos-single-node --context=default -o yaml
   ```

### 3. Kubernetes API Not Accessible

**Symptoms:**
- kubectl commands fail with connection refused
- Cluster appears healthy in Omni

**Possible Causes:**
- Firewall blocking port 6443
- Certificate issues
- Wrong endpoint configuration

**Solutions:**

1. **Verify firewall rules:**
   ```bash
   gcloud compute firewall-rules describe k8s-api
   # Should allow TCP port 6443
   ```

2. **Test connectivity:**
   ```bash
   # From your local machine
   EXTERNAL_IP=$(cd terraform && terraform output -raw external_ip)
   nc -zv $EXTERNAL_IP 6443
   ```

3. **Check certificate SANs:**
   ```bash
   # Verify external IP is in certificate SANs
   grep -A 2 certSANs talos-config/controlplane.yaml
   ```

4. **Get fresh kubeconfig:**
   ```bash
   make kubeconfig
   kubectl cluster-info --kubeconfig ~/.kube/config-talos
   ```

### 4. Pod Scheduling Issues

**Symptoms:**
- Pods stuck in Pending state
- Scheduling errors in events

**Possible Causes:**
- Node taints preventing scheduling
- Resource constraints
- Node not ready

**Solutions:**

1. **Check node status:**
   ```bash
   kubectl get nodes -o wide --kubeconfig ~/.kube/config-talos
   kubectl describe nodes --kubeconfig ~/.kube/config-talos
   ```

2. **Check node taints:**
   ```bash
   kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints --kubeconfig ~/.kube/config-talos
   ```

3. **Check resource usage:**
   ```bash
   kubectl top nodes --kubeconfig ~/.kube/config-talos
   kubectl describe node --kubeconfig ~/.kube/config-talos
   ```

### 5. Terraform Deployment Issues

**Symptoms:**
- Terraform apply fails
- Resources not created properly

**Common Solutions:**

1. **Check GCP authentication:**
   ```bash
   make gcp-auth
   gcloud auth application-default login
   ```

2. **Verify project permissions:**
   ```bash
   gcloud projects get-iam-policy $(gcloud config get-value project)
   ```

3. **Check quota limits:**
   ```bash
   gcloud compute project-info describe --project=$(gcloud config get-value project)
   ```

4. **Enable required APIs:**
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

### 6. Image Upload Issues

**Symptoms:**
- Terraform fails creating compute image
- Storage bucket access denied

**Solutions:**

1. **Check Talos image file:**
   ```bash
   ls -la talos-config/gcp-amd64-omni-witson-v1.10.1.raw.tar.gz
   # File should be ~238MB
   ```

2. **Verify storage permissions:**
   ```bash
   gsutil ls  # Should not error
   ```

3. **Check bucket creation:**
   ```bash
   # Bucket names must be globally unique
   cd terraform && terraform plan
   ```

## Debugging Commands

### GCP Instance Debugging

```bash
# Instance information
gcloud compute instances describe INSTANCE_NAME --zone=ZONE

# Instance logs
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE

# Instance metadata
gcloud compute instances describe INSTANCE_NAME --zone=ZONE --format="value(metadata.items[].value)"

# Network connectivity test
gcloud compute instances add-metadata INSTANCE_NAME --zone=ZONE --metadata=enable-oslogin=TRUE
```

### Omni Debugging

```bash
# List all machines
omnictl get machines --context=default

# Machine details
omnictl get machine MACHINE_ID --context=default -o yaml

# Cluster status
omnictl get clusters --context=default

# Cluster events
omnictl get cluster talos-single-node --context=default -o yaml
```

### Kubernetes Debugging

```bash
# Cluster information
kubectl cluster-info --kubeconfig ~/.kube/config-talos

# Node events
kubectl get events --sort-by=.metadata.creationTimestamp --kubeconfig ~/.kube/config-talos

# System pods
kubectl get pods -n kube-system --kubeconfig ~/.kube/config-talos

# Pod logs
kubectl logs -n kube-system POD_NAME --kubeconfig ~/.kube/config-talos
```

### Network Debugging

```bash
# Test external connectivity
curl -k https://EXTERNAL_IP:6443/version

# Check DNS resolution
nslookup witson.omni.siderolabs.io

# Firewall rules
gcloud compute firewall-rules list --filter="targetTags:talos-node"

# Routes
gcloud compute routes list
```

## Recovery Procedures

### Complete Cluster Reset

If the cluster is completely broken:

1. **Destroy infrastructure:**
   ```bash
   make destroy
   ```

2. **Clean up Omni:**
   - Remove cluster from Omni dashboard
   - Remove machine registration

3. **Redeploy:**
   ```bash
   make deploy
   ```

### Machine Replacement

If the machine is corrupted but cluster config is good:

1. **Stop the instance:**
   ```bash
   gcloud compute instances stop INSTANCE_NAME --zone=ZONE
   ```

2. **Recreate with Terraform:**
   ```bash
   cd terraform
   terraform taint google_compute_instance.talos_node
   terraform apply
   ```

### Configuration Recovery

If configuration files are lost:

1. **Machine config:** Get new join token from Omni
2. **Control plane config:** Download from Omni cluster
3. **Kubeconfig:** Re-download from Omni

## Performance Optimization

### Instance Sizing

```bash
# Check resource usage
kubectl top nodes --kubeconfig ~/.kube/config-talos
kubectl top pods --all-namespaces --kubeconfig ~/.kube/config-talos

# Consider upgrading if:
# - CPU usage consistently > 80%
# - Memory usage > 85%
# - Disk I/O is saturated
```

### Network Performance

```bash
# Check network utilization
gcloud compute instances describe INSTANCE_NAME --zone=ZONE --format="get(networkInterfaces[0].networkIP)"

# Consider regional persistent disks for better performance
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Node health:**
   - CPU, memory, disk usage
   - Node ready status
   - Kubelet health

2. **Cluster health:**
   - API server response time
   - etcd health
   - Pod scheduling success rate

3. **Network health:**
   - Omni connectivity
   - External API accessibility
   - DNS resolution

### Setting Up Monitoring

```bash
# Basic monitoring with kubectl
watch kubectl get nodes --kubeconfig ~/.kube/config-talos

# More advanced monitoring would require:
# - Prometheus + Grafana
# - GCP monitoring integration
# - Custom alerting rules
```

## Getting Help

### Community Resources

- **Talos Linux**: https://www.talos.dev/docs/
- **Siderolabs Omni**: https://omni.siderolabs.com/docs/
- **Google Cloud**: https://cloud.google.com/docs/

### Support Channels

- **GitHub Issues**: Create issues in this repository
- **Talos Slack**: Join the Talos community Slack
- **GCP Support**: Use Google Cloud support if needed

### Logging Information for Support

When requesting help, include:

1. **Error messages** (exact text)
2. **Steps to reproduce** the issue
3. **Environment information**:
   ```bash
   gcloud version
   terraform version
   omnictl version
   kubectl version --client
   ```
4. **Configuration** (sanitized, no secrets)
5. **Logs** (relevant portions only)