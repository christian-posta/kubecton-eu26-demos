#!/usr/bin/env bash
# Demo 1: AI Agent Registry / MCP onboarding — paced walkthrough (Kubecon EU 2026).
# Assumes AgentRegistry is running; you register Server Everything in the UI when prompted,
# and you have arctl, kubectl, pv, npx, etc. See README.md § Demo 1.
# Loads .env and kubectl port-forward silently (no typed command); failures still print.
#
# Optional: DEMO_RUN_FAST=1, DEMO_AUTO_RUN=1 (same as util.sh).
# Override: AGW_NAMESPACE, AGW_SERVICE, PORT_FORWARD_LOCAL, PORT_FORWARD_REMOTE.

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=util.sh
. "${DEMO_ROOT}/util.sh"

# Silent: load project .env (not shown in the paced demo output)
if [ -f "${DEMO_ROOT}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${DEMO_ROOT}/.env"
    set +a
fi

AGW_NS="${AGW_NAMESPACE:-agentgateway-system}"
AGW_SVC="${AGW_SERVICE:-agentgateway}"
PF_LOCAL="${PORT_FORWARD_LOCAL:-3000}"
PF_REMOTE="${PORT_FORWARD_REMOTE:-8080}"
UPSTREAM_MCP_URL="https://servereverything.dev/mcp"
LOCAL_MCP_URL="http://127.0.0.1:${PF_LOCAL}/server/mcp"

PF_PID=""
PF_LOG=""

banner() {
    echo ""
    echo "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    desc "$1"
}

cleanup_port_forward() {
    if [ -n "${PF_PID:-}" ] && kill -0 "${PF_PID}" 2>/dev/null; then
        kill "${PF_PID}" 2>/dev/null || true
        wait "${PF_PID}" 2>/dev/null || true
    fi
    PF_PID=""
    if [ -n "${PF_LOG:-}" ] && [ -f "${PF_LOG}" ]; then
        rm -f "${PF_LOG}"
    fi
    PF_LOG=""
}

on_demo_exit() {
    cleanup_port_forward
    echo
}

trap on_demo_exit EXIT

# Starts kubectl port-forward; on success, logs are discarded (process keeps writing to unlinked file).
# On failure (port in use, RBAC, missing svc, etc.), prints the captured output.
start_agentgateway_port_forward() {
    PF_LOG=$(mktemp)
    kubectl port-forward -n "${AGW_NS}" "svc/${AGW_SVC}" "${PF_LOCAL}:${PF_REMOTE}" >>"${PF_LOG}" 2>&1 </dev/null &
    PF_PID=$!

    local i
    for i in {1..25}; do
        if ! kill -0 "${PF_PID}" 2>/dev/null; then
            echo "${yellow}--- kubectl port-forward exited (see output below) ---${reset}"
            cat "${PF_LOG}"
            cleanup_port_forward
            return 1
        fi
        if grep -qiE 'Unable to listen|address already in use|bind:.*in use|error forwarding|error:.*listen' "${PF_LOG}" 2>/dev/null; then
            echo "${yellow}--- Port-forward failed (e.g. port ${PF_LOCAL} in use) ---${reset}"
            cat "${PF_LOG}"
            kill "${PF_PID}" 2>/dev/null || true
            wait "${PF_PID}" 2>/dev/null || true
            cleanup_port_forward
            return 1
        fi
        if grep -q 'Forwarding from' "${PF_LOG}" 2>/dev/null; then
            rm -f "${PF_LOG}"
            PF_LOG=""
            return 0
        fi
        sleep 0.2
    done

    if kill -0 "${PF_PID}" 2>/dev/null; then
        rm -f "${PF_LOG}"
        PF_LOG=""
        return 0
    fi

    echo "${yellow}--- Port-forward did not stay running ---${reset}"
    cat "${PF_LOG}"
    cleanup_port_forward
    return 1
}

demo_top

banner "Demo 1 — Registry / MCP onboarding (UI at http://localhost:12121)"

desc "Call the upstream Server Everything MCP — same URL you will add in the registry UI"
run "npx @modelcontextprotocol/inspector --cli ${UPSTREAM_MCP_URL} --transport http --method tools/list"

demo_top

desc "Heads-up: open the registry UI and register ${UPSTREAM_MCP_URL} as streamable-http — press Enter when done."
if [ -z "${DEMO_AUTO_RUN:-}" ]; then
    read -r
fi

banner "CLI: confirm the published server is visible in the registry"

desc "Streamable HTTP MCP servers — filter for servereverything"
run "arctl mcp list --type streamable-http --all | grep everything"

banner "Generate Kubernetes manifests (dry-run) then deploy to Agent Gateway"

desc "Preview Agent Gateway + HTTPRoute / backend resources"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway ${AGW_SVC} --gateway-namespace ${AGW_NS} --dry-run"

desc "Apply rendered manifests to the cluster"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway ${AGW_SVC} --gateway-namespace ${AGW_NS} --dry-run | kubectl apply -f -"

desc "Port-forwarding the gateway to 127.0.0.1:${PF_LOCAL} in the background (only prints if it fails)"
if ! start_agentgateway_port_forward; then
    desc "Fix the issue above (free port ${PF_LOCAL}, kube context, or service name), then re-run this script."
    exit 1
fi

banner "Call the MCP through the gateway via local port-forward"

desc "Inspector against the gateway path published by arctl (HTTP on localhost)"
run "npx @modelcontextprotocol/inspector --cli ${LOCAL_MCP_URL} --transport http --method tools/list"

demo_top

desc "Done. Exiting stops the background port-forward."
if [ -z "${DEMO_AUTO_RUN:-}" ]; then
    read -s
fi
