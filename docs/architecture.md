# Architecture Overview

This document describes the architecture and design decisions for the Talos Linux single-node Kubernetes cluster deployment on GCP.

## High-Level Architecture

```
┌─────────────────────────────────────┐
│            Internet                 │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         Google Cloud                │
│  ┌─────────────────────────────────┐ │
│  │      VPC Network (default)      │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │    Subnet (us-central1)     │ │ │
│  │  │  ┌─────────────────────────┐ │ │ │
│  │  │  │    Talos Linux Node     │ │ │ │
│  │  │  │   ┌─────────────────┐   │ │ │ │
│  │  │  │   │   Kubernetes    │   │ │ │ │
│  │  │  │   │  Control Plane  │   │ │ │ │
│  │  │  │   │   + Worker      │   │ │ │ │
│  │  │  │   └─────────────────┘   │ │ │ │
│  │  │  └─────────────────────────┘ │ │ │
│  │  └─────────────────────────────┐ │ │
│  └─────────────────────────────────┘ │
└─────────────────────────────────────┘
              │
┌─────────────▼───────────────────────┐
│     Siderolabs Omni (SaaS)          │
│   - Cluster Management              │
│   - Node Registration               │
│   - Configuration Distribution      │
│   - Monitoring & Updates            │
└─────────────────────────────────────┘
```

## Component Architecture

### Compute Infrastructure

#### Talos Linux Node
- **Instance Type**: n2-standard-4 (4 vCPUs, 16GB RAM)
- **Operating System**: Talos Linux v1.10.1
- **Role**: Combined control plane and worker node
- **Boot Disk**: 250GB SSD (pd-ssd) for optimal performance
- **Network**: Single network interface with external IP

#### Key Characteristics
- **Immutable OS**: No package manager, SSH, or shell access
- **API-driven**: All management through Talos API
- **Container-optimized**: Minimal attack surface
- **Secure by default**: Built-in security hardening

### Network Architecture

#### External Connectivity
```
Internet → Load Balancer → Static IP → Talos Node
```

#### Port Configuration
| Port  | Protocol | Service           | Source            |
|-------|----------|-------------------|-------------------|
| 6443  | TCP      | Kubernetes API    | 0.0.0.0/0         |
| 50000 | TCP      | Talos API         | 0.0.0.0/0         |
| 51821 | UDP      | Omni WireGuard    | 0.0.0.0/0         |
| 6443  | TCP      | Health Checks     | GCP Health Check  |

#### Firewall Rules
- **k8s-api**: Allows Kubernetes API access (port 6443)
- **talos-api**: Allows Talos API access (port 50000) 
- **omni-wireguard**: Allows Omni connection (port 51821)
- **talos-health-check**: Allows GCP health checks

#### Network Security
- Static external IP for consistent access
- Minimal firewall rules (principle of least privilege)
- Encrypted communication for all services
- No SSH access (API-only management)

### Storage Architecture

#### Boot Disk
- **Type**: pd-ssd (SSD for better I/O performance)
- **Size**: 250GB (adequate for OS, container images, and data)
- **Encryption**: Encrypted at rest by default (GCP)
- **Backup**: Can be snapshotted for disaster recovery

#### Container Storage
- **Container Runtime**: containerd
- **Image Storage**: Local SSD storage
- **Temporary Storage**: tmpfs for ephemeral data
- **Persistent Volumes**: Can use GCP Persistent Disks

### Kubernetes Architecture

