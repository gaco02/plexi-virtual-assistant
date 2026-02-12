#!/bin/bash

# Deploy to Google Cloud Run with Secret Manager for Firebase credentials
# NOTE: Set these environment variables before running, or use Google Secret Manager
#   DB_PASSWORD, OPENAI_API_KEY, FIREBASE_WEB_API_KEY

gcloud run deploy tiktok-analyzer \
  --image gcr.io/plexi-assistant/tiktok-analyzer \
  --platform managed \
  --region us-west1 \
  --allow-unauthenticated \
  --add-cloudsql-instances=plexi-assistant:us-west1:plexi-postgres \
  --set-env-vars DB_USER=plexi_user,DB_PASSWORD=${DB_PASSWORD},DB_NAME=plexi_db,DB_HOST=/cloudsql/plexi-assistant:us-west1:plexi-postgres,FIREBASE_PROJECT_ID=virtual-assistant-app-f7f1d,FIREBASE_WEB_API_KEY=${FIREBASE_WEB_API_KEY},OPENAI_API_KEY=${OPENAI_API_KEY} \
  --update-secrets FIREBASE_CREDENTIALS=firebase-credentials:latest
