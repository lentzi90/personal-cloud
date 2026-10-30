# Collabora Online

Deploys [Collabora Online](https://www.collaboraonline.com/) (CODE) and wires
it up to OpenCloud for in-browser document editing, based on the
[collabora example](https://github.com/opencloud-eu/opencloud-compose/blob/main/weboffice/collabora.yml)
in `opencloud-eu/opencloud-compose`.

## How it works

- `collabora/` (this directory) only deploys the actual Collabora
  Online/CODE container - the office suite that renders documents in the
  browser. TLS is terminated at the gateway, so coolwsd serves plain HTTP
  (`ssl.enable=false`, `ssl.termination=true`) and the Service/probes use HTTP.
  The container gets the `SYS_ADMIN` capability and unconfined seccomp/AppArmor
  profiles (as in the reference compose file) so it can set up its chroot jails.
  Environments that need more can add it in their overlay (the `kind` overlay
  runs the container privileged). Because the Pod Security `baseline` policy
  rejects this, Collabora runs in its own `collabora` namespace labelled
  `pod-security.kubernetes.io/enforce: privileged` (each overlay provides a
  `namespace.yaml`), rather than in the `opencloud` namespace. It is only
  reached through its HTTPRoute and the public domain names, so it does not
  need to share a namespace with OpenCloud.
- A small `initContainer` (`alpine/openssl`) generates a WOPI proof key on a
  persistent volume (`collabora-proof-key`) before Collabora starts, mirroring
  the `collabora-proof-key` one-shot service in the reference compose file. The
  key must survive pod restarts: OpenCloud caches the proof keys from
  Collabora's discovery document and would reject documents signed with a new
  key until that cache expires. There is no key rotation; to rotate the key,
  delete the file from the volume (and expect OpenCloud to need a restart to
  pick up the new key).
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
- OpenCloud and Collabora call each other server-side using the public
  domain names (OpenCloud fetches the discovery document from
  `COLLABORATION_APP_ADDR`, Collabora calls `COLLABORATION_WOPI_SRC`), so both
  names must resolve from inside the cluster.
- The `opencloud-env` and `opencloud-csp` ConfigMaps keep their name hash so
  that changing them rolls out the OpenCloud pod, which only reads them on
  startup.

## Setup Instructions

To enable Collabora in a new environment:

1. Create `collabora/overlays/<environment>/` following the `kind` example:
   a `collabora-httproute.yaml` (or equivalent ingress) for the Collabora
   domain, a `namespace.yaml` for the `collabora` namespace (privileged Pod
   Security level, see above), and a `collabora.env` with at least `aliasgroup1` (the OpenCloud
   URL) and `extra_params` (`ssl.enable=false`, `ssl.termination=true`, and
   pointing `net.frame_ancestors` and `net.lok_allow.host[14]` at the OpenCloud
   domain). Keep `ssl.ssl_verification=true` when OpenCloud uses a trusted
   certificate.
2. Add an ArgoCD Application for it (see `apps/kind/collabora-app.yaml`).
3. In the corresponding `opencloud/overlays/<environment>/config.env`, add:
   - `OC_ADD_RUN_SERVICES=collaboration`
   - `COLLABORA_DOMAIN`, `FRONTEND_APP_HANDLER_SECURE_VIEW_APP_ADDR`,
     `GRAPH_AVAILABLE_ROLES`, and the `COLLABORATION_*` variables (see the
     `kind` overlay for a working example, or the reference compose file
     linked above).
4. Add the Collabora domain to `frame-src` and `img-src` in
   `opencloud/overlays/<environment>/csp.yaml`.

## KinD

The `*.test.local` names only exist in your `/etc/hosts` (see the top level
README), which pods do not use. The Chainsaw test adds a `test.local` zone to
CoreDNS that points at the private gateway. To do the same by hand, append this
to the `Corefile` in the `coredns` ConfigMap in `kube-system` (with the gateway
address from `kubectl -n envoy-gateway-system get gateway envoy-private`) and
restart CoreDNS:

```
test.local:53 {
    errors
    hosts {
        <gateway-ip> opencloud.test.local collabora.test.local
    }
    cache 30
}
```

## Examples

See `collabora/overlays/kind/` and `opencloud/overlays/kind/` for a working
example.
