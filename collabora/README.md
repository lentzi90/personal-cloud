# Collabora Online

Deploys [Collabora Online](https://www.collaboraonline.com/) (CODE) and wires
it up to OpenCloud for in-browser document editing, based on the
[collabora example](https://github.com/opencloud-eu/opencloud-compose/blob/main/weboffice/collabora.yml)
in `opencloud-eu/opencloud-compose`.

## How it works

- `collabora/` (this directory) only deploys the actual Collabora
  Online/CODE container - the office suite that renders documents in the
  browser. A small `initContainer` (`alpine/openssl`) generates a WOPI proof
  key into an `emptyDir` before Collabora starts, mirroring the
  `collabora-proof-key` one-shot service in the reference compose file
  (adapted to regenerate on every pod start instead of using a persistent
  volume).
- The WOPI bridge (`collaboration`) is enabled on the existing OpenCloud
  deployment via `OC_ADD_RUN_SERVICES=collaboration` and the
  `COLLABORATION_*` environment variables, configured in
  `opencloud/overlays/<environment>/config.env`. WOPI requests are served by
  the OpenCloud proxy on the OpenCloud domain itself, so no separate
  `wopiserver` domain, route, Deployment or Service is needed, and no NATS
  registry or REVA gRPC gateway has to be exposed between pods: everything
  runs in the same process.
- OpenCloud's Content-Security-Policy (`opencloud/overlays/<environment>/csp.yaml`)
  needs to allow framing/loading the Collabora domain (`frame-src`, `img-src`).

## Setup Instructions

To enable Collabora in a new environment:

1. Create `collabora/overlays/<environment>/` following the `kind` example:
   a `collabora-httproute.yaml` (or equivalent ingress) for the Collabora
   domain, and a `collabora.env` with at least `aliasgroup1` (the OpenCloud
   URL) and `extra_params` (pointing `net.frame_ancestors` and
   `net.lok_allow.host[14]` at the OpenCloud domain).
2. Add an ArgoCD Application for it (see `apps/kind/collabora-app.yaml`).
3. In the corresponding `opencloud/overlays/<environment>/config.env`, add:
   - `OC_ADD_RUN_SERVICES=collaboration`
   - `COLLABORA_DOMAIN`, `FRONTEND_APP_HANDLER_SECURE_VIEW_APP_ADDR`,
     `GRAPH_AVAILABLE_ROLES`, and the `COLLABORATION_*` variables (see the
     `kind` overlay for a working example, or the reference compose file
     linked above).
4. Add the Collabora domain to `frame-src` and `img-src` in
   `opencloud/overlays/<environment>/csp.yaml`.

## Examples

See `collabora/overlays/kind/` and `opencloud/overlays/kind/` for a working
example.
