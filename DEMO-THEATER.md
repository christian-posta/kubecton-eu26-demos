Databricks MCP server:

https://dbc-f1002050-7c6a.cloud.databricks.com/api/2.0/mcp/genie/01f0c67c0cda1eb5b34096d638d3be44


Flow:

1. Start at Databricks website

Navigate to get the MCP server URL

Go to VS Code and plop it in and connect

Note, VS code can't do DCR with this provider, so it asks you to manually specify a client.

Create the client with name "VS Code", select "All APIs" and uncheck the "Create Secret" box -- this will be a public client. 

VS code will automatically cope the redirect URLs to use. Make sure to add a trailing slash to the 127.0.0.1 redirect, and also manually add a localhost version. All three redirect URIs should look like this:

http://127.0.0.1:33418/
http://localhost:33418/
https://vscode.dev/redirect


Can use this client:

dd1a6039-1c4c-4dd1-947c-f142a90da95b

Boom! I have access to the Bakehouse Sale MCP server. Use
this query in VS Code:

```
Use the Bakehouse Sales tool to give me a summary of the datasets available in the genie space.
```




https://ceposta-agw-gke.ngrok.io/mcp/databricks


set -a && source .env && set +a


 arctl mcp deploy agentgateway dev.servereverything/server \
  --gateway agentgateway \
  --gateway-namespace agentgateway-system \
  --dry-run \
  --sso
