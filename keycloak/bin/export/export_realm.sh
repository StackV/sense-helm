#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly KEYCLOAK_STATEFULSET="keycloak-keycloakx"

CONTEXT=""
NAMESPACE="default"
REALM="StackV"
STORAGE_CLASS="local-path"
STORAGE_SIZE="256Mi"
OUTPUT_DIR=""

usage() {
  cat <<'EOF'
Usage: export_realm.sh --context CONTEXT [options]

Export a Keycloak realm using the live deployment's image and database connection.
The script temporarily scales the Keycloak StatefulSet to zero, but leaves
PostgreSQL running.

Options:
  --context CONTEXT       Required kubectl context.
  --namespace NAMESPACE   Keycloak namespace (default: default).
  --realm REALM           Realm to export (default: StackV).
  --output-dir DIRECTORY  Local destination (default: ./keycloak/bin/dumps/<realm>-<timestamp>).
  --storage-class CLASS   Temporary export PVC storage class (default: local-path).
  --storage-size SIZE     Temporary export PVC size (default: 256Mi).
  -h, --help              Show this help message.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

while (($# > 0)); do
  case "$1" in
    --context)
      (($# >= 2)) || die "--context requires a value"
      CONTEXT="$2"
      shift 2
      ;;
    --namespace)
      (($# >= 2)) || die "--namespace requires a value"
      NAMESPACE="$2"
      shift 2
      ;;
    --realm)
      (($# >= 2)) || die "--realm requires a value"
      REALM="$2"
      shift 2
      ;;
    --output-dir)
      (($# >= 2)) || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --storage-class)
      (($# >= 2)) || die "--storage-class requires a value"
      STORAGE_CLASS="$2"
      shift 2
      ;;
    --storage-size)
      (($# >= 2)) || die "--storage-size requires a value"
      STORAGE_SIZE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
done

[[ -n "$CONTEXT" ]] || die "--context is required"
command -v kubectl >/dev/null 2>&1 || die "kubectl is required"
command -v envsubst >/dev/null 2>&1 || die "envsubst is required"

readonly STAMP="$(date -u +%Y%m%dt%H%M%Sz)-${RANDOM}"
readonly EXPORT_JOB_NAME="keycloak-realm-export-${STAMP}"
readonly EXPORT_PVC_NAME="keycloak-realm-export-${STAMP}"
readonly EXPORT_READER_NAME="keycloak-realm-reader-${STAMP}"

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${SCRIPT_DIR}/../dumps/${REALM}-${STAMP}"
fi

[[ ! -e "$OUTPUT_DIR" ]] || die "output path already exists: $OUTPUT_DIR"

kubectl_cmd() {
  kubectl --context "$CONTEXT" --namespace "$NAMESPACE" "$@"
}

render_template() {
  local template="$1"
  local variables="$2"

  envsubst "$variables" < "$template"
}

wait_for_job_completion() {
  local deadline=$((SECONDS + 1800))
  local job_conditions

  while ((SECONDS < deadline)); do
    job_conditions="$(kubectl_cmd get "job/${EXPORT_JOB_NAME}" \
      -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}')"

    if [[ "$job_conditions" == *"Complete=True"* ]]; then
      return 0
    fi

    if [[ "$job_conditions" == *"Failed=True"* ]]; then
      die "realm export Job ${EXPORT_JOB_NAME} failed"
    fi

    sleep 5
  done

  die "timed out waiting for realm export Job ${EXPORT_JOB_NAME}"
}

keycloak_scaled_down=false
temporary_resources_created=false
export_succeeded=false

restore_keycloak() {
  if [[ "$keycloak_scaled_down" == true ]]; then
    info "Restoring ${KEYCLOAK_STATEFULSET} to ${ORIGINAL_REPLICAS} replica(s)."
    if kubectl_cmd scale "statefulset/${KEYCLOAK_STATEFULSET}" \
      --replicas="$ORIGINAL_REPLICAS" >/dev/null; then
      kubectl_cmd rollout status "statefulset/${KEYCLOAK_STATEFULSET}" --timeout=10m || \
        printf 'warning: %s did not become ready after restoration\n' "$KEYCLOAK_STATEFULSET" >&2
    else
      printf 'warning: unable to restore %s automatically\n' "$KEYCLOAK_STATEFULSET" >&2
    fi
  fi

  if [[ "$temporary_resources_created" == true && "$export_succeeded" != true ]]; then
    printf 'warning: temporary export resources may remain in namespace %s\n' "$NAMESPACE" >&2
  fi
}

trap restore_keycloak EXIT

KEYCLOAK_IMAGE="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
ORIGINAL_REPLICAS="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.replicas}')"
KEYCLOAK_IMAGE_PULL_SECRET_NAMES="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{range .spec.template.spec.imagePullSecrets[*]}{.name}{"\n"}{end}')"
KEYCLOAK_DB_HOST="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_URL_HOST")].value}')"
KEYCLOAK_DB_PORT="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_URL_PORT")].value}')"
KEYCLOAK_DB_NAME="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_URL_DATABASE")].value}')"
KEYCLOAK_DB_USER="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_USERNAME")].value}')"
KEYCLOAK_DB_USER="${KEYCLOAK_DB_USER:-keycloak}"
KEYCLOAK_DB_SECRET_NAME="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_PASSWORD")].valueFrom.secretKeyRef.name}')"
KEYCLOAK_DB_SECRET_KEY="$(kubectl_cmd get "statefulset/${KEYCLOAK_STATEFULSET}" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="KC_DB_PASSWORD")].valueFrom.secretKeyRef.key}')"

