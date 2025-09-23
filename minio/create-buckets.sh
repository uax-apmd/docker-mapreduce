#!/bin/sh
set -euo pipefail

# Define alias 'minio' con URL sin credenciales + user/pass como args
mc alias set minio "${MINIO_ENDPOINT:-http://minio:9000}" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

# Crea buckets si no existen
mc mb --ignore-existing minio/"$S3_BUCKET_LOGS"
mc mb --ignore-existing minio/"$S3_BUCKET_RESULTS"

echo "Buckets OK: $S3_BUCKET_LOGS, $S3_BUCKET_RESULTS"
