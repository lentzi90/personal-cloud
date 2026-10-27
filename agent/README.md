# Agent

[Open WebUI](https://github.com/open-webui/open-webui) with a sandbox
([Open Terminal](https://github.com/open-webui/open-terminal)).

## turing-talos

The `jern.fi` realm is not managed by the realm import, so in Keycloak create:

- Realm roles `agentUser` and `agentAdmin`, assigned to users.
- Client `agent` (client authentication, standard flow, redirect URI
  `https://agent.jern.fi/oauth/oidc/callback`). Disable *Full scope allowed* and
  map both roles to the client scope.

Then create the secrets in Bitwarden and fill in their IDs in
`turing-talos/apps/agent/external-secret.yaml`. The OIDC client secret is the
one generated for the `agent` client.