#### Single-Node Configuration
```
┌─────────────────────────────────────┐
│           Talos Linux Node          │
│                                     │
│  ┌─────────────────────────────────┐ │
│  │      Control Plane              │ │
│  │  - kube-apiserver               │ │
│  │  - kube-controller-manager      │ │
│  │  - kube-scheduler               │ │
│  │  - etcd                         │ │
│  └─────────────────────────────────┘ │
│                                     │
│  ┌─────────────────────────────────┐ │
│  │      Worker Components          │ │
│  │  - kubelet                      │ │
│  │  - kube-proxy                   │ │
│  │  - containerd                   │ │
│  └─────────────────────────────────┘ │
│                                     │
│  ┌─────────────────────────────────┐ │
│  │      Application Pods           │ │
│  │  - User workloads               │ │
│  │  - System components            │ │
│  │  - Monitoring (optional)        │ │
│  └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

#### No Taints Configuration
- Control plane node accepts workload pods
- Suitable for development and small production workloads
- Maximizes resource utilization on single node

### Management Architecture

#### Omni Integration
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Local CLI     │    │  Omni Platform  │    │  Talos Node     │
│                 │    │                 │    │                 │
│  - omnictl      │◄──►│  - Dashboard    │◄──►│  - Machine      │
│  - kubectl      │    │  - API          │    │  - Cluster      │
│  - talosctl     │    │  - Auth         │    │  - Workloads    │
│                 │    │  - Updates      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Management Flows
1. **Machine Registration**: Node connects to Omni via WireGuard
2. **Cluster Creation**: Omni provisions Kubernetes cluster
3. **Configuration**: Omni distributes and manages configurations
4. **Updates**: Omni orchestrates OS and Kubernetes updates
5. **Monitoring**: Omni provides cluster health and metrics

## Security Architecture

### Multi-Layer Security

#### Operating System Level
- **Immutable root filesystem**: Prevents tampering
- **No package manager**: Eliminates package-based attacks
- **No SSH**: Removes remote access attack vectors
- **Minimal attack surface**: Only essential services running

#### Network Level
- **Encrypted communications**: All traffic encrypted in transit
- **Firewall rules**: Minimal open ports
- **Static IP**: Predictable network access
- **VPC isolation**: Network-level isolation in GCP

#### Kubernetes Level
- **RBAC enabled**: Role-based access control
- **Pod Security Standards**: Baseline enforcement
- **Network policies**: Can be implemented for pod-to-pod security
- **Secrets management**: Kubernetes-native secret handling

#### GCP Level
- **IAM integration**: Service account with minimal permissions
- **Disk encryption**: Encrypted storage at rest
- **Audit logging**: GCP audit trails
- **Shielded VMs**: Integrity monitoring and vTPM

### Certificate Management
- **Automatic rotation**: Handled by Talos/Kubernetes
- **External IP in SANs**: Certificates include external IP
- **CA management**: Omni manages certificate authorities
- **Secure distribution**: Certificates distributed via Omni API

## Scalability Considerations

### Current Limitations
- **Single node**: No high availability
- **Resource constraints**: Limited by single instance resources
- **Network bottleneck**: Single network interface

### Scaling Options
1. **Vertical scaling**: Increase instance size (more CPU/RAM)
2. **Storage scaling**: Increase disk size as needed
3. **Multi-node migration**: Expand to multi-node cluster
4. **Regional deployment**: Deploy multiple clusters in different regions

### Performance Characteristics
- **Boot time**: ~2-3 minutes for full cluster readiness
- **API latency**: <100ms for local API calls
- **Disk I/O**: High performance with SSD storage
- **Network throughput**: Limited by instance network tier

## Disaster Recovery Architecture

### Backup Strategy
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Configuration  │    │   Cluster Data  │    │  Application    │
│    Backups      │    │    Backups      │    │    Backups      │
│                 │    │                 │    │                 │
│ - machine-config│    │ - etcd snapshots│    │ - PV snapshots  │
│ - controlplane  │    │ - secrets       │    │ - app configs   │
│ - certificates  │    │ - configmaps    │    │ - databases     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Recovery Procedures
1. **Node replacement**: Recreate with same configuration
2. **Cluster rebuild**: Bootstrap new cluster from backups
3. **Data restoration**: Restore persistent volumes from snapshots
4. **Configuration restoration**: Reapply configurations from version control

## Monitoring and Observability

### Built-in Monitoring
- **Omni dashboard**: Cluster health and metrics
- **GCP monitoring**: Instance and network metrics
- **Kubernetes metrics**: Built-in cluster metrics

### Optional Monitoring Stack
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Prometheus    │◄──►│    Grafana      │◄──►│   AlertManager  │
│                 │    │                 │    │                 │
│ - Metrics       │    │ - Visualization │    │ - Notifications │
│ - Time series   │    │ - Dashboards    │    │ - Routing       │
│ - Alerts        │    │ - Analysis      │    │ - Escalation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Cost Optimization

### Current Cost Structure
- **Compute**: ~$97/month (n2-standard-4)
- **Storage**: ~$42/month (250GB SSD)
- **Network**: ~$10-50/month (IP + egress)
- **Total**: ~$150-200/month

### Optimization Strategies
1. **Preemptible instances**: 60-80% cost reduction (dev environments)
2. **Right-sizing**: Monitor usage and adjust instance type
3. **Storage optimization**: Use balanced disks instead of SSD if I/O requirements allow
4. **Scheduled shutdown**: Auto-stop for development environments

## Design Principles

### Simplicity
- Single-node design eliminates complexity
- Minimal external dependencies
- Straightforward deployment process

### Security
- Immutable infrastructure
- Principle of least privilege
- Defense in depth

### Reliability
- Automated deployment and recovery
- Infrastructure as code
- Comprehensive monitoring

### Cost-Effectiveness
- Right-sized for development/prototype workloads
- Minimal infrastructure overhead
- Clear cost optimization paths

## Future Architecture Evolution

### Short-term Enhancements
- Terraform state management (remote backend)
- Enhanced monitoring stack
- Automated backup procedures
- Cost optimization automation

### Long-term Evolution
- Multi-node cluster support
- Multiple environment management
- Advanced networking (service mesh)
- GitOps integration
- Advanced security hardening