# Makefile for Talos Linux GCP Deployment
# Provides common operations for managing the Talos cluster

.DEFAULT_GOAL := help
.PHONY: help init plan apply destroy status clean fmt validate

# Configuration
PROJECT_ID := $(shell gcloud config get-value project)
CLUSTER_NAME := talos-ipv6-cluster
SCRIPTS_DIR := scripts
KUBECONFIG_FILE := $(HOME)/.kube/config-talos-ipv6
OMNI_CONTEXT := default-1

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Talos Linux GCP Deployment$(NC)"
	@echo "=============================="
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Prerequisites:$(NC)"
	@echo "  - gcloud CLI installed and authenticated"
	@echo "  - terraform installed"
	@echo "  - omnictl installed"
	@echo "  - kubectl installed"
	@echo ""
	@echo "$(YELLOW)Quick Start:$(NC)"
	@echo "  1. make deploy          # Deploy IPv6 infrastructure"
	@echo "  2. make cluster-bootstrap # Create cluster via web UI"
	@echo "  3. make kubeconfig      # Download kubeconfig"
	@echo "  4. make status          # Check cluster status"

## Infrastructure Management

create-network: ## Create IPv6-enabled VPC and subnet
	@echo "$(BLUE)[INFO]$(NC) Creating IPv6-enabled network..."
	@gcloud compute networks create talos-ipv6-vpc --subnet-mode=custom || echo "Network may already exist"
	@gcloud compute networks subnets create talos-ipv6-subnet \
		--network=talos-ipv6-vpc \
		--region=us-central1 \
		--range=10.1.0.0/16 \
		--stack-type=IPV4_IPV6 \
		--ipv6-access-type=EXTERNAL || echo "Subnet may already exist"
	@echo "$(GREEN)[SUCCESS]$(NC) IPv6 network ready"

create-firewall: ## Create firewall rules for IPv6 network
	@echo "$(BLUE)[INFO]$(NC) Creating firewall rules..."
	@gcloud compute firewall-rules create talos-ipv6-internal \
		--network talos-ipv6-vpc \
		--allow tcp,udp,icmp \
		--source-ranges 10.1.0.0/16 || echo "Rule may already exist"
	@gcloud compute firewall-rules create talos-ipv6-api \
		--network talos-ipv6-vpc \
		--allow tcp:50000 \
		--source-ranges 0.0.0.0/0,::/0 || echo "Rule may already exist"
	@gcloud compute firewall-rules create talos-ipv6-k8s \
		--network talos-ipv6-vpc \
		--allow tcp:6443 \
		--source-ranges 0.0.0.0/0,::/0 || echo "Rule may already exist"
	@echo "$(GREEN)[SUCCESS]$(NC) Firewall rules configured"

create-instance: ## Create Talos instance on IPv6 network
	@echo "$(BLUE)[INFO]$(NC) Creating Talos instance..."
	@gcloud compute instances create apollo-gcp-ipv6 \
		--zone=us-central1-a \
		--machine-type=n2-standard-4 \
		--network=talos-ipv6-vpc \
		--subnet=talos-ipv6-subnet \
		--image=talos-v1101-omni-ipv6 \
		--boot-disk-size=250GB \
		--boot-disk-type=pd-standard \
		--tags=talos-node \
		--stack-type=IPV4_IPV6 \
		--ipv6-network-tier=PREMIUM
	@echo "$(GREEN)[SUCCESS]$(NC) Instance created"
	@echo "$(YELLOW)[INFO]$(NC) Wait 2-3 minutes for machine to register with Omni"

destroy-infrastructure: ## Destroy all GCP resources
	@echo "$(RED)[WARNING]$(NC) This will destroy all GCP infrastructure!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	@echo "$(BLUE)[INFO]$(NC) Destroying infrastructure..."
	@gcloud compute instances delete apollo-gcp-ipv6 --zone=us-central1-a --quiet || true
	@gcloud compute images delete talos-v1101-omni-ipv6 --quiet || true
	@gcloud compute firewall-rules delete talos-ipv6-internal talos-ipv6-api talos-ipv6-k8s --quiet || true
	@gcloud compute networks subnets delete talos-ipv6-subnet --region=us-central1 --quiet || true
	@gcloud compute networks delete talos-ipv6-vpc --quiet || true
	@echo "$(GREEN)[SUCCESS]$(NC) Infrastructure destroyed"

