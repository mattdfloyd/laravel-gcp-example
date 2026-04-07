#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Workload Identity Federation Setup
# ============================================
# Allows GitHub Actions to authenticate to GCP
# without storing service account keys.
#
# Run this once, then add the outputs as
# GitHub repository secrets.
# ============================================

PROJECT_ID="laravel-gcp-example"
GITHUB_ORG="mattdfloyd"
GITHUB_REPO="laravel-gcp-example"
REGION="us-east1"
APP_NAME="laravel-gcp-example"

SA_NAME="${APP_NAME}-github"
POOL_NAME="${APP_NAME}-github-pool"
PROVIDER_NAME="${APP_NAME}-github-provider"

echo "▸ Creating service account..."
gcloud iam service-accounts create "$SA_NAME" \
  --display-name="GitHub Actions for ${APP_NAME}" \
  --project="$PROJECT_ID"

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "▸ Granting roles to service account..."

# Cloud Run: deploy services and jobs
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

# Cloud Build: submit builds
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudbuild.builds.editor"

# Artifact Registry: push images
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/artifactregistry.writer"

# Secret Manager: read secrets (for deploy)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"

# Cloud SQL: manage instances (for migrations)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudsql.client"

# Service Account User: act as compute SA for Cloud Run
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# Storage: for Terraform state
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

# Compute: for VPC connectors (Terraform)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.networkAdmin"

# VPC Access: for serverless connectors (Terraform)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/vpcaccess.admin"

# Redis: for Memorystore (Terraform)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/redis.admin"

# Cloud Scheduler (Terraform)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/cloudscheduler.admin"

echo "▸ Creating Workload Identity Pool..."
gcloud iam workload-identity-pools create "$POOL_NAME" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="$PROJECT_ID"

echo "▸ Creating OIDC Provider..."
gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
  --location="global" \
  --workload-identity-pool="$POOL_NAME" \
  --display-name="GitHub OIDC" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project="$PROJECT_ID"

echo "▸ Binding service account to pool..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/${POOL_NAME}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}" \
  --project="$PROJECT_ID"

# ── Output ──────────────────────────────────

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME}"

echo ""
echo "============================================"
echo "✅ Setup complete!"
echo ""
echo "Add these as GitHub repository secrets:"
echo ""
echo "  GCP_PROJECT_ID"
echo "  → ${PROJECT_ID}"
echo ""
echo "  GCP_SERVICE_ACCOUNT"
echo "  → ${SA_EMAIL}"
echo ""
echo "  GCP_WORKLOAD_IDENTITY_PROVIDER"
echo "  → ${WIF_PROVIDER}"
echo ""
echo "============================================"
