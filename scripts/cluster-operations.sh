#!/bin/bash

# Talos Linux Cluster Operations Script
# This script provides common operations for managing the Talos cluster

set -euo pipefail

# Configuration
CLUSTER_NAME="talos-ipv6-cluster"
OMNI_CONTEXT="default-1"
KUBECONFIG_FILE="$HOME/.kube/config-talos-ipv6"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    cat << EOF
Talos Cluster Operations Script

Usage: $0 [COMMAND]

Commands:
    status          Show cluster and node status
    machines        List all machines in Omni
    clusters        List all clusters in Omni
    bootstrap       Bootstrap a new cluster
    kubeconfig      Download and configure kubeconfig
    nodes           Show Kubernetes nodes
    pods            Show all pods
    health          Check cluster health
    logs            Show cluster logs
    update          Update cluster
    reset           Reset cluster (WARNING: destructive)
    help            Show this help message

Examples:
    $0 status       # Show overall cluster status
    $0 bootstrap    # Bootstrap new cluster
    $0 kubeconfig   # Download kubeconfig
    $0 health       # Check cluster health
EOF
}

# Check prerequisites
check_prerequisites() {
    if ! command -v omnictl &> /dev/null; then
        log_error "omnictl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
}

# Show cluster status
show_status() {
    log_info "Cluster Status Overview"
    echo "========================"
    
    log_info "Omni Machines:"
    omnictl get machines --context="$OMNI_CONTEXT" || log_warning "Could not fetch machines"
    
    echo ""
    log_info "Omni Clusters:"
    omnictl get clusters --context="$OMNI_CONTEXT" || log_warning "Could not fetch clusters"
    
    if [ -f "$KUBECONFIG_FILE" ]; then
        echo ""
        log_info "Kubernetes Nodes:"
        kubectl get nodes --kubeconfig="$KUBECONFIG_FILE" -o wide || log_warning "Could not fetch nodes"
        
        echo ""
        log_info "System Pods:"
        kubectl get pods -n kube-system --kubeconfig="$KUBECONFIG_FILE" || log_warning "Could not fetch pods"
    else
        log_warning "Kubeconfig not found at $KUBECONFIG_FILE"
    fi
}

# List machines
list_machines() {
    log_info "Listing all machines in Omni..."
    omnictl get machines --context="$OMNI_CONTEXT" -o yaml
}

# List clusters
list_clusters() {
    log_info "Listing all clusters in Omni..."
    omnictl get clusters --context="$OMNI_CONTEXT" -o yaml
}

# Bootstrap cluster
bootstrap_cluster() {
    log_info "Bootstrapping cluster '$CLUSTER_NAME'..."
    
    # Check if cluster already exists
    if omnictl get cluster "$CLUSTER_NAME" --context="$OMNI_CONTEXT" &> /dev/null; then
        log_warning "Cluster '$CLUSTER_NAME' already exists"
        return
    fi
    
    log_info "Creating cluster configuration..."
    # This would typically involve creating cluster through Omni API
    # For now, we'll provide instructions
    cat << EOF

To bootstrap the cluster, please:

1. Open Omni dashboard: https://witson.omni.siderolabs.io
2. Navigate to Clusters section
3. Click "Create Cluster"
4. Set cluster name: $CLUSTER_NAME
5. Select your registered machine
6. Configure as single-node (control plane + worker)
7. Apply configuration

Or use omnictl CLI:
    omnictl cluster create $CLUSTER_NAME --context=$OMNI_CONTEXT

EOF
}

# Download kubeconfig
download_kubeconfig() {
    log_info "Downloading kubeconfig for cluster '$CLUSTER_NAME'..."
    
    # Create .kube directory if it doesn't exist
    mkdir -p "$(dirname "$KUBECONFIG_FILE")"
    
    # Download kubeconfig
    if omnictl kubeconfig "$CLUSTER_NAME" --context="$OMNI_CONTEXT" > "$KUBECONFIG_FILE"; then
        log_success "Kubeconfig saved to $KUBECONFIG_FILE"
        log_info "You can now use kubectl with: kubectl --kubeconfig=$KUBECONFIG_FILE"
        log_info "Or set KUBECONFIG environment variable: export KUBECONFIG=$KUBECONFIG_FILE"
    else
        log_error "Failed to download kubeconfig"
        exit 1
    fi
}

