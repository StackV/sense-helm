#!/bin/bash

# PostgreSQL Export Script
# Exports a database from a pod to a local dump file

set -e

# Check arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <pod-name> <database-name> <username> [namespace] [output-file]"
    echo "Example: $0 postgres-0 bitnami_keycloak keycloak default ./backup.sql"
    exit 1
fi

POD_NAME=$1
DATABASE=$2
USERNAME=$3
NAMESPACE=${4:-default}
OUTPUT_FILE=${5:-${DATABASE}_dump_$(date +%Y%m%d_%H%M%S).sql}

echo "=========================================="
echo "PostgreSQL Database Export"
echo "=========================================="
echo "Pod: $POD_NAME"
echo "Database: $DATABASE"
echo "Username: $USERNAME"
echo "Namespace: $NAMESPACE"
echo "Output File: $OUTPUT_FILE"
echo "=========================================="

# Export from pod
echo "Exporting database from $POD_NAME..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- pg_dump -U "$USERNAME" -C -c --if-exists "$DATABASE" > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Export successful: $OUTPUT_FILE ($(du -h "$OUTPUT_FILE" | cut -f1))"
else
    echo "✗ Export failed"
    exit 1
fi

echo "=========================================="
echo "Export complete!"
echo "=========================================="
