#!/bin/bash

# PostgreSQL Import Script
# Imports a database dump file into a pod

set -e

# Check arguments
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <pod-name> <username> <dump-file> [namespace]"
    echo "Example: $0 postgres-new-0 keycloak ./backup.sql default"
    exit 1
fi

POD_NAME=$1
USERNAME=$2
DUMP_FILE=$3
NAMESPACE=${4:-default}

# Check if dump file exists
if [ ! -f "$DUMP_FILE" ]; then
    echo "✗ Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "=========================================="
echo "PostgreSQL Database Import"
echo "=========================================="
echo "Pod: $POD_NAME"
echo "Username: $USERNAME"
echo "Dump File: $DUMP_FILE ($(du -h "$DUMP_FILE" | cut -f1))"
echo "Namespace: $NAMESPACE"
echo "=========================================="

# Prompt for password
read -r -s -p "Enter password for user $USERNAME: " PGPASSWORD
echo
export PGPASSWORD

# Import to pod
echo "Importing database into $POD_NAME..."
kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- env PGPASSWORD="$PGPASSWORD" psql -U "$USERNAME" postgres < "$DUMP_FILE"

# Clear password from environment
unset PGPASSWORD

if [ $? -eq 0 ]; then
    echo "✓ Import successful"
else
    echo "✗ Import failed"
    exit 1
fi

echo "=========================================="
echo "Import complete!"
echo "=========================================="
