# Talos Configuration Files

This directory contains configuration files for Talos Linux deployment and Omni management.

## File Descriptions

### Core Configuration Files

- **`machine-config.yaml`** - Omni connection configuration for machine registration
  - Contains SideroLink configuration
  - Event sink and kmsg log configuration
  - Required for machine to connect to Omni

- **`controlplane.yaml`** - Cluster control plane configuration
  - Machine and cluster configuration
  - Contains generated certificates and tokens
  - Single-node control plane + worker setup

- **`talosconfig.yaml`** - Talos CLI configuration
  - Endpoint and authentication configuration
  - Used by `talosctl` for API access

- **`omniconfig.yaml`** - Omni CLI configuration
  - Omni dashboard endpoint and authentication
  - Used by `omnictl` for cluster management

### Additional Files

- **`gcp-amd64-omni-witson-v1.10.1.raw.tar.gz`** - Talos Linux image for GCP
  - Pre-built image with Omni support
  - Used for creating GCP compute image

- **`talos-gcp-deployment-prd.md`** - Product Requirements Document
  - Detailed specifications and requirements
  - Architecture and deployment guidelines

## Security Considerations

### Files in Version Control
These files are included in version control:
- `machine-config.yaml` - Contains join tokens (rotatable)
- `controlplane.yaml` - Contains generated certificates and keys
- `talosconfig.yaml` - Contains endpoint configuration only
- `omniconfig.yaml` - Contains endpoint configuration only

### Files Excluded from Version Control
The following patterns are excluded via `.gitignore`:
- `*.kubeconfig` - Kubernetes access credentials
- `talosconfig` (without extension) - CLI configurations with auth
- `*.secret`, `*secret*`, `*token*` - Any secret files
- `*.key`, `*.pem`, `*.crt` - Certificate files

## Configuration Templates

### Creating a New Machine Configuration

1. **Copy the machine-config template**:
   ```bash
   cp machine-config.yaml.template machine-config.yaml
   ```

2. **Update the join token**:
   - Get a new join token from Omni dashboard
   - Replace the token in the SideroLinkConfig section

3. **Verify configuration**:
   ```bash
   omnictl validate machine-config.yaml
   ```

### Creating a New Control Plane Configuration

1. **Use Omni to generate configuration**:
   - Create cluster in Omni dashboard
   - Download the generated control plane configuration
   - Save as `controlplane.yaml`

2. **Update external IP address**:
   - Replace the IP address in `certSANs` and `endpoint`
   - Use the static IP from your GCP deployment

## Usage

### Machine Registration
```bash
# Machine will automatically use machine-config.yaml on boot
# Check registration in Omni dashboard
omnictl get machines --context=default
```

### Cluster Management
```bash
# Create cluster using controlplane.yaml
omnictl cluster create talos-single-node --context=default

# Get kubeconfig
omnictl kubeconfig talos-single-node --context=default > ~/.kube/config-talos

# Check cluster status
kubectl get nodes --kubeconfig ~/.kube/config-talos
```

### Direct Talos API Access
```bash
# Use talosconfig.yaml for direct Talos API access
talosctl --talosconfig talosconfig.yaml health

# Get system information
talosctl --talosconfig talosconfig.yaml version
```

## Troubleshooting

### Machine Not Appearing in Omni
1. Check firewall rules (port 51821 for WireGuard)
2. Verify join token is correct
3. Check instance startup logs:
   ```bash
   gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE
   ```

### Cluster Bootstrap Issues
1. Verify machine is registered in Omni
2. Check that machine has enough resources
3. Ensure external IP is correctly configured in controlplane.yaml

### Network Connectivity Issues
1. Verify firewall rules:
   - Port 6443: Kubernetes API
   - Port 50000: Talos API
   - Port 51821: Omni WireGuard
2. Check GCP network configuration
3. Verify static IP assignment

## Best Practices

### Security
- Rotate join tokens regularly
- Keep certificates and keys secure
- Use least-privilege access policies
- Monitor access logs in Omni

### Configuration Management
- Keep templates for easy regeneration
- Document any customizations
- Test configurations in development first
- Use version control for templates and documentation

### Backup
Important files to backup:
- `machine-config.yaml` - For machine recreation
- `controlplane.yaml` - For cluster recreation
- Generated kubeconfig files
- Omni cluster definitions

## Integration with Deployment

These configurations are used by:
- **Terraform**: References the Talos image file
- **Deployment scripts**: Uses configuration files for verification
- **Makefile**: Provides commands for configuration management
- **GCP instance**: Metadata includes configuration references