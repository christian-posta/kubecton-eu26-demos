#!/usr/bin/env bash
# Demo 2: MCP Authorization — paced terminal walkthrough (Kubecon EU 2026).
# Uses util.sh (pv “self-typing”). See README.md § Demo 2.
#
# Prerequisites: bash, pv, curl, jq, npx (Node), arctl, kubectl; .env with SSO
#   vars for arctl --sso (loaded silently). After apply, kubectl port-forward runs in
#   the background (like demo1); EXIT tears it down before your shell is idle again.
#   Gateway HTTP calls use AGENTGATEWAY_SSO_PUBLIC_BASE_URL from .env (e.g. https://….ngrok.io)
#   when set; otherwise http://127.0.0.1:$PORT_FORWARD_LOCAL. Point ngrok at that local port.
# Optional: DEMO_RUN_FAST=1, DEMO_AUTO_RUN=1; AGW_NAMESPACE, AGW_SERVICE,
#   PORT_FORWARD_LOCAL, PORT_FORWARD_REMOTE.

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=util.sh
. "${DEMO_ROOT}/util.sh"

# Silent: project .env (SSO for arctl --sso)
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

GATEWAY_PUBLIC_BASE="${AGENTGATEWAY_SSO_PUBLIC_BASE_URL:-http://127.0.0.1:${PF_LOCAL}}"
GATEWAY_PUBLIC_BASE="${GATEWAY_PUBLIC_BASE%/}"

GITHUB_MCP_URL="https://api.githubcopilot.com/mcp"
GITLAB_AUTH_METADATA_URL="https://gitlab.com/.well-known/oauth-authorization-server/api/v4/mcp"

PF_PID=""
PF_LOG=""

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

banner() {
    echo ""
    echo "${blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
    desc "$1"
}

banner "Demo 2 — MCP Authorization: real endpoints advertise OAuth (401 + metadata)"

desc "Call GitHub’s MCP without a token — the inspector uses HTTP; expect auth-related failure or empty tools."
run "npx @modelcontextprotocol/inspector --cli ${GITHUB_MCP_URL} --transport http --method tools/list"

demo_top

banner "Unauthenticated HTTP: GitHub Copilot MCP returns 401 and points at resource + authorization metadata"

desc "Headers only — note WWW-Authenticate and resource_metadata URL"
run "curl -I ${GITHUB_MCP_URL}"

desc "OAuth Protected Resource metadata (RFC 9728-style) for the MCP resource"
run "curl -s https://api.githubcopilot.com/.well-known/oauth-protected-resource/mcp | jq"

desc "Authorization server metadata for GitHub’s OAuth — where clients discover endpoints"
run "curl -s https://github.com/.well-known/oauth-authorization-server/login/oauth | jq"

banner "Contrast: GitLab exposes MCP-oriented AS metadata (and registration story differs from GitHub)"

desc "GitLab authorization server metadata for the MCP API — compare with GitHub’s document"
run "curl -s ${GITLAB_AUTH_METADATA_URL} | jq"

demo_top

banner "Your Agent Gateway: SSO deploy preview, apply, then the same discovery flow on your URL"

desc "Dry-run: Kubernetes manifests for Agent Gateway + MCP server with --sso"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway ${AGW_SVC} --gateway-namespace ${AGW_NS} --sso --dry-run"

desc "Apply the rendered manifests (pipe dry-run into kubectl apply)"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway ${AGW_SVC} --gateway-namespace ${AGW_NS} --sso --dry-run | kubectl apply -f -"

desc "Port-forward in background: 127.0.0.1:${PF_LOCAL} → svc/${AGW_SVC}:${PF_REMOTE} (ngrok should target this port; only prints if PF fails)"
if ! start_agentgateway_port_forward; then
    desc "Fix port-forward (free port ${PF_LOCAL}, kube context, or service name), then re-run from here."
    exit 1
fi

desc "Inspector via public gateway URL from .env (e.g. ngrok); without a JWT expect unauthorized (README)"
run "npx @modelcontextprotocol/inspector --cli ${GATEWAY_PUBLIC_BASE}/server/mcp --transport http --method tools/list"

demo_top

desc "401 from your gateway — check WWW-Authenticate and resource_metadata"
run "curl -I ${GATEWAY_PUBLIC_BASE}/server/mcp"

banner "Next: complete OAuth in VS Code or MCP Insepctor using this metadata — README Demo 2 closing note"

desc "Done. Port-forward stops on exit. Optional cleanup is in README (kubectl delete / arctl mcp delete / VS Code credentials)."
desc "Go to mcp-inspector UI and try to connect with client id F7LkCRyHuobrBLSiOtnk3LwH7o8eRP8l"
if [ -z "${DEMO_AUTO_RUN:-}" ]; then
    read -s -r -n 1
fi
