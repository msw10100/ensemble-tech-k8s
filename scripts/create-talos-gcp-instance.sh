#!/bin/bash

# Create a fresh Talos instance on GCP that connects to Omni
# This uses a Talos boot image (requires image to be uploaded first)

set -euo pipefail

source .env

echo "🚀 Creating fresh Talos instance on GCP..."

# Check if the Talos image exists
if ! gcloud compute images describe talos-omni-image --project=$GCP_PROJECT_ID >/dev/null 2>&1; then
    echo "❌ Talos image 'talos-omni-image' not found."
    echo "Please download the image from Omni and upload it first:"
    echo "1. Go to Omni web interface"
    echo "2. Download machine image configured for your setup"
    echo "3. Upload to GCS: gsutil cp gcp-amd64-omni-witson-v1.10.1.raw.tar.gz gs://chorus-deployment-images-$GCP_PROJECT_ID/"
    echo "4. Create image: gcloud compute images create talos-omni-image --source-uri gs://chorus-deployment-images-$GCP_PROJECT_ID/gcp-amd64-omni-witson-v1.10.1.raw.tar.gz"
    exit 1
fi

# Create instance with Talos boot image
gcloud compute instances create apollo-gcp-talos \
    --project=$GCP_PROJECT_ID \
    --zone=$GCP_ZONE \
    --machine-type=$GCP_MACHINE_TYPE \
    --network-interface=network-tier=PREMIUM,subnet=talos-ipv6-subnet,stack-type=IPV4_IPV6 \
    --image=talos-omni-image \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=apollo-gcp-talos \
    --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write

echo "✅ Instance created with Talos image. It should register with Omni in 2-3 minutes."
echo "Check Omni dashboard for the new machine to appear."