## Cluster Management

status: ## Show overall cluster status
	@echo "$(BLUE)[INFO]$(NC) Checking cluster status..."
	@$(SCRIPTS_DIR)/cluster-operations.sh status

omni-machines: ## List machines in Omni
	@echo "$(BLUE)[INFO]$(NC) Listing Omni machines..."
	@omnictl get machines --context=$(OMNI_CONTEXT) || echo "$(RED)[ERROR]$(NC) Failed to fetch machines"

omni-clusters: ## List clusters in Omni
	@echo "$(BLUE)[INFO]$(NC) Listing Omni clusters..."
	@omnictl get clusters --context=$(OMNI_CONTEXT) || echo "$(RED)[ERROR]$(NC) Failed to fetch clusters"

cluster-bootstrap: ## Instructions for creating cluster
	@echo "$(BLUE)[INFO]$(NC) Cluster creation via Omni web interface..."
	@echo ""
	@echo "$(YELLOW)Steps to create cluster:$(NC)"
	@echo "1. Go to: https://witson.omni.siderolabs.io"
	@echo "2. Navigate to Clusters → Create Cluster"
	@echo "3. Set cluster name: $(CLUSTER_NAME)"
	@echo "4. Select your registered machine"
	@echo "5. Configure as single-node (control plane + worker)"
	@echo "6. Apply configuration"
	@echo ""
	@echo "Then run: make kubeconfig"

kubeconfig: ## Download and configure kubeconfig
	@echo "$(BLUE)[INFO]$(NC) Downloading kubeconfig..."
	@mkdir -p $(dir $(KUBECONFIG_FILE))
	@omnictl kubeconfig $(KUBECONFIG_FILE) --cluster=$(CLUSTER_NAME) --context=$(OMNI_CONTEXT) --merge=false --force
	@echo "$(GREEN)[SUCCESS]$(NC) Kubeconfig saved to $(KUBECONFIG_FILE)"
	@echo "Usage: kubectl --kubeconfig=$(KUBECONFIG_FILE) get nodes"

nodes: ## Show Kubernetes nodes
	@echo "$(BLUE)[INFO]$(NC) Showing Kubernetes nodes..."
	@$(SCRIPTS_DIR)/cluster-operations.sh nodes

pods: ## Show all pods
	@echo "$(BLUE)[INFO]$(NC) Showing all pods..."
	@$(SCRIPTS_DIR)/cluster-operations.sh pods

health: ## Check cluster health
	@echo "$(BLUE)[INFO]$(NC) Checking cluster health..."
	@$(SCRIPTS_DIR)/cluster-operations.sh health

logs: ## Show cluster logs
	@echo "$(BLUE)[INFO]$(NC) Showing cluster logs..."
	@$(SCRIPTS_DIR)/cluster-operations.sh logs

## Application Management

argocd-install: kubeconfig ## Install ArgoCD
	@echo "$(BLUE)[INFO]$(NC) Installing ArgoCD..."
	@kubectl apply -f argocd/ --kubeconfig=$(KUBECONFIG_FILE)
	@echo "$(GREEN)[SUCCESS]$(NC) ArgoCD installed"
	@echo "Wait for pods to be ready, then access via port-forward"

argocd-port-forward: ## Port forward to ArgoCD
	@echo "$(BLUE)[INFO]$(NC) Port forwarding to ArgoCD..."
	@kubectl port-forward svc/argocd-server -n argocd 8080:443 --kubeconfig=$(KUBECONFIG_FILE)

## Development and Debugging

tf-output: ## Show Terraform outputs
	@echo "$(BLUE)[INFO]$(NC) Terraform outputs:"
	@cd $(TERRAFORM_DIR) && terraform output

tf-state: ## Show Terraform state
	@echo "$(BLUE)[INFO]$(NC) Terraform state:"
	@cd $(TERRAFORM_DIR) && terraform state list

instance-info: ## Show GCP instance information
	@echo "$(BLUE)[INFO]$(NC) GCP instance information:"
	@gcloud compute instances list --filter="labels.component=talos" --format="table(name,zone,machineType,status,externalIP)"