# Show nodes
show_nodes() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        log_error "Kubeconfig not found. Run '$0 kubeconfig' first."
        exit 1
    fi
    
    log_info "Kubernetes Nodes:"
    kubectl get nodes --kubeconfig="$KUBECONFIG_FILE" -o wide
    
    echo ""
    log_info "Node Details:"
    kubectl describe nodes --kubeconfig="$KUBECONFIG_FILE"
}

# Show pods
show_pods() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        log_error "Kubeconfig not found. Run '$0 kubeconfig' first."
        exit 1
    fi
    
    log_info "All Pods:"
    kubectl get pods --all-namespaces --kubeconfig="$KUBECONFIG_FILE" -o wide
}

# Check health
check_health() {
    log_info "Checking cluster health..."
    
    log_info "Omni cluster status:"
    omnictl get cluster "$CLUSTER_NAME" --context="$OMNI_CONTEXT" || log_warning "Could not get cluster status from Omni"
    
    if [ -f "$KUBECONFIG_FILE" ]; then
        echo ""
        log_info "Kubernetes cluster info:"
        kubectl cluster-info --kubeconfig="$KUBECONFIG_FILE" || log_warning "Could not get cluster info"
        
        echo ""
        log_info "Component status:"
        kubectl get componentstatuses --kubeconfig="$KUBECONFIG_FILE" || log_warning "Component status not available"
        
        echo ""
        log_info "Node conditions:"
        kubectl get nodes --kubeconfig="$KUBECONFIG_FILE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | column -t
    else
        log_warning "Kubeconfig not found at $KUBECONFIG_FILE"
    fi
}

# Show logs
show_logs() {
    if [ ! -f "$KUBECONFIG_FILE" ]; then
        log_error "Kubeconfig not found. Run '$0 kubeconfig' first."
        exit 1
    fi
    
    log_info "Recent cluster events:"
    kubectl get events --sort-by=.metadata.creationTimestamp --kubeconfig="$KUBECONFIG_FILE" | tail -20
    
    echo ""
    log_info "System pod logs (last 10 lines each):"
    kubectl get pods -n kube-system --kubeconfig="$KUBECONFIG_FILE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | while read -r pod; do
        echo "=== $pod ==="
        kubectl logs "$pod" -n kube-system --kubeconfig="$KUBECONFIG_FILE" --tail=10 || true
        echo ""
    done
}

# Update cluster
update_cluster() {
    log_info "Updating cluster '$CLUSTER_NAME'..."
    
    log_warning "This operation will update Talos Linux and Kubernetes versions"
    read -p "Continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Update cancelled"
        return
    fi
    
    # Use Omni to update cluster
    log_info "Triggering cluster update through Omni..."
    omnictl cluster update "$CLUSTER_NAME" --context="$OMNI_CONTEXT" || log_error "Update failed"
}

# Reset cluster
reset_cluster() {
    log_error "WARNING: This will completely reset the cluster!"
    log_error "All workloads and data will be lost!"
    
    read -p "Type 'yes' to confirm cluster reset: " -r
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Reset cancelled"
        return
    fi
    
    log_info "Resetting cluster '$CLUSTER_NAME'..."
    # This would use Omni API to reset/destroy cluster
    log_warning "Please use Omni dashboard to reset the cluster manually"
    log_info "Go to: https://witson.omni.siderolabs.io"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    check_prerequisites
    
    case "$1" in
        status)
            show_status
            ;;
        machines)
            list_machines
            ;;
        clusters)
            list_clusters
            ;;
        bootstrap)
            bootstrap_cluster
            ;;
        kubeconfig)
            download_kubeconfig
            ;;
        nodes)
            show_nodes
            ;;
        pods)
            show_pods
            ;;
        health)
            check_health
            ;;
        logs)
            show_logs
            ;;
        update)
            update_cluster
            ;;
        reset)
            reset_cluster
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"