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

# Wait for envoy gateway to be ready
echo "Waiting for envoy gateway to be ready..."
kubectl wait --namespace envoy-gateway-system \
  --for=condition=ready pod \
  --selector=gateway.envoyproxy.io/owning-gateway-name=envoy-private \
  --timeout=120s

# Add hosts entries for local testing (check if not already present with correct IP)
grep -q "^127\.0\.0\.1[[:space:]].*argocd\.local" /etc/hosts || echo "127.0.0.1 argocd.local" | sudo tee -a /etc/hosts
grep -q "^127\.0\.0\.1[[:space:]].*keycloak\.local" /etc/hosts || echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
grep -q "^127\.0\.0\.1[[:space:]].*opencloud\.local" /etc/hosts || echo "127.0.0.1 opencloud.local" | sudo tee -a /etc/hosts

# Test ArgoCD
echo ""
echo "--- Testing ArgoCD ---"
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

# Test Opencloud
echo ""
echo "--- Testing Opencloud ---"
# OpenCloud typically returns 302 for root path (redirects to login)
response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "https://opencloud.local/" || echo "000")
if [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "303" ]; then
  echo "✓ Opencloud is accessible (HTTP $response)"
else
  echo "✗ Opencloud returned HTTP $response (expected 200/302/303)"
  exit 1
fi

echo ""
echo "=== All HTTP health checks passed ==="
