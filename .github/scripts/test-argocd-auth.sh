#!/bin/bash
set -e

echo "=== Testing ArgoCD CLI Authentication ==="

# Get admin password from secret and use it securely
echo "Retrieving ArgoCD admin password..."
# Store password in a temporary file with restricted permissions
password_file=$(mktemp)
chmod 600 "$password_file"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > "$password_file"

if [ ! -s "$password_file" ]; then
  echo "✗ Failed to retrieve ArgoCD admin password"
  rm -f "$password_file"
  exit 1
fi

echo "✓ Retrieved admin password"

# Login to ArgoCD using port-forward (password via stdin)
echo ""
echo "Logging in to ArgoCD via port-forward..."
cat "$password_file" | argocd login --port-forward --port-forward-namespace argocd \
  --username=admin --password-stdin --insecure
login_status=$?

# Clean up password file
rm -f "$password_file"

if [ $login_status -eq 0 ]; then
  echo "✓ Successfully logged in to ArgoCD"
else
  echo "✗ Failed to log in to ArgoCD"
  exit 1
fi

# Verify we can list applications
echo ""
echo "Listing ArgoCD applications..."
apps=$(argocd app list --output name 2>&1)
list_status=$?

if [ $list_status -eq 0 ]; then
  echo "✓ Successfully retrieved application list"
  echo "Applications found:"
  echo "$apps"
else
  echo "✗ Failed to list applications"
  echo "$apps"
  exit 1
fi

# Verify specific applications are present
echo ""
echo "Verifying expected applications are deployed..."
for app in argocd cert-manager keycloak opencloud; do
  if echo "$apps" | grep -q "$app"; then
    echo "✓ Application '$app' is deployed"
  else
    echo "⚠ Application '$app' not found in list"
  fi
done

echo ""
echo "=== ArgoCD CLI authentication test passed ==="
