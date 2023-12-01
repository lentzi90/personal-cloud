#!/usr/bin/env bash

# set -e

echo "Installing argocd"
kubectl apply -k argocd/overlays/kind

echo "Create a secret with the secret key to be used by argocd"
gpg --armor --export-secret-key personal.cloud.test@example.com > argocd-gpg-private-key.gpg
kubectl -n argocd create secret generic argocd-gpg-private-key --from-file=argocd-gpg-private-key.gpg

echo "Wait for argocd-server to start"
kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=5m

echo "Login and check that it is working"
password="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
argocd login --port-forward --port-forward-namespace argocd --username=admin --password="${password}"
argocd --port-forward --port-forward-namespace=argocd cluster list
echo "Access to argocd confirmed!"

# Add argocd, cert-manager and nginx-ingress to get a fully working argocd deployment
kubectl -n argocd apply -f apps/kind/argocd-app.yaml
kubectl -n argocd apply -f apps/kind/cert-manager-app.yaml
kubectl -n argocd apply -f apps/kind/ingress-nginx-app.yaml

argocd --port-forward --port-forward-namespace=argocd app wait cert-manager
argocd --port-forward --port-forward-namespace=argocd app wait ingress-nginx
argocd --port-forward --port-forward-namespace=argocd app wait argocd --sync
