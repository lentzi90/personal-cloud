#!/bin/bash
set -e

echo "=== Testing HTTP Endpoints ==="

# Function to test HTTP endpoint
test_http_endpoint() {
  local name=$1
  local url=$2
  local expected_status=${3:-200}
  
  echo "Testing $name at $url..."
  response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url" || echo "000")
  
  if [ "$response" = "$expected_status" ]; then
    echo "✓ $name is accessible (HTTP $response)"
    return 0
  else
    echo "✗ $name returned HTTP $response (expected $expected_status)"
    return 1
  fi
}

# Wait for ingress to be ready
echo "Waiting for nginx ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Add hosts entries for local testing (check if not already present with correct IP)
grep -q "^127\.0\.0\.1[[:space:]]\+argocd\.local[[:space:]]*$" /etc/hosts || echo "127.0.0.1 argocd.local" | sudo tee -a /etc/hosts
grep -q "^127\.0\.0\.1[[:space:]]\+keycloak\.local[[:space:]]*$" /etc/hosts || echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
grep -q "^127\.0\.0\.1[[:space:]]\+opencloud\.local[[:space:]]*$" /etc/hosts || echo "127.0.0.1 opencloud.local" | sudo tee -a /etc/hosts

# Test ingress controller health
echo ""
echo "--- Testing Ingress Controller ---"
# Note: /healthz endpoint returns 404 when accessed without a valid ingress rule
# This is expected behavior - the 404 confirms the ingress controller is running
# and processing requests (just not routing this particular path)
test_http_endpoint "Nginx Ingress Controller" "http://localhost/healthz" 404

# Test ArgoCD
echo ""
echo "--- Testing ArgoCD ---"
# ArgoCD redirects HTTP to HTTPS, so we test HTTPS endpoint
test_http_endpoint "ArgoCD UI" "https://argocd.local/" 200

# Test Keycloak
echo ""
echo "--- Testing Keycloak ---"
# Keycloak may redirect, so we follow redirects
response=$(curl -k -s -o /dev/null -w "%{http_code}" -L --connect-timeout 10 --max-time 30 "https://keycloak.local/" || echo "000")
if [ "$response" = "200" ]; then
  echo "✓ Keycloak is accessible (HTTP $response)"
else
  echo "✗ Keycloak returned HTTP $response (expected 200)"
  exit 1
fi

# Test Opencloud (Nextcloud)
echo ""
echo "--- Testing Opencloud ---"
# Nextcloud typically returns 302 for root path (redirects to login)
response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "https://opencloud.local/" || echo "000")
if [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "303" ]; then
  echo "✓ Opencloud is accessible (HTTP $response)"
else
  echo "✗ Opencloud returned HTTP $response (expected 200/302/303)"
  exit 1
fi

echo ""
echo "=== All HTTP health checks passed ==="
