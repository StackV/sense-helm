#!/usr/bin/env bash
#
# Repeatable validation install for the SENSE Orchestrator chart.
#
#   ./bin/install.sh                     # tear down, install, wait, report
#   ./bin/install.sh --tag mybranch      # override image.tag for this run
#   ./bin/install.sh --dry-run           # server-side dry run, changes nothing
#   ./bin/install.sh --keep              # upgrade in place, no teardown
#   ./bin/install.sh --values other.yaml   # use a different override file
#   ./bin/install.sh --allow-host-conflict # install even if the ingress host is taken
#
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RELEASE="sense-validate"
VALUES_FILE="${CHART_DIR}/validation.values.yaml"
TIMEOUT="15m"
IMAGE_TAG=""
DRY_RUN=false
KEEP=false
ASSUME_YES=false
ALLOW_HOST_CONFLICT=false

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)   RELEASE="$2"; shift 2 ;;
    --values|-f) VALUES_FILE="$2"; shift 2 ;;
    --tag)       IMAGE_TAG="$2"; shift 2 ;;
    --timeout)   TIMEOUT="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --keep)      KEEP=true; shift ;;
    --yes|-y)    ASSUME_YES=true; shift ;;
    --allow-host-conflict) ALLOW_HOST_CONFLICT=true; shift ;;
    # Print the leading comment block, whatever length it happens to be.
    -h|--help)   awk 'NR>2 && /^#/ {sub(/^# ?/, ""); print; next} NR>2 {exit}' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)           die "unknown argument: $1" ;;
  esac
done

command -v helm    >/dev/null || die "helm not found on PATH"
command -v kubectl >/dev/null || die "kubectl not found on PATH"
[[ -f "$VALUES_FILE" ]] || die "values file not found: $VALUES_FILE"

HELM_SET=()
[[ -n "$IMAGE_TAG" ]] && HELM_SET+=(--set "image.tag=${IMAGE_TAG}")

# Render once and drive everything below off what would actually be deployed, rather than
# re-deriving resource names from values. Also catches template errors before we touch
# the cluster.
info "Rendering chart"
MANIFEST="$(helm template "$RELEASE" "$CHART_DIR" -f "$VALUES_FILE" ${HELM_SET[@]+"${HELM_SET[@]}"})" \
  || die "chart failed to render"

NAMESPACE="$(awk '/^  namespace:/ {gsub(/"/, "", $2); print $2; exit}' <<<"$MANIFEST")"
[[ -n "$NAMESPACE" ]] || die "could not determine namespace from rendered chart"

STATEFULSETS=()
PVCS=()
SECRET_KEYS=()
while IFS= read -r line; do [[ -n "$line" ]] && STATEFULSETS+=("$line"); done \
  < <(awk '/^kind: StatefulSet/ {f=1} f && /^  name:/ {print $2; f=0}' <<<"$MANIFEST")
while IFS= read -r line; do [[ -n "$line" ]] && PVCS+=("$line"); done \
  < <(awk '/^kind: PersistentVolumeClaim/ {f=1} f && /^  name:/ {print $2; f=0}' <<<"$MANIFEST")