instance-logs: ## Show instance startup logs
	@echo "$(BLUE)[INFO]$(NC) Instance startup logs:"
	@INSTANCE_NAME=$$(cd $(TERRAFORM_DIR) && terraform output -raw instance_name 2>/dev/null || echo "talos-node") && \
	 ZONE=$$(cd $(TERRAFORM_DIR) && terraform output -raw zone 2>/dev/null || echo "us-central1-a") && \
	 gcloud compute instances get-serial-port-output $$INSTANCE_NAME --zone=$$ZONE

ssh-debug: ## SSH to instance for debugging (not normally needed for Talos)
	@echo "$(YELLOW)[WARNING]$(NC) Talos Linux doesn't support SSH by design"
	@echo "Use 'make instance-logs' to view startup logs"
	@echo "Use 'make health' to check cluster health"

## Utilities

check-deps: ## Check if required dependencies are installed
	@echo "$(BLUE)[INFO]$(NC) Checking dependencies..."
	@command -v gcloud >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) gcloud is not installed"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) terraform is not installed"; exit 1; }
	@command -v omnictl >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) omnictl is not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) kubectl is not installed"; exit 1; }
	@echo "$(GREEN)[SUCCESS]$(NC) All dependencies are installed"

gcp-auth: ## Check GCP authentication
	@echo "$(BLUE)[INFO]$(NC) Checking GCP authentication..."
	@gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 || { echo "$(RED)[ERROR]$(NC) Not authenticated with gcloud"; exit 1; }
	@gcloud config get-value project || { echo "$(RED)[ERROR]$(NC) No GCP project set"; exit 1; }
	@echo "$(GREEN)[SUCCESS]$(NC) GCP authentication OK"

omni-auth: ## Check Omni authentication
	@echo "$(BLUE)[INFO]$(NC) Checking Omni authentication..."
	@omnictl get machines --context=$(OMNI_CONTEXT) >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(NC) Cannot connect to Omni"; exit 1; }
	@echo "$(GREEN)[SUCCESS]$(NC) Omni authentication OK"

prereqs: check-deps gcp-auth omni-auth ## Check all prerequisites

## Quick deployment workflow

deploy: prereqs create-network create-firewall create-instance ## Full deployment workflow
	@echo "$(GREEN)[SUCCESS]$(NC) Deployment completed!"
	@echo ""
	@echo "$(YELLOW)[NEXT STEPS]$(NC)"
	@echo "1. Wait 2-3 minutes for instance to boot"
	@echo "2. Check machine registration: make omni-machines"
	@echo "3. Create cluster via web interface: make cluster-bootstrap"
	@echo "4. Get kubeconfig: make kubeconfig"
	@echo "5. Verify cluster: make nodes"

teardown: destroy-infrastructure ## Full teardown workflow
	@echo "$(GREEN)[SUCCESS]$(NC) Teardown completed!"

## Information

info: ## Show deployment information
	@echo "$(BLUE)Talos Linux GCP Deployment Information$(NC)"
	@echo "======================================="
	@echo ""
	@echo "$(YELLOW)Project Configuration:$(NC)"
	@echo "  Project ID: $(PROJECT_ID)"
	@echo "  Cluster Name: $(CLUSTER_NAME)"
	@echo "  Kubeconfig: $(KUBECONFIG_FILE)"
	@echo ""
	@echo "$(YELLOW)Directories:$(NC)"
	@echo "  Scripts: $(SCRIPTS_DIR)/"
	@echo "  Talos Config: talos-config/"
	@echo "  Documentation: docs/"
	@echo ""
	@echo "$(YELLOW)Key Files:$(NC)"
	@echo "  README.md - Project documentation"
	@echo "  Makefile - Deployment commands"
	@echo "  scripts/cluster-operations.sh - Cluster management"
	@echo "  docs/deployment-guide.md - Detailed deployment guide"
	@echo ""
	@echo "$(YELLOW)Network Configuration:$(NC)"
	@echo "  VPC: talos-ipv6-vpc (IPv4/IPv6 dual-stack)"
	@echo "  Subnet: talos-ipv6-subnet (10.1.0.0/16, IPv6 enabled)"
	@echo "  Region: us-central1"
	@echo ""
	@echo "$(YELLOW)Current Status:$(NC)"
	@gcloud compute instances list --filter="name:apollo-gcp-ipv6" --format="value(name,status)" 2>/dev/null || echo "  No instance found"