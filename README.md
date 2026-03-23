# Kubecon EU 2026 Demos

Wednesday March 25, 2026 15:00 - 15:30 CET
3:00-3:30pm (30 mins talk)
Hall 7 | Room C

https://kccnceu2026.sched.com/event/2CW8C/enterprise-challenges-with-mcp-adoption-christian-posta-soloio


**Enterprise Challenges with MCP Adoption**


Abstract:

The Model Context Protocol specifies how MCP servers expose tools, data, and workflows to agents. The spec was written in terms of single tenant, desktop based use cases. Enterprises need to move beyond this definition of and begin building “MCP services”: secure, remotely accessible, multi-tenant, governed services that expose sensitive business capabilities to AI agents.

In this talk, I'll highlight three challenges that arise:
- Onboarding & Discovery: How do you register, approve and safely expose MCP services while defending against tool poisoning and shadow services?

- Authorization & Identity: How much of the MCP Authorization spec can be adopted when most IdPs don’t support the RFCs it assumes? What’s the gap between the spec’s design for public SaaS and the reality of enterprise SSO, policy engines, and workload identity?

- Upstream Access & Consent: Once an MCP service needs to call enterprise APIs on behalf of a user, how do we govern delegation and prevent credential misuse?

## Demo 1: AI Agent Registry / MCP Onboarding

