# Keycloak OIDC Integration for OpenCloud

This is a reference/template directory for Keycloak OIDC integration with OpenCloud.

Due to Kustomize security restrictions, env files cannot be referenced from
outside the overlay directory, so each environment has its own `oidc.env` file.

## How the integration works

Keycloak replaces the OpenCloud built-in identity *provider* (`idp`), but the
built-in identity *manager* (`idm`) keeps running as the user and group
directory. Only `idp` is listed in `OC_EXCLUDE_RUN_SERVICES`.

On sign-in the proxy reads the `preferred_username` claim from the token and
looks up the matching OpenCloud account (`PROXY_USER_CS3_CLAIM=username`):

- If the account exists, it is reused with its original user ID, so personal
  spaces and shares stay intact. This is what allows an existing installation to
  be migrated to Keycloak.
- If it does not exist, `PROXY_AUTOPROVISION_ACCOUNTS=true` creates it. Note
  that autoprovisioned accounts get a *newly generated* user ID, so they always
  start with an empty personal space.

Roles are taken from the Keycloak `roles` claim. The OpenCloud defaults already
map `opencloudAdmin`, `opencloudSpaceAdmin`, `opencloudUser` and
`opencloudGuest`, so no extra mapping configuration is needed. The mapping can
only be changed through a config file, there is no environment variable for it.

## Setup Instructions

To enable Keycloak OIDC integration in a new environment:

### 1. Copy the OIDC env file

Copy the `oidc.env` file from this directory to your overlay:

```bash
cp opencloud/components/keycloak-oidc/oidc.env <your-overlay-path>/oidc.env
```

### 2. Update the OIDC issuer URL

Edit the copied `oidc.env` file and update the issuer URL to match your Keycloak
deployment:

```env
OC_OIDC_ISSUER=https://keycloak.example.com/realms/openCloud
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

### 4. Add a CSP configuration

The web UI needs to be allowed to talk to Keycloak, so copy `csp.yaml` from one
of the examples below, point `connect-src` at your Keycloak host and mount it:

```yaml
configMapGenerator:
- name: opencloud-csp
  files:
  - csp.yaml
```

The deployment then needs `PROXY_CSP_CONFIG_FILE_LOCATION=/etc/opencloud/csp.yaml`
and the ConfigMap mounted at that path.

### 5. Include the opencloud-realm component in your Keycloak overlay

Add the component to your Keycloak kustomization:

```yaml
components:
- ../../components/opencloud-realm
```

And patch the redirect URIs for your environment (the `web` client is at index 2):

```yaml
patches:
- target:
    kind: KeycloakRealmImport
    name: opencloud-realm
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

The realm import does not contain any users. Create them in Keycloak, and make
sure the username matches the OpenCloud username when migrating an existing
installation. See `docs/opencloud-keycloak-migration.md`.

## Examples

See the following directories for working examples:

- `opencloud/overlays/kind/` - KinD development environment
- `turing-talos/apps/opencloud/` - Production turing-talos environment

## Configuration Reference

The `oidc.env` file contains the following key settings:

| Variable | Description |
|----------|-------------|
| `OC_EXCLUDE_RUN_SERVICES` | Services to disable (`idp`, since Keycloak replaces it) |
| `OC_OIDC_ISSUER` | OIDC issuer URL, used by proxy, web, users and webfinger |
| `WEB_OIDC_CLIENT_ID` | OIDC client ID (default: `web`) |
| `PROXY_OIDC_REWRITE_WELLKNOWN` | Serve the discovery document from the proxy instead of the disabled idp |
| `PROXY_USER_OIDC_CLAIM` | Claim used to identify the user (`preferred_username`) |
| `PROXY_USER_CS3_CLAIM` | OpenCloud attribute it is matched against (`username`) |
| `PROXY_AUTOPROVISION_ACCOUNTS` | Enable automatic user provisioning on first login |
| `PROXY_ROLE_ASSIGNMENT_DRIVER` | Role assignment driver (`oidc`) |
| `PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM` | Claim name containing roles |
