# Turing Talos cluster

Network environment:
- 192.168.0.1 - Router
- DHCP: 192.168.0.100 - 192.168.0.199
- Metallb pool: 192.168.0.50 - 192.168.0.99
- Static IPs for hosts: 192.168.0.200 - 192.168.0.250
- Talos VIPs: 192.168.0.10 - 192.168.0.19

## Generating configuration files

```bash
talosctl gen secrets
# Generate controlplane.yaml, worker.yaml and talosconfig
sops exec-file secrets.yaml \
    'talosctl gen config turing-talos https://192.168.0.10:6443 --with-secrets={}'
```

## Initializing cluster

Check DHCP assigned IPs with `tpi uart -n <i> get`.
Then initialize the cluster like this:

```bash
NODE_1=192.168.0.210
NODE_2=192.168.0.211
NODE_3=192.168.0.212

NODE_1=192.168.0.185
NODE_2=192.168.0.123
NODE_3=192.168.0.102

talosctl apply -f controlplane.yaml -p @n1.yaml --insecure -n ${NODE_1}
talosctl bootstrap -n 192.168.0.210
talosctl apply -f worker.yaml -p @n2.yaml --insecure -n ${NODE_2}
talosctl apply -f worker.yaml -p @n3.yaml --insecure -n ${NODE_3}
```

Get the kubeconfig:

```bash
talosctl kubeconfig -n ${NODE_1}
```

Configure talosconfig:

```bash
talosctl config nodes ${NODE_1} ${NODE_2} ${NODE_3}
talosctl config endpoints ${NODE_1}
```

## Reset nodes

```bash
# Workers and non-last control plane node
talosctl reset --nodes ${NODE_2},${NODE_3} --reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL
# Last control plane node
talosctl reset --nodes ${NODE_1} --reboot --graceful=false --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL
```

Reset the whole cluster:

```bash
talosctl reset --reboot --graceful=false --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL
```

## Upgrade

Kubernetes upgrade:

```bash
# Download the new version of talosctl first, and
# generate new configuration files and then apply them.
# Alternatively, edit the configuration files so they have the new version.
NODE_1=192.168.0.210
NODE_2=192.168.0.211
NODE_3=192.168.0.212

talosctl apply -f controlplane.yaml -p @n1.yaml -n ${NODE_1}
talosctl apply -f worker.yaml -p @n2.yaml -n ${NODE_2}
talosctl apply -f worker.yaml -p @n3.yaml -n ${NODE_3}
```

Talos upgrade:

```bash
# Download the new version of talosctl first
talosctl -n ${NODE_1} upgrade
talosctl -n ${NODE_2} upgrade
talosctl -n ${NODE_3} upgrade
```
