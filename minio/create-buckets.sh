#!/bin/sh
set -euo pipefail
mc alias set minio "$MC_HOST_minio"

# Crea buckets si no existen
mc ls minio/"$S3_BUCKET_LOGS" >/dev/null 2>&1 || mc mb minio/"$S3_BUCKET_LOGS"
mc ls minio/"$S3_BUCKET_RESULTS" >/dev/null 2>&1 || mc mb minio/"$S3_BUCKET_RESULTS"

echo "Buckets OK: $S3_BUCKET_LOGS, $S3_BUCKET_RESULTS"