[[ -n "$KEYCLOAK_IMAGE" ]] || die "could not read the Keycloak image"
[[ "$ORIGINAL_REPLICAS" =~ ^[0-9]+$ ]] || die "could not read the Keycloak replica count"
[[ -n "$KEYCLOAK_DB_HOST" ]] || die "could not read KC_DB_URL_HOST"
[[ -n "$KEYCLOAK_DB_PORT" ]] || die "could not read KC_DB_URL_PORT"
[[ -n "$KEYCLOAK_DB_NAME" ]] || die "could not read KC_DB_URL_DATABASE"
[[ -n "$KEYCLOAK_DB_SECRET_NAME" ]] || die "could not read the Keycloak database secret reference"
[[ -n "$KEYCLOAK_DB_SECRET_KEY" ]] || die "could not read the Keycloak database secret key"

readonly KEYCLOAK_IMAGE
readonly ORIGINAL_REPLICAS
readonly KEYCLOAK_DB_HOST
readonly KEYCLOAK_DB_PORT
readonly KEYCLOAK_DB_NAME
readonly KEYCLOAK_DB_USER
readonly KEYCLOAK_DB_SECRET_NAME
readonly KEYCLOAK_DB_SECRET_KEY
readonly KEYCLOAK_REALM="$REALM"
readonly EXPORT_STORAGE_CLASS="$STORAGE_CLASS"
readonly EXPORT_STORAGE_SIZE="$STORAGE_SIZE"
readonly OUTPUT_DIR

KEYCLOAK_IMAGE_PULL_SECRETS="["
image_pull_secret_separator=""
while IFS= read -r image_pull_secret; do
  [[ -n "$image_pull_secret" ]] || continue
  KEYCLOAK_IMAGE_PULL_SECRETS+="${image_pull_secret_separator}{\"name\": \"${image_pull_secret}\"}"
  image_pull_secret_separator=", "
done <<< "$KEYCLOAK_IMAGE_PULL_SECRET_NAMES"
KEYCLOAK_IMAGE_PULL_SECRETS+="]"
readonly KEYCLOAK_IMAGE_PULL_SECRETS

export EXPORT_JOB_NAME
export EXPORT_PVC_NAME
export EXPORT_READER_NAME
export KEYCLOAK_IMAGE
export KEYCLOAK_IMAGE_PULL_SECRETS
export KEYCLOAK_DB_HOST
export KEYCLOAK_DB_PORT
export KEYCLOAK_DB_NAME
export KEYCLOAK_DB_USER
export KEYCLOAK_DB_SECRET_NAME
export KEYCLOAK_DB_SECRET_KEY
export KEYCLOAK_REALM
export EXPORT_STORAGE_CLASS
export EXPORT_STORAGE_SIZE

info "Scaling ${KEYCLOAK_STATEFULSET} to zero for a consistent realm export."
if ((ORIGINAL_REPLICAS > 0)); then
  keycloak_scaled_down=true
fi
kubectl_cmd scale "statefulset/${KEYCLOAK_STATEFULSET}" --replicas=0

for ((ordinal = 0; ordinal < ORIGINAL_REPLICAS; ordinal++)); do
  kubectl_cmd wait --for=delete "pod/${KEYCLOAK_STATEFULSET}-${ordinal}" --timeout=5m
done

umask 077
mkdir -p "$OUTPUT_DIR"

render_template "$SCRIPT_DIR/realm-export-pvc.yaml" \
  '${EXPORT_PVC_NAME} ${EXPORT_STORAGE_CLASS} ${EXPORT_STORAGE_SIZE}' | \
  kubectl_cmd apply -f -
temporary_resources_created=true

render_template "$SCRIPT_DIR/realm-export-job.yaml" \
  '${EXPORT_JOB_NAME} ${EXPORT_PVC_NAME} ${KEYCLOAK_IMAGE} ${KEYCLOAK_IMAGE_PULL_SECRETS} ${KEYCLOAK_REALM} ${KEYCLOAK_DB_HOST} ${KEYCLOAK_DB_PORT} ${KEYCLOAK_DB_NAME} ${KEYCLOAK_DB_USER} ${KEYCLOAK_DB_SECRET_NAME} ${KEYCLOAK_DB_SECRET_KEY}' | \
  kubectl_cmd apply -f -
wait_for_job_completion

EXPORT_JOB_POD="$(kubectl_cmd get pods -l "job-name=${EXPORT_JOB_NAME}" \
  -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$EXPORT_JOB_POD" ]] || die "could not find the completed realm export Pod"
kubectl_cmd delete "job/${EXPORT_JOB_NAME}" --cascade=foreground --wait=true
kubectl_cmd wait --for=delete "pod/${EXPORT_JOB_POD}" --timeout=2m

render_template "$SCRIPT_DIR/realm-export-reader.yaml" \
  '${EXPORT_READER_NAME} ${EXPORT_PVC_NAME}' | \
  kubectl_cmd apply -f -
kubectl_cmd wait --for=condition=Ready "pod/${EXPORT_READER_NAME}" --timeout=2m
kubectl_cmd cp "${EXPORT_READER_NAME}:/export/." "$OUTPUT_DIR/"
chmod -R go-rwx "$OUTPUT_DIR"

kubectl_cmd delete "pod/${EXPORT_READER_NAME}" --wait=true
kubectl_cmd delete "pvc/${EXPORT_PVC_NAME}"

kubectl_cmd scale "statefulset/${KEYCLOAK_STATEFULSET}" --replicas="$ORIGINAL_REPLICAS"
kubectl_cmd rollout status "statefulset/${KEYCLOAK_STATEFULSET}" --timeout=10m

keycloak_scaled_down=false
export_succeeded=true
trap - EXIT

info "Realm export copied to ${OUTPUT_DIR}"
