# Keycloak OIDC Integration for OpenCloud

This directory provides reference configuration for connecting OpenCloud to the
unified homelab Keycloak realm.

Due to Kustomize security restrictions, env files cannot be referenced from
outside the overlay directory, so each environment has its own `oidc.env` file.

## Setup Instructions

### 1. Copy the OIDC env file to your overlay

```bash
cp opencloud/components/keycloak-oidc/oidc.env <your-overlay-path>/oidc.env
```

### 2. Update the OIDC issuer URL

Edit the copied `oidc.env` file and set the issuer URL to match your Keycloak
deployment:

```env
OC_OIDC_ISSUER=https://keycloak.example.com/realms/homelab
PROXY_OIDC_ISSUER=https://keycloak.example.com/realms/homelab
```

### 3. Add oidc.env to the overlay configMapGenerator

In your overlay's `kustomization.yaml`, add the `oidc.env` file:

```yaml
configMapGenerator:
- name: opencloud-env
  envs:
  - config.env
  - oidc.env
```

### 4. Include the homelab-realm component in your Keycloak overlay

Add to your Keycloak `kustomization.yaml`:

```yaml
components:
- ../../../keycloak/components/homelab-realm
```

And patch the `web` client's redirect URIs (client index 2):

```yaml
patches:
- target:
    kind: KeycloakRealmImport
    name: homelab-realm
  patch: |-
    - op: add
      path: /spec/realm/clients/2/redirectUris
      value:
        - https://opencloud.example.com/*
    - op: add
      path: /spec/realm/clients/2/webOrigins
      value:
        - https://opencloud.example.com
    - op: add
      path: /spec/realm/clients/2/attributes/post.logout.redirect.uris
      value: https://opencloud.example.com/*
```

## Configuration Reference

| Variable | Description |
|----------|-------------|
| `PROXY_AUTOPROVISION_ACCOUNTS` | Enable automatic user provisioning on first login |
| `WEB_OIDC_CLIENT_ID` | OIDC client ID (default: `web`) |
| `OC_OIDC_ISSUER` | OIDC issuer URL (shared by OpenCloud services) |
| `PROXY_OIDC_ISSUER` | OIDC issuer URL for the proxy service |
| `PROXY_ROLE_ASSIGNMENT_DRIVER` | Role assignment driver (`oidc`) |
| `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM` | Claim name containing roles |
| `PROXY_ROLE_ASSIGNMENT_OIDC_MAPPING` | Role mapping from Keycloak to OpenCloud |
| `OCIS_EXCLUDE_RUN_SERVICES` | Services to disable (e.g., `idm,idp`) |
| `PROXY_OIDC_USER_ID_CLAIM` | Claim containing user ID (`openclouduuid`) |
