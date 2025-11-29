# Keycloak OIDC Integration for OpenCloud

This is a reference/template directory for Keycloak OIDC integration with OpenCloud.

Due to Kustomize security restrictions, env files cannot be referenced from
outside the overlay directory, so each environment has its own `oidc.env` file.

## Setup Instructions

To enable Keycloak OIDC integration in a new environment:

### 1. Copy the OIDC env file

Copy the `oidc.env` file from this directory to your overlay:

```bash
cp opencloud/components/keycloak-oidc/oidc.env <your-overlay-path>/oidc.env
```

### 2. Update the OIDC issuer URLs

Edit the copied `oidc.env` file and update the issuer URLs to match your Keycloak deployment:

```env
OCIS_OIDC_ISSUER=https://keycloak.example.com/realms/openCloud
WEB_OIDC_ISSUER=https://keycloak.example.com/realms/openCloud
PROXY_OIDC_ISSUER=https://keycloak.example.com/realms/openCloud
```

### 3. Add the oidc.env to your configMapGenerator

In your overlay's `kustomization.yaml`, add the `oidc.env` file to the configMapGenerator:

```yaml
configMapGenerator:
- name: opencloud-env
  envs:
  - config.env
  - oidc.env
```

### 4. Include the opencloud-realm component in your Keycloak overlay

Add the component to your Keycloak kustomization:

```yaml
components:
- ../../components/opencloud-realm
```

And patch the redirect URIs for your environment:

```yaml
patches:
- target:
    kind: KeycloakRealmImport
    name: opencloud-realm
  patch: |-
    - op: add
      path: /spec/realm/clients/0/redirectUris
      value:
        - https://opencloud.example.com/*
    - op: add
      path: /spec/realm/clients/0/webOrigins
      value:
        - https://opencloud.example.com
    - op: add
      path: /spec/realm/clients/0/attributes/post.logout.redirect.uris
      value: https://opencloud.example.com/*
```

## Examples

See the following directories for working examples:

- `opencloud/overlays/kind/` - KinD development environment
- `turing-talos/apps/opencloud/` - Production turing-talos environment

## Configuration Reference

The `oidc.env` file contains the following key settings:

| Variable | Description |
|----------|-------------|
| `PROXY_AUTOPROVISION_ACCOUNTS` | Enable automatic user provisioning on first login |
| `WEB_OIDC_CLIENT_ID` | OIDC client ID (default: `web`) |
| `OCIS_OIDC_ISSUER` | OIDC issuer URL for OpenCloud core |
| `WEB_OIDC_ISSUER` | OIDC issuer URL for web UI |
| `PROXY_OIDC_ISSUER` | OIDC issuer URL for proxy |
| `PROXY_ROLE_ASSIGNMENT_DRIVER` | Role assignment driver (`oidc`) |
| `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM` | Claim name containing roles |
| `PROXY_ROLE_ASSIGNMENT_OIDC_MAPPING` | Role mapping from Keycloak to OpenCloud |
| `OCIS_EXCLUDE_RUN_SERVICES` | Services to disable (e.g., `idm`) |
| `PROXY_OIDC_USER_ID_CLAIM` | Claim containing user ID (`openclouduuid`) |