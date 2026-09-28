# Keycloak SSO plugin for Jellyfin

This component installs the [9p4/jellyfin-plugin-sso](https://github.com/9p4/jellyfin-plugin-sso)
plugin (the project is archived, but the last release keeps working) so Jellyfin
can authenticate against the shared Keycloak realm
(`keycloak/components/homelab-realm`).

Due to Kustomize security restrictions, files cannot be referenced from outside
the overlay directory, so each environment has its own `SSO-Auth.xml` file.

## How it works

An init container downloads the pinned plugin release directly from GitHub
(no calls to the GitHub API at runtime, to avoid CI firewall issues) into the
persistent `jellyfin-config` volume, then seeds the plugin's configuration
file (`SSO-Auth.xml`) on first run only, so changes made through the Jellyfin
admin UI afterwards are not overwritten on every restart.

## Setup Instructions

### 1. Copy the SSO-Auth.xml file to your overlay

```bash
cp jellyfin/components/keycloak-sso/SSO-Auth.xml.example <your-overlay-path>/SSO-Auth.xml
```

### 2. Update the OIDC endpoint

Edit the copied `SSO-Auth.xml` and point `OidEndpoint` at your Keycloak
deployment:

```xml
<OidEndpoint>https://keycloak.example.com/realms/homelab</OidEndpoint>
```

### 3. Add the component and configMapGenerator to your overlay

```yaml
components:
- ../../components/keycloak-sso

generatorOptions:
  disableNameSuffixHash: true

configMapGenerator:
- name: jellyfin-sso-config
  files:
  - SSO-Auth.xml
```

## Configuration Reference

| Field | Description |
|-------|--------------|
| `OidEndpoint` | Keycloak realm issuer URL |
| `OidClientId` | The `jellyfin` client from the shared realm |
| `AdminRoles` | Realm roles granted Jellyfin admin access (`jellyfinAdmin`) |
| `Roles` | Realm roles allowed to sign in (`jellyfinUser`, `jellyfinAdmin`) |
| `RoleClaim` | Claim holding the roles (`realm_access.roles`, from the realm's `roles` client scope) |

## Examples

See the following directories for working examples:

- `jellyfin/overlays/kind/` - KinD development environment
- `turing-talos/apps/jellyfin/` - Production turing-talos environment
