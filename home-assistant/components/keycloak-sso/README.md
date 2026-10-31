# Keycloak SSO for Home Assistant

Home Assistant has no native OIDC support. This component installs the
[hass-oidc-auth](https://github.com/christiaangoossens/hass-oidc-auth)
custom integration with an init container and loads the overlay's
`auth_oidc.yaml` as a configuration package. Login is done with the public
PKCE client `home-assistant` from the shared realm
(`keycloak/components/homelab-realm`).

Realm roles are mapped to Home Assistant roles through the client's `groups`
claim: `homeAssistantUser` can sign in, `homeAssistantAdmin` becomes
administrator. The regular username/password login keeps working, e.g. for the
onboarding user.

Each overlay provides its own `auth_oidc.yaml` and a `home-assistant-oidc-config`
ConfigMap:

```yaml
components:
- ../../components/keycloak-sso

generatorOptions:
  disableNameSuffixHash: true

configMapGenerator:
- name: home-assistant-oidc-config
  files:
  - auth_oidc.yaml
```

Examples: `home-assistant/overlays/kind/` and `turing-talos/apps/home-assistant/`.
