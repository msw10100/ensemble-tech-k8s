#!/bin/bash

# Rebuild GCP instance and cluster from clean Omni image
# This script automates the entire process once the image is uploaded

set -euo pipefail

# Load environment variables
source .env

echo "🚀 Starting fresh cluster rebuild process..."
echo "Project: $GCP_PROJECT_ID"
echo "Zone: $GCP_ZONE"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Step 1: Check if image upload is complete
echo "📥 Checking image upload status..."
if ! gsutil ls gs://chorus-deployment-images-$GCP_PROJECT_ID/disk.raw > /dev/null 2>&1; then
    echo "❌ Image not found in Cloud Storage. Please wait for upload to complete."
    exit 1
fi

# Step 2: Create GCP compute image from uploaded disk
echo "🖼️ Creating GCP compute image..."
gcloud compute images create talos-omni-clean-v1101 \
    --source-uri gs://chorus-deployment-images-$GCP_PROJECT_ID/disk.raw \
    --project $GCP_PROJECT_ID \
    --quiet || echo "Image may already exist"

# Step 3: Create fresh GCP instance with clean image
echo "💻 Creating fresh GCP instance..."
gcloud compute instances create apollo-gcp-ipv6-clean \
    --project=$GCP_PROJECT_ID \
    --zone=$GCP_ZONE \
    --machine-type=$GCP_MACHINE_TYPE \
    --network-interface=network-tier=PREMIUM,subnet=talos-ipv6-subnet,stack-type=IPV4_IPV6 \
    --image=talos-omni-clean-v1101 \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=apollo-gcp-ipv6-clean \
    --shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring

echo "⏳ Waiting for instance to start..."
sleep 30

# Step 4: Get the new machine ID from Omni (manual step)
echo "📋 Next steps:"
echo "1. Wait 2-3 minutes for the machine to register with Omni"
echo "2. Check Omni dashboard for the new machine ID"
echo "3. Update cluster-template.yaml with the new machine ID"
echo "4. Run: omnictl cluster template sync --file cluster-template.yaml --context=$OMNI_CONTEXT"
echo "5. Run: ./scripts/setup-fresh-cluster.sh"
echo ""
echo "🎉 GCP instance created successfully!"
echo "Instance name: apollo-gcp-ipv6-clean"
echo "Next: Update cluster template and create cluster"