#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Local Calendars — Deploy to S3 + CloudFront
# Subdomain: localcalendars.huntington-analytics.com
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUCKET="localcalendars.huntington-analytics.com"
REGION="us-east-1"

echo "=== Local Calendars — Deploy ==="
echo "Bucket:  $BUCKET"
echo "Domain:  localcalendars.huntington-analytics.com"
echo ""

# Check prerequisites
if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required but not installed."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 1. Sync to S3
# ─────────────────────────────────────────────────────────────
echo "--- Step 1: Syncing to S3 ---"

# HTML files with no-cache
aws s3 sync "$SCRIPT_DIR/" "s3://$BUCKET/" \
  --delete \
  --exclude "*" \
  --include "*.html" \
  --exclude ".git/*" \
  --exclude "deploy.sh" \
  --cache-control "max-age=0, must-revalidate" \
  --region "$REGION"

# Other assets with moderate cache
aws s3 sync "$SCRIPT_DIR/" "s3://$BUCKET/" \
  --exclude "*.html" \
  --exclude ".git/*" \
  --exclude "deploy.sh" \
  --cache-control "max-age=86400" \
  --region "$REGION"

echo "S3 sync complete."
echo ""

# ─────────────────────────────────────────────────────────────
# 2. Invalidate CloudFront cache (if distribution exists)
# ─────────────────────────────────────────────────────────────
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Aliases.Items[?contains(@,'localcalendars.huntington-analytics.com')]].Id" \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$DIST_ID" ] && [ "$DIST_ID" != "None" ]; then
  echo "--- Step 2: Invalidating CloudFront cache ---"
  INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$DIST_ID" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text \
    --region "$REGION")
  echo "Invalidation created: $INVALIDATION_ID"
else
  echo "--- Step 2: No CloudFront distribution found for this subdomain ---"
  echo "Set up CloudFront + Route 53 to serve from: $BUCKET"
fi

echo ""
echo "=== Deploy Complete ==="
echo "Site: https://localcalendars.huntington-analytics.com"
