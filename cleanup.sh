#!/usr/bin/env bash
# Tear down Kubecon demo resources per README.md § Cleanup.
# - Agent Gateway objects for dev.servereverything/server (non-SSO and SSO manifests)
# - Registry MCP package entry
#
# Usage: ./cleanup.sh
# Env:   ARCTL (default: arctl, or repo ./bin/arctl if executable)
#        CLEANUP_MCP_ID (default: dev.servereverything/server)
#        CLEANUP_MCP_VERSION (default: 1.0.0)
#        AGW_GATEWAY (default: agentgateway)
#        AGW_NAMESPACE (default: agentgateway-system)
#
# Clear VS Code MCP / OAuth credentials manually if you used them.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -x "${ROOT}/bin/arctl" ]; then
    ARCTL="${ARCTL:-${ROOT}/bin/arctl}"
else
    ARCTL="${ARCTL:-arctl}"
fi

if [ ! -f "${ROOT}/.env" ]; then
    echo "Warning: no ${ROOT}/.env — SSO-oriented arctl dry-run may fail; continuing." >&2
else
    set -a
    # shellcheck disable=SC1091
    . "${ROOT}/.env"
    set +a
fi

GATEWAY="${AGW_GATEWAY:-agentgateway}"
GATEWAY_NS="${AGW_NAMESPACE:-agentgateway-system}"
MCP_ID="${CLEANUP_MCP_ID:-dev.servereverything/server}"
MCP_VERSION="${CLEANUP_MCP_VERSION:-1.0.0}"

kubectl_delete_manifest() {
    local tmp
    tmp="$(mktemp)"
    if "$ARCTL" mcp deploy agentgateway "${MCP_ID}" \
        --gateway "${GATEWAY}" \
        --gateway-namespace "${GATEWAY_NS}" \
        "$@" \
        --dry-run >"${tmp}" 2>/dev/null; then
        kubectl delete -f "${tmp}" --ignore-not-found=true
    else
        echo "Note: arctl dry-run failed for args: $* (skipping this kubectl delete)." >&2
    fi
    rm -f "${tmp}"
}

echo "== Deleting Agent Gateway Kubernetes resources for ${MCP_ID} =="
echo "-- Manifest without --sso (Demo 1 style)"
kubectl_delete_manifest

echo "-- Manifest with --sso (README / Demo 2 style)"
kubectl_delete_manifest --sso

echo ""
echo "== Deleting registry entry ${MCP_ID} version ${MCP_VERSION} =="
if "$ARCTL" mcp delete "${MCP_ID}" --version "${MCP_VERSION}"; then
    echo "Registry delete completed."
else
    echo "Registry delete failed or entry already removed (check arctl output above)." >&2
fi

echo ""
echo "Done. If you connected from VS Code, clear stored MCP / OAuth credentials there manually."
