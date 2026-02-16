# Readme

1. Install cert-manager: `kubectl apply -k cert-manager/overlays/<overlay>`
2. Install argocd: `kubectl apply -k argocd/overlays/<overlay>`
3. Add all applications: `kubectl apply -k apps/overlays/<overlay>`

The `apps` folder contains argocd Applications including an "app-of-apps".

## Backup

Use `rsync` to download all data from the NFS share.

```bash
rsync --archive --compress --progress --delete --rsync-path='sudo -u www-data rsync' lennart@bombur:/media/data/personal-cloud/opencloud ./
```

Make btrfs snapshots of the data.

```bash
sudo btrfs subvolume snapshot -r . .snapshots/nasse-$(date +%Y-%m-%d)

# Check disk usage
btrfs filesystem df --human-readable .
btrfs filesystem du --human-readable --summarize .
```

## Testing with KinD

```bash
sudo kind create cluster --config=kind-config.yaml
sudo kind get kubeconfig > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml

kubectl apply -k cert-manager/overlays/kind
kubectl apply -k argocd/overlays/kind

# Login and check that it is working
password="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd login --port-forward --port-forward-namespace argocd --username=admin --password="${password}"
argocd --port-forward --port-forward-namespace=argocd cluster list

# Apply the app of apps to install everything
kubectl -n argocd apply -f apps/kind/apps-app.yaml

# Add ClusterSecretStore
kubectl -n external-secrets create secret generic bitwarden-access-token --from-literal=token=...
kubectl apply -f secret-store/test-secretstore.yaml
```

## Accessing the apps

Add the following to `/etc/hosts`:

```
127.0.0.1 argocd.local opencloud.local jellyfin.local
```

### Argocd

Go to [argocd.local](https://argocd.local) to see the dashboard.
Log in as `admin` with the password you get from this commands:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### OpenCloud

Login at [opencloud.local](https://opencloud.local) with `admin`/`admin`.

### Jellyfin

Setup at [jellyfin.local](https://jellyfin.local).

### Pi-hole

Find the IP and password:

```bash
pi_hole_ip="$(kubectl -n pi-hole get svc pi-hole -o jsonpath="{.status.loadBalancer.ingress[].ip}")"
pi_hole_password="$(kubectl -n pi-hole get secret pi-hole-env -o jsonpath="{.data.WEBPASSWORD}" | base64 -d)"
echo "Login at http://${pi_hole_ip}/admin with the password ${pi_hole_password}"
```

Test the nameserver like this:

```bash
host example.com "${pi_hole_ip}"
```

### Wireguard

```bash
POD_NAME=$(kubectl -n wireguard get pod -l app.kubernetes.io/name=wireguard -o jsonpath="{.items[0].metadata.name}")
kubectl -n wireguard cp "${POD_NAME}":/config/peer1/peer1.conf /tmp/peer1.conf
sudo nmcli con import type wireguard file /tmp/peer1.conf
# Remove DNS configuration from the connection
nmcli con modify peer1 -ipv4.dns "10.13.13.1"
nmcli con modify peer1 -ipv4.dns-search "~"

nmcli c up peer1
# Check the connection by curling coredns
curl 10.96.0.10:9153
# This should give 404
# Now disable the connection and check again
nmcli c down peer1
curl --connect-timeout 2 10.96.0.10:9153
# This should timeout
```

Cleanup:

```bash
sudo nmcli c delete peer1
```
 ## Chainsaw test

 The Chainsaw test suite validates the deployment of all applications in a KinD cluster and includes end-to-end tests to verify actual application functionality.

 ### Prerequisites

 The E2E tests require the following tools to be installed:
 - `kubectl` - Kubernetes CLI
 - `argocd` - ArgoCD CLI
 - `curl` - HTTP client
 - `openssl` - TLS/SSL toolkit
 - `jq` - JSON processor

 ### Running the tests

 ```bash
sudo kind create cluster --config=kind-config.yaml
sudo kind get kubeconfig > kubeconfig.yaml
export KUBECONFIG=kubeconfig.yaml
export BITWARDEN_ACCESS_TOKEN=...

# Install ArgoCD CLI (if not already installed)
ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name)
curl -sSL -o /tmp/argocd-linux-amd64 "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
sudo install -m 755 /tmp/argocd-linux-amd64 /usr/local/bin/argocd

# Run tests
chainsaw test
 ```

 ### Test Coverage

 The test suite includes:

 1. **Resource Deployment Tests**: Validates that all Kubernetes resources (Deployments, Pods, etc.) are created and healthy
 2. **ArgoCD Application Sync Tests**: Ensures all ArgoCD Applications reach "Healthy" and "Synced" status
 3. **HTTP Health Checks** (`.github/scripts/test-http-endpoints.sh`): Tests that applications are accessible via HTTP/HTTPS endpoints
    - Nginx ingress controller health
    - ArgoCD UI accessibility
    - Keycloak UI accessibility
    - OpenCloud (Nextcloud) UI accessibility
 4. **Certificate Validation** (`.github/scripts/test-certificates.sh`): Verifies TLS certificates are properly configured and not expired
    - ArgoCD certificate
    - Keycloak certificate
    - OpenCloud certificate
 5. **Authentication Tests** (`.github/scripts/test-argocd-auth.sh`): Validates login and API access
    - ArgoCD CLI login with admin credentials
    - Application listing via ArgoCD API
