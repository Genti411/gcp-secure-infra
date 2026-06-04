#!/usr/bin/env bash
# Build the image, then provision + deploy with Terraform.
#   ./deploy.sh YOUR_PROJECT_ID [REGION]
# Requires: gcloud (authenticated), terraform, a billing-enabled project.
set -euo pipefail

PROJECT_ID="${1:?usage: ./deploy.sh PROJECT_ID [REGION]}"
REGION="${2:-us-central1}"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/secure-apps/secure-app:latest"

gcloud config set project "$PROJECT_ID"
cd "$(dirname "$0")/terraform"
terraform init

# 1) Enable APIs + create the Artifact Registry repo first (the image push and
#    the Cloud Run service both depend on these existing).
terraform apply -auto-approve \
  -target=google_project_service.apis \
  -target=google_artifact_registry_repository.repo \
  -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="image=$IMAGE"

# 2) Build + push the container image with Cloud Build.
gcloud builds submit ../app --tag "$IMAGE"

# 3) Full apply: least-privilege SA, Secret Manager secret, Cloud Run, IAM.
terraform apply -auto-approve \
  -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="image=$IMAGE"

echo
echo "Deployed. Service URL:"
terraform output -raw service_url
echo
