# Home Assistant

[Home Assistant](https://www.home-assistant.io/) with `configuration.yaml`
managed in git (`base/configuration.yaml`). Only `.storage`, the database and
installed custom integrations live on the PVC.

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