# Collect "secret/key" pairs, not just secret names — see the preflight below.
while IFS= read -r line; do [[ -n "$line" ]] && SECRET_KEYS+=("$line"); done \
  < <(awk '
      /secretKeyRef:/ {f=1; n=""; k=""; next}
      f && /^[[:space:]]*name:/ {gsub(/"/, "", $2); n=$2}
      f && /^[[:space:]]*key:/  {gsub(/"/, "", $2); k=$2}
      f && n != "" && k != ""   {print n"/"k; f=0; n=""; k=""}' <<<"$MANIFEST" | sort -u)

INGRESS_HOSTS=()
while IFS= read -r line; do [[ -n "$line" ]] && INGRESS_HOSTS+=("$line"); done \
  < <(awk '/^kind: Ingress/ {f=1} /^---/ {f=0} f && /^[[:space:]]*- host:/ {print $3}' <<<"$MANIFEST" | sort -u)
OUR_INGRESS="$(awk '/^kind: Ingress/ {f=1} /^---/ {f=0} f && /^  name:/ {print $2; exit}' <<<"$MANIFEST")"

CERT_NAME="$(awk   '/^kind: Certificate/ {f=1} /^---/ {f=0} f && /^  name:/ {print $2; exit}' <<<"$MANIFEST")"
ISSUER_KIND="$(awk '/issuerRef:/ {f=1} f && /kind:/ {print $2; exit}' <<<"$MANIFEST")"
ISSUER_NAME="$(awk '/issuerRef:/ {f=1} f && /name:/ {print $2; exit}' <<<"$MANIFEST")"

ORCH_STS="$(printf '%s\n' ${STATEFULSETS[@]+"${STATEFULSETS[@]}"} | grep -- '-orch$'  || true)"
MYSQL_STS="$(printf '%s\n' ${STATEFULSETS[@]+"${STATEFULSETS[@]}"} | grep -- '-mysql$' || true)"
INIT_CONTAINER="${ORCH_STS}-db-init"

# --- Guard rails -------------------------------------------------------------------
# Teardown is destructive, so refuse to run it against anything not explicitly marked as
# a scratch install. `global.mode: test` is what the validation override sets.
if [[ "$KEEP" == false && "$DRY_RUN" == false ]]; then
  grep -Eq '^[[:space:]]*mode:[[:space:]]*test[[:space:]]*$' "$VALUES_FILE" \
    || die "$(basename "$VALUES_FILE") does not set 'global.mode: test'; refusing to uninstall. Use --keep to upgrade in place."
fi

if [[ "$DRY_RUN" == true ]]; then MODE_DESC="server dry-run"
elif [[ "$KEEP" == true ]];   then MODE_DESC="upgrade in place"
else                               MODE_DESC="TEARDOWN + fresh install"
fi

cat <<SUMMARY

  context    $(kubectl config current-context)
  namespace  ${NAMESPACE}
  release    ${RELEASE}
  values     $(basename "$VALUES_FILE")
  tag        ${IMAGE_TAG:-<from values>}
  mode       ${MODE_DESC}

SUMMARY

if [[ "$DRY_RUN" == false && "$ASSUME_YES" == false ]]; then
  [[ -t 0 ]] || die "not a TTY; pass --yes to run non-interactively"
  read -r -p "Proceed? [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }
fi

# --- Dry run -----------------------------------------------------------------------
if [[ "$DRY_RUN" == true ]]; then
  info "Server-side dry run"
  # helm 3.10 has no --dry-run=server, so validate through kubectl. Resources helm already
  # created lack the last-applied-configuration annotation, which is loud and harmless here.
  if ! dry_out="$(kubectl apply --dry-run=server -n "$NAMESPACE" -f - <<<"$MANIFEST" 2>&1)"; then
    printf '%s\n' "$dry_out" >&2
    die "server dry run failed"
  fi
  printf '%s\n' "$dry_out" | grep -v 'last-applied-configuration annotation' || true
  exit 0
fi

# --- Preflight ---------------------------------------------------------------------
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || info "Namespace ${NAMESPACE} will be created"

# Check the individual keys, not just that the secret objects exist. A secret that is
# present but missing a key fails at container *creation*, which the kubelet retries
# forever with backoff. `helm --wait` cannot tell that apart from a slow start, so it
# blocks for the full timeout on a pod that can never become ready.
pairs() { printf '%s\n' ${SECRET_KEYS[@]+"${SECRET_KEYS[@]}"}; }

missing=""
for secret in $(pairs | cut -d/ -f1 | sort -u); do
  if ! actual="$(kubectl get secret "$secret" -n "$NAMESPACE" \
                 -o go-template='{{range $k, $v := .data}}{{$k}} {{end}}' 2>/dev/null)"; then
    missing="${missing}
  ${secret} — secret not found"
    continue
  fi
  for key in $(pairs | grep "^${secret}/" | cut -d/ -f2); do
    case " ${actual} " in
      *" ${key} "*) ;;
      *) missing="${missing}
  ${secret} — missing key '${key}'" ;;
    esac
  done
done
if [[ -n "$missing" ]]; then
  die "prerequisite secret problems in namespace ${NAMESPACE}:${missing}

See bin/create_secrets.sh — note it passes no -n, so run it with '-n ${NAMESPACE}'."
fi
info "Prerequisite secrets verified ($(pairs | wc -l | tr -d ' ') keys across $(pairs | cut -d/ -f1 | sort -u | tr '\n' ' '))"

# Two Ingresses claiming one hostname on the same controller route nondeterministically, so
# a validation run can quietly hijack traffic from an unrelated deployment. Cert-manager
# will also race to issue a second certificate for the same name.
if (( ${#INGRESS_HOSTS[@]} )); then
  existing="$(kubectl get ingress -A -o go-template='{{range .items}}{{$ns := .metadata.namespace}}{{$n := .metadata.name}}{{range .spec.rules}}{{if .host}}{{$ns}}/{{$n}}|{{.host}}{{"\n"}}{{end}}{{end}}{{end}}' 2>/dev/null || true)"
  conflicts=""
  for host in "${INGRESS_HOSTS[@]}"; do
    while IFS= read -r row; do
      [[ -z "$row" ]] && continue
      owner="${row%%|*}"
      [[ "${row##*|}" == "$host" ]] || continue
      [[ "$owner" == "${NAMESPACE}/${OUR_INGRESS}" ]] && continue
      conflicts="${conflicts}
  ${host} — already claimed by ${owner}"
    done <<<"$existing"
  done
  if [[ -n "$conflicts" ]]; then
    if [[ "$ALLOW_HOST_CONFLICT" == true ]]; then
      warn "ingress hostname collision (proceeding anyway):${conflicts}"
    else
      die "ingress hostname collision:${conflicts}

Change global.domain (or ingress.hostname) in $(basename "$VALUES_FILE"), or pass
--allow-host-conflict to install over the top of it anyway."
    fi
  else
    info "Ingress hostnames unclaimed: ${INGRESS_HOSTS[*]}"
  fi
fi

# A Certificate whose issuer is absent stays pending forever. helm --wait does not gate on
# CRDs, so the install "succeeds" with no TLS — which would silently fail to validate the
# very cert-manager wiring this override exists to exercise. Warn rather than block, since
# the workload itself comes up fine either way.
if [[ -n "$CERT_NAME" && -n "$ISSUER_NAME" ]]; then
  issuer_args=("$(tr '[:upper:]' '[:lower:]' <<<"$ISSUER_KIND")" "$ISSUER_NAME")
  [[ "$ISSUER_KIND" == "Issuer" ]] && issuer_args+=(-n "$NAMESPACE")
  if ! issuer_ready="$(kubectl get "${issuer_args[@]}" \
       -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)"; then
    warn "${ISSUER_KIND}/${ISSUER_NAME} not found — Certificate ${CERT_NAME} will stay pending and no TLS will be issued"
  elif [[ "$issuer_ready" != "True" ]]; then
    warn "${ISSUER_KIND}/${ISSUER_NAME} is not Ready — Certificate ${CERT_NAME} may not issue"
  else
    info "Issuer ${ISSUER_KIND}/${ISSUER_NAME} is Ready"
  fi
fi

# --- Teardown ----------------------------------------------------------------------
if [[ "$KEEP" == false ]]; then
  if helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1; then
    info "Uninstalling existing release ${RELEASE}"
    helm uninstall "$RELEASE" -n "$NAMESPACE" --wait --timeout "$TIMEOUT"
  else
    info "No existing release to remove"
  fi

  # The chart annotates the MySQL PVC with helm.sh/resource-policy: keep, so that a
  # production uninstall cannot destroy the database. That means helm deliberately leaves
  # it behind, and a fresh validation run has to delete it explicitly — otherwise MySQL
  # starts on the previous datadir and the Flyway history from the last run is still there,
  # which is not a first-boot test at all.
  #
  # This destroys data. It is gated by the global.mode: test check above.
  for pvc in ${PVCS[@]+"${PVCS[@]}"}; do
    if kubectl get pvc "$pvc" -n "$NAMESPACE" >/dev/null 2>&1; then
      info "Deleting PVC ${pvc} (helm keeps it by policy; a fresh run needs it gone)"
      kubectl delete pvc "$pvc" -n "$NAMESPACE" --wait=true --timeout="$TIMEOUT" \
        || warn "could not delete PVC ${pvc}; MySQL may reuse the existing datadir"
    fi
  done
fi

# --- Install -----------------------------------------------------------------------
# Expect several minutes even on a healthy run: MySQL initializes an empty datadir, and the
# orchestrator's startup probe alone has a 180s initial delay before WildFly is even polled.
info "Installing ${RELEASE} (--wait; this takes several minutes)"
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$NAMESPACE" --create-namespace \
  -f "$VALUES_FILE" ${HELM_SET[@]+"${HELM_SET[@]}"} \
  --wait --timeout "$TIMEOUT" || {
    warn "helm reported failure; dumping migration init container logs"
    kubectl logs "${ORCH_STS}-0" -n "$NAMESPACE" -c "$INIT_CONTAINER" --tail=50 2>/dev/null || true
    die "install failed"
  }

# --- Report ------------------------------------------------------------------------
[[ -n "$MYSQL_STS" ]] && kubectl rollout status "statefulset/${MYSQL_STS}" -n "$NAMESPACE" --timeout "$TIMEOUT"
[[ -n "$ORCH_STS"  ]] && kubectl rollout status "statefulset/${ORCH_STS}"  -n "$NAMESPACE" --timeout "$TIMEOUT"

info "Flyway migration output"
kubectl logs "${ORCH_STS}-0" -n "$NAMESPACE" -c "$INIT_CONTAINER" --tail=30 2>/dev/null \
  || warn "could not read logs from ${INIT_CONTAINER}"

# Confirm the cert-manager path actually produced a certificate, and that it landed in the
# same secret the Ingress consumes — that pairing is one of the 2.0.0 fixes under test.
if [[ -n "$CERT_NAME" ]]; then
  info "Waiting for Certificate ${CERT_NAME} (ACME issuance, up to 90s)"
  if kubectl wait --for=condition=Ready "certificate/${CERT_NAME}" -n "$NAMESPACE" --timeout=90s >/dev/null 2>&1; then
    cert_secret="$(kubectl get "certificate/${CERT_NAME}" -n "$NAMESPACE" -o jsonpath='{.spec.secretName}' 2>/dev/null)"
    ingress_secret="$(kubectl get "ingress/${OUR_INGRESS}" -n "$NAMESPACE" -o jsonpath='{.spec.tls[0].secretName}' 2>/dev/null || true)"
    if [[ -n "$ingress_secret" && "$cert_secret" != "$ingress_secret" ]]; then
      warn "Certificate writes to '${cert_secret}' but the Ingress reads '${ingress_secret}' — TLS will not serve"
    else
      info "Certificate Ready, issued into '${cert_secret}' (matches Ingress)"
    fi
  else
    warn "Certificate ${CERT_NAME} not Ready yet; check with:
  kubectl describe certificate ${CERT_NAME} -n ${NAMESPACE}"
  fi
fi

info "Done. Pods:"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE}"