Using `ceposta-main` branch: [https://github.com/christian-posta/agentregistry/tree/ceposta-main](https://github.com/christian-posta/agentregistry/blob/ceposta-main/simple-demo.md#kubecon-demo)

Source of notes here: [Kubecon Demo](https://github.com/christian-posta/agentregistry/blob/ceposta-main/simple-demo.md)


1. Start AgentRegistry as described in [simple demo](https://github.com/christian-posta/agentregistry/blob/ceposta-main/simple-demo.md)

NOTE: we should `source .env` because that has the SSO configs. 

UI will be on http://localhost:12121

2. We will add an MCP server from the UI: `https://servereverything.dev/mcp` as `streamable-http`

Can check what it has:

```bash
npx @modelcontextprotocol/inspector --cli https://servereverything.dev/mcp --transport http --method tools/list
```

3. We can explore the UI a little, add servereverything to the registry. 

show how we can generate k8s resources to deploy agentgateway


4. From the CLI we can search for the servereverything:

```bash
arctl mcp list --type streamable-http --all | grep everything
```

Preview resources:

```bash
arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --dry-run
```

Let's deploy it and test that we can reach it from an MCP client:

```bash
arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --dry-run | kubectl apply -f -
```

Make sure agentgateway is port forwarded to port `3000`

```bash
npx @modelcontextprotocol/inspector --cli https://ceposta-agw.ngrok.io/server/mcp --transport http --method tools/list
```

## Demo 2: MCP Authorization

```bash
npx @modelcontextprotocol/inspector --cli https://api.githubcopilot.com/mcp --transport http --method tools/list
```

```bash
curl -I https://api.githubcopilot.com/mcp


HTTP/2 401 
content-security-policy: default-src 'none'; sandbox
content-type: text/plain; charset=utf-8
strict-transport-security: max-age=31536000
www-authenticate: Bearer error="invalid_request", error_description="No access token was provided in this request", resource_metadata="https://api.githubcopilot.com/.well-known/oauth-protected-resource/mcp"
x-content-type-options: nosniff
date: Fri, 20 Mar 2026 17:30:20 GMT
content-length: 51
x-github-backend: Kubernetes
x-github-request-id: F673:5A9D6:8BE024:9AFA3A:69BD842C
```

```bash
curl -s https://api.githubcopilot.com/.well-known/oauth-protected-resource/mcp | jq

{
  "resource": "https://api.githubcopilot.com/mcp",
  "authorization_servers": [
    "https://github.com/login/oauth"
  ],
  "scopes_supported": [
    "repo",
    "read:org",
    "read:user",
    "user:email",
    "read:packages",
    "write:packages",
    "read:project",
    "project",
    "gist",
    "notifications",
    "workflow",
    "codespace"
  ],
  "bearer_methods_supported": [
    "header"
  ],
  "resource_name": "GitHub MCP Server"
}
```

```bash
curl -s https://github.com/.well-known/oauth-authorization-server/login/oauth | jq

{
  "issuer": "https://github.com/login/oauth",
  "authorization_endpoint": "https://github.com/login/oauth/authorize",
  "token_endpoint": "https://github.com/login/oauth/access_token",
  "response_types_supported": [
    "code"
  ],
  "grant_types_supported": [
    "authorization_code",
    "refresh_token"
  ],
  "service_documentation": "https://docs.github.com/apps/creating-github-apps/registering-a-github-app/registering-a-github-app",
  "code_challenge_methods_supported": [
    "S256"
  ]
}
```

NOTE there is no registration endpoint!! Unlike, for example GitLAB <- LAB... GitLab!!

```bash
curl -s https://gitlab.com/.well-known/oauth-authorization-server/api/v4/mcp | jq
```

For the SSO stuff, you need 

```bash
set -a && source .env && set +a  

arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --sso \
  --dry-run
```


Let's go ahead and apply this:

```bash
set -a && source .env && set +a  

arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --sso \
  --dry-run | kubectl apply -f -
```

```bash
npx @modelcontextprotocol/inspector --cli https://ceposta-agw.ngrok.io/server/mcp --transport http --method tools/list

Failed to connect to MCP server: Streamable HTTP error: Error POSTing to endpoint: {"error":"unauthorized","error_description":"JWT token required"}
```

```bash
curl -I https://ceposta-agw.ngrok.io/server/mcp

HTTP/2 401 
content-type: application/json
date: Fri, 20 Mar 2026 17:47:20 GMT
www-authenticate: Bearer resource_metadata="https://ceposta-agw.ngrok.io/.well-known/oauth-protected-resource/server/mcp"
content-length: 65
```

```bash
curl -s https://ceposta-agw.ngrok.io/.well-known/oauth-protected-resource/server/mcp | jq

{
  "resource": "https://ceposta-agw.ngrok.io/server/mcp",
  "authorization_servers": [
    "https://ceposta-agw.ngrok.io/server/mcp"
  ],
  "mcp_protocol_version": "2025-06-18",
  "resource_type": "mcp-server",
  "bearer_methods_supported": [
    "header",
    "body",
    "query"
  ],
  "resource_documentation": "https://ceposta-agw.ngrok.io/server/mcp/docs",
  "resource_policy_uri": "https://ceposta-agw.ngrok.io/server/mcp/policies",
  "scopes_supported": [
    "profile",
    "openid",
    "offline_access"
  ]
}
```

```bash
curl -s https://ceposta-agw.ngrok.io/.well-known/oauth-authorization-server/server/mcp | jq

{
  "issuer": "https://ceposta-solo.auth0.com/",
  "authorization_endpoint": "https://ceposta-solo.auth0.com/authorize?audience=https://ceposta-agw.ngrok.io/mcp",
  "token_endpoint": "https://ceposta-solo.auth0.com/oauth/token",
  "device_authorization_endpoint": "https://ceposta-solo.auth0.com/oauth/device/code",
  "userinfo_endpoint": "https://ceposta-solo.auth0.com/userinfo",
  "mfa_challenge_endpoint": "https://ceposta-solo.auth0.com/mfa/challenge",
  "jwks_uri": "https://ceposta-solo.auth0.com/.well-known/jwks.json",
  "registration_endpoint": "https://ceposta-solo.auth0.com/oidc/register",
  "revocation_endpoint": "https://ceposta-solo.auth0.com/oauth/revoke",
  "scopes_supported": [
    "openid",
    "profile",
    "offline_access",
    "name",
    "given_name",
    "family_name",
    "nickname",
    "email",
    "email_verified",
    "picture",
    "created_at",
    "identities",
    "phone",
    "address"
  ],
  "response_types_supported": [
    "code",
    "token",
    "id_token",
    "code token",
    "code id_token",
    "token id_token",
    "code token id_token"
  ],
  "code_challenge_methods_supported": [
    "S256",
    "plain"
  ],
  "response_modes_supported": [
    "query",
    "fragment",
    "form_post"
  ],
  "subject_types_supported": [
    "public"
  ],
  "token_endpoint_auth_methods_supported": [
    "client_secret_basic",
    "client_secret_post",
    "private_key_jwt"
  ],
  "token_endpoint_auth_signing_alg_values_supported": [
    "RS256",
    "RS384",
    "PS256"
  ],
  "claims_supported": [
    "aud",
    "auth_time",
    "created_at",
    "email",
    "email_verified",
    "exp",
    "family_name",
    "given_name",
    "iat",
    "identities",
    "iss",
    "name",
    "nickname",
    "phone_number",
    "picture",
    "sub"
  ],
  "request_uri_parameter_supported": false,
  "request_parameter_supported": false,
  "id_token_signing_alg_values_supported": [
    "HS256",
    "RS256",
    "PS256"
  ],
  "global_token_revocation_endpoint": "https://ceposta-solo.auth0.com/oauth/global-token-revocation/connection/{connectionName}",
  "global_token_revocation_endpoint_auth_methods_supported": [
    "global-token-revocation+jwt"
  ],
  "dpop_signing_alg_values_supported": [
    "ES256"
  ]
}
```

Now we are connected over Enterprise SSO (Auth0!)

From here we can try to connect from VS code. 


## Cleanup

Delete agentgateway resources for servereverything

```bash
set -a && source .env && set +a  

arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --sso \
  --dry-run | kubectl delete -f -
```

Delete servereverything from the registry:

```bash
./bin/arctl mcp delete dev.servereverything/server --version 1.0.0
```

Manually clear the VS code credentials.
