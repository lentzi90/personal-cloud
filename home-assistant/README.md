# Home Assistant

[Home Assistant](https://www.home-assistant.io/) with `configuration.yaml`
managed in git (`base/configuration.yaml`). Only `.storage`, the database and
installed custom integrations live on the PVC.

Location values (`latitude`, `longitude`, `elevation`) are read from
`secrets.yaml` with `!secret`. On KinD they are hard coded in the overlay, use `ExternalSecret` for production.

SSO through Keycloak is described in
[components/keycloak-sso](components/keycloak-sso/README.md).
