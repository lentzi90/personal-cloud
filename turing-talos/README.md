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
NODE_4=192.168.0.213

talosctl apply -f controlplane.yaml -p @n1.yaml --insecure -n ${NODE_1}
talosctl bootstrap -n 192.168.0.210
talosctl apply -f worker.yaml -p @n2.yaml --insecure -n ${NODE_2}
talosctl apply -f worker.yaml -p @n3.yaml --insecure -n ${NODE_3}
talosctl apply -f worker.yaml -p @n4.yaml --insecure -n ${NODE_4}
```

Get the kubeconfig:

```bash
talosctl kubeconfig -n ${NODE_1}
```

Configure talosconfig:

```bash
talosctl config nodes ${NODE_1} ${NODE_2} ${NODE_3} ${NODE_4}
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
VERSION=vX.Y.Z
NODE_1=192.168.0.210

talosctl upgrade-k8s -n ${NODE_1} --to ${VERSION} --dry-run
```

Talos upgrade:

```bash
VERSION=vX.Y.Z
# Image including iscsi-tools for turing RK1
talosctl -n ${NODE_1} upgrade --image factory.talos.dev/installer/85f683902139269fbc5a7f64ea94a694d31e0b3d94347a225223fcbd042083ae:${VERSION}
talosctl -n ${NODE_2} upgrade --image factory.talos.dev/installer/85f683902139269fbc5a7f64ea94a694d31e0b3d94347a225223fcbd042083ae:${VERSION}
talosctl -n ${NODE_3} upgrade --image factory.talos.dev/installer/85f683902139269fbc5a7f64ea94a694d31e0b3d94347a225223fcbd042083ae:${VERSION}
# Image including iscsi-tools for Raspberry Pi 4
talosctl -n ${NODE_4} upgrade --image factory.talos.dev/installer/f47e6cd2634c7a96988861031bcc4144468a1e3aef82cca4f5b5ca3fffef778a:${VERSION}
```

## Apply changes

```bash
talosctl apply -f controlplane.yaml -p @n1.yaml -n ${NODE_1} --dry-run
talosctl apply -f worker.yaml -p @n2.yaml -n ${NODE_2} --dry-run
talosctl apply -f worker.yaml -p @n3.yaml -n ${NODE_3} --dry-run
talosctl apply -f worker.yaml -p @n4.yaml -n ${NODE_4} --dry-run
```

## NAS setup

```bash
sudo apt install -y nfs-kernel-server btrfs-progs
# New btrfs volume
sudo fdisk /dev/sdX
sudo mkfs.btrfs -f /dev/sdX
# Existing btrfs volume
sudo btrfs device scan
sudo btrfs filesystem show # gives the UUID
sudo mkdir -p /media/Data
sudo mount UUID=... /media/Data
# Add to /etc/fstab
echo "UUID=... /media/Data btrfs defaults 0 0" | sudo tee -a /etc/fstab

# Setup NFS
sudo nano /etc/exports
# /media/data *(rw,no_root_squash,insecure,async,no_subtree_check,anonuid=1000,anongid=1000)
sudo exportfs -ar
sudo systemctl restart nfs-kernel-server
```
