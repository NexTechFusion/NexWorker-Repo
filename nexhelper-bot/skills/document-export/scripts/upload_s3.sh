#!/bin/bash
# S3 Upload Script
# Uploads files to S3-compatible storage
#
# Usage: ./upload_s3.sh <file> [bucket] [key]

set -e

FILE="${1}"
BUCKET="${2:-${S3_BUCKET:-nexhelper-docs}}"
KEY="${3:-$(basename "${FILE}")}"

# Load environment
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.eu-central-1.amazonaws.com}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Usage: ./upload_s3.sh <file> [bucket] [key]"
    exit 1
fi

if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "❌ S3 credentials not configured"
    echo "   Set S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET"
    exit 1
fi

# Extract endpoint host
S3_HOST=$(echo "$S3_ENDPOINT" | sed 's|https://\?||' | sed 's|/.*||')

# Generate timestamp and signature
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
DATE=$(date -u +"%Y%m%d")

# Create canonical request
CONTENT_TYPE="application/octet-stream"
CONTENT_SHA256=$(sha256sum "${FILE}" | cut -d' ' -f1)

# Build string to sign (simplified - for production use AWS CLI or proper signing)
STRING_TO_SIGN="PUT

${CONTENT_SHA256}

x-amz-content-sha256:${CONTENT_SHA256}
x-amz-date:${TIMESTAMP}

/${BUCKET}/${KEY}"

# For production, use AWS CLI if available
if command -v aws &> /dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "☁️  Uploading to S3"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "File:   ${FILE}"
    echo "Bucket: ${BUCKET}"
    echo "Key:    ${KEY}"
    echo ""
    
    aws s3 cp "${FILE}" "s3://${BUCKET}/${KEY}" \
        --endpoint-url "${S3_ENDPOINT}" \
        --region "${S3_REGION:-eu-central-1}"
    
    echo ""
    echo "✅ Upload complete!"
    echo "   URL: ${S3_ENDPOINT}/${BUCKET}/${KEY}"
    echo ""
else
    # Use curl with presigned URL or direct upload
    # This is simplified - for production, use proper AWS Signature v4
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "☁️  Uploading to S3 (curl)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "File:   ${FILE}"
    echo "Bucket: ${BUCKET}"
    echo "Key:    ${KEY}"
    echo ""
    
    # Simplified upload (requires bucket to be public or pre-signed URL)
    curl -X PUT \
        -T "${FILE}" \
        -H "Content-Type: ${CONTENT_TYPE}" \
        -H "x-amz-date: ${TIMESTAMP}" \
        "${S3_ENDPOINT}/${BUCKET}/${KEY}" \
        --user "${S3_ACCESS_KEY}:${S3_SECRET_KEY}" \
        -s -o /dev/null -w "%{http_code}"
    
    echo ""
    echo "✅ Upload complete!"
    echo ""
fi
