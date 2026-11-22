# Home Assistant

[Home Assistant](https://www.home-assistant.io/) with `configuration.yaml`
managed in git (`base/configuration.yaml`). Only `.storage`, the database and
installed custom integrations live on the PVC.

The HTTP integration settings (trust of `X-Forwarded-For` from the Envoy
gateway) are not in `configuration.yaml`: since Home Assistant 2026.8 they are
managed in the UI (Settings, System, Network) and stored in
`/config/.storage/http`, and the `http:` block is ignored from 2027.2.0. They
are part of the app state on the PVC, so keep them in the backups. The
`seed-http-config` init container only copies `base/http-seed.json` to a fresh
`/config` volume (new KinD cluster, lost PVC) and never overwrites an existing
file. Without it requests through the gateway get a `400`. Edit the seed if the
pod network changes, existing installations must change it in the UI.

Location values (`latitude`, `longitude`, `elevation`) are read from
`secrets.yaml` with `!secret`. On KinD they are hard coded in the overlay, use `ExternalSecret` for production.

SSO through Keycloak is described in
[components/keycloak-sso](components/keycloak-sso/README.md).

Custom integrations are installed by one init container, see
[components/custom-integrations](components/custom-integrations/README.md).

The go-e chargers and controller are set up as described in
[goecharger_api2](components/custom-integrations/integrations/goecharger_api2.md).

The Solis inverter is set up as described in
[solarman](components/custom-integrations/integrations/solarman.md).
