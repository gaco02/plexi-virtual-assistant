#!/bin/bash
set -euo pipefail

# Deploy to Google Cloud Run with Secret Manager for Firebase credentials
#
# Required environment variables (set before running):
#   DB_PASSWORD, OPENAI_API_KEY, FIREBASE_WEB_API_KEY
#
# Usage:
#   export DB_PASSWORD=xxx OPENAI_API_KEY=xxx FIREBASE_WEB_API_KEY=xxx
#   ./deploy-cloud-run.sh

SERVICE_NAME="plexi-assistant-api"
REGION="us-west1"
PROJECT="plexi-assistant"
IMAGE="gcr.io/${PROJECT}/${SERVICE_NAME}"
CLOUD_SQL_INSTANCE="${PROJECT}:${REGION}:plexi-postgres"

# Validate required env vars
for var in DB_PASSWORD OPENAI_API_KEY FIREBASE_WEB_API_KEY; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: $var is not set"
        exit 1
    fi
done

echo "Building and deploying ${SERVICE_NAME} to ${REGION}..."

gcloud builds submit --tag "${IMAGE}"

gcloud run deploy "${SERVICE_NAME}" \
  --image "${IMAGE}" \
  --platform managed \
  --region "${REGION}" \
  --allow-unauthenticated \
  --add-cloudsql-instances="${CLOUD_SQL_INSTANCE}" \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=10 \
  --set-env-vars \
    "DB_USER=plexi_user,\
DB_PASSWORD=${DB_PASSWORD},\
DB_NAME=plexi_db,\
DB_HOST=/cloudsql/${CLOUD_SQL_INSTANCE},\
FIREBASE_PROJECT_ID=plexi-assistant-5afb4,\
FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY},\
OPENAI_API_KEY=${OPENAI_API_KEY},\
ENVIRONMENT=production" \
  --update-secrets FIREBASE_CREDENTIALS=firebase-credentials:latest

echo "Deployment complete. Service URL:"
gcloud run services describe "${SERVICE_NAME}" --region="${REGION}" --format='value(status.url)'
