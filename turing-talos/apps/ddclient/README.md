# ddclient (turing-talos)

Keeps the `jern.fi` DNS A record pointing at this cluster's public IP, using
Hetzner DNS as the provider.

## Required: a working ddclient image

The historical `lennartj/ddclient` image (Fedora 31 base, built in 2019) does
**not** work for this: Hetzner changed their DNS API, and support for it was
only fixed in ddclient upstream after v4.0.0 (see the "Unreleased" section of
https://github.com/ddclient/ddclient/blob/main/ChangeLog.md). No distro
package ships that fix yet either (Alpine 3.22/edge are still on v4.0.0).

Since `jern.fi` is an apex domain, this also needs the apex-domain fix
(hostname == zone sent as `@`), merged to `main` but not yet in a tagged
release as of this writing.

Until a suitable published image exists, build one from ddclient's `main`
branch (or a tag once v4.0.1 or later is released), publish it, and update
the `images:` entry in `kustomization.yaml` accordingly. A minimal Dockerfile:

```dockerfile
FROM alpine:3.20
RUN apk add --no-cache perl curl bash git autoconf automake make gettext && \
    git clone --depth=1 https://github.com/ddclient/ddclient.git /src && \
    cd /src && ./autogen && ./configure --sysconfdir=/etc && make && make install && \
    cd / && rm -rf /src && \
    apk del autoconf automake make git && \
    addgroup -g 1000 ddclient && adduser -D -u 1000 -G ddclient ddclient && \
    mkdir -p /ddclient/config && chown -R ddclient:ddclient /ddclient
USER ddclient
ENTRYPOINT ["/usr/local/sbin/ddclient"]
CMD ["-daemon=0", "-foreground", "-file=/ddclient/config/ddclient.conf"]
```

Pin the git clone to a specific commit/tag rather than always tracking `main`.

## Secret

The Hetzner DNS API token is pulled from the same Bitwarden item already used
by `hetzner-cloud-webhook` for ACME DNS-01 challenges (see
`../hetzner-cloud-webhook/externalsecret.yaml`), since it already has
permission to manage records in the `jern.fi` zone. `externalsecret.yaml`
renders it into a full `ddclient.conf` via the ExternalSecret's
`target.template`, so the token never needs to be committed to git.
