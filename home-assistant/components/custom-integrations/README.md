# Custom integrations

Home Assistant custom integrations are installed into the persistent
`/config/custom_components` directory by a single `install-integrations` init
container, so there is one place to add and update them.

How it works:

- `integrations/<domain>.env` defines an integration (the file name is the
  integration domain, i.e. the directory name in `custom_components`):

  ```sh
  # renovate: datasource=github-releases depName=owner/repo
  VERSION=v1.2.3
  URL="https://github.com/owner/repo/releases/download/${VERSION}/domain.zip"
  # Optional: paths (relative to the integration) kept across upgrades.
  KEEP=""
  ```

  The archive may contain the integration at its root (release assets) or in
  `custom_components/<domain>` (repository source archives, e.g.
  `https://github.com/owner/repo/archive/refs/tags/${VERSION}.zip`).
- All definitions are in one `home-assistant-integrations` ConfigMap together
  with `install.sh`. Overlays choose which integrations to install with a
  `home-assistant-integrations-enabled` ConfigMap.
- The installed version is stored in `custom_components/<domain>/.version`.
  Nothing is downloaded when it matches `VERSION`.
- If an update fails but the integration is already installed, the old version
  is kept and a warning is logged. The init container only fails when an
  enabled integration is not installed at all.
- Renovate bumps `VERSION` (see `renovate.json`). The `# renovate:` comment
  above it is required.

## Usage

```yaml
components:
- ../../components/custom-integrations

configMapGenerator:
- name: home-assistant-integrations-enabled
  literals:
  - enabled=auth_oidc goecharger_api2 solarman
```

Do not set `disableNameSuffixHash`. Home Assistant only loads integrations on
start, so the hash suffix is what rolls the Deployment (and runs the installer)
when the list or a definition changes. Changing any definition restarts every
overlay that uses this component, even those that do not enable it.

Examples: `home-assistant/overlays/kind/` and `turing-talos/apps/home-assistant/`.

## Adding an integration

1. Add `integrations/<domain>.env` and list it under `files` in
   `kustomization.yaml`.
2. Add the domain to `enabled` in the overlays that want it.
3. Optionally add `integrations/<domain>.md` with the setup steps.
4. Check the Home Assistant version compatibility in the integration's
   documentation. Custom integrations are not covered by Home Assistant's own
   release testing.

## Available integrations

| Domain | Project | Notes |
|--------|---------|-------|
| `auth_oidc` | [hass-oidc-auth](https://github.com/christiaangoossens/hass-oidc-auth) | See [keycloak-sso](../keycloak-sso/README.md) |
| `goecharger_api2` | [ha-goecharger-api2](https://github.com/marq24/ha-goecharger-api2) | [Setup](integrations/goecharger_api2.md) |
| `solarman` | [ha-solarman](https://github.com/davidrapan/ha-solarman) | [Setup](integrations/solarman.md) |
