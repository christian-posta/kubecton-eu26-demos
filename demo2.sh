#!/usr/bin/env bash
# Demo 2: MCP Authorization — paced terminal walkthrough (Kubecon EU 2026).
# Uses util.sh (pv “self-typing”). See README.md § Demo 2.
#
# Prerequisites: bash, pv, curl, jq, npx (Node), arctl, kubectl; .env with SSO
#   vars for the Agent Gateway section (loaded silently — not typed). Optional:
#   DEMO_RUN_FAST=1 for quick replay, DEMO_AUTO_RUN=1 to skip pauses between steps.

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=util.sh
. "${DEMO_ROOT}/util.sh"

# Silent: project .env (SSO / AGW URLs for arctl and ${AGENTGATEWAY_SSO_PUBLIC_BASE_URL} in later steps)
if [ -f "${DEMO_ROOT}/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "${DEMO_ROOT}/.env"
    set +a
fi

GITHUB_MCP_URL="https://api.githubcopilot.com/mcp"
GITLAB_AUTH_METADATA_URL="https://gitlab.com/.well-known/oauth-authorization-server/api/v4/mcp"

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

banner "Your Agent Gateway: SSO deploy preview, apply, then the same discovery flow on your URL"

desc "Dry-run: Kubernetes manifests for Agent Gateway + MCP server with --sso"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway agentgateway --gateway-namespace agentgateway-system --sso --dry-run"

desc "Apply the rendered manifests (pipe dry-run into kubectl apply)"
run "arctl mcp deploy agentgateway dev.servereverything/server --gateway agentgateway --gateway-namespace agentgateway-system --sso --dry-run | kubectl apply -f -"

desc "Inspector against your published MCP URL — without a JWT you should see unauthorized (as in README)"
run "npx @modelcontextprotocol/inspector --cli \${AGENTGATEWAY_SSO_PUBLIC_BASE_URL}/server/mcp --transport http --method tools/list"

demo_top

desc "401 from your gateway — check WWW-Authenticate and resource_metadata"
run "curl -I \${AGENTGATEWAY_SSO_PUBLIC_BASE_URL}/server/mcp"

desc "Protected resource metadata for your MCP route"
run "curl -s \${AGENTGATEWAY_SSO_PUBLIC_BASE_URL}/.well-known/oauth-protected-resource/server/mcp | jq"

desc "Authorization server metadata (enterprise IdP / Auth0 integration)"
run "curl -s \${AGENTGATEWAY_SSO_PUBLIC_BASE_URL}/.well-known/oauth-authorization-server/server/mcp | jq"

banner "Next: complete OAuth in VS Code (or your client) using this metadata — README Demo 2 closing note"

desc "Done. Optional cleanup is in README (kubectl delete / arctl mcp delete / VS Code credentials)."
if [ -z "${DEMO_AUTO_RUN:-}" ]; then
    read -s -r -n 1
fi
