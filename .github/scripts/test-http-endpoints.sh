#!/bin/bash
set -e

echo "=== Testing HTTP Endpoints ==="

# Function to test HTTP endpoint
test_http_endpoint() {
  local name=$1
  local url=$2
  local expected_status=${3:-200}
  
  echo "Testing $name at $url..."
  response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "$url" 2>/dev/null) || true
  
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

# Get the gateway's external IP assigned by MetalLB
echo "Getting gateway IP..."
GATEWAY_IP=$(kubectl get gateway envoy-private -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
if [ -z "$GATEWAY_IP" ]; then
  echo "✗ Failed to get gateway IP"
  exit 1
fi
echo "Gateway IP: $GATEWAY_IP"

# Add hosts entries using the gateway's actual IP
ESCAPED_IP=$(echo "$GATEWAY_IP" | sed 's/\./\\./g')
grep -q "^${ESCAPED_IP}[[:space:]].*\bargocd\.local\b" /etc/hosts || echo "${GATEWAY_IP} argocd.local" | sudo tee -a /etc/hosts
grep -q "^${ESCAPED_IP}[[:space:]].*\bkeycloak\.local\b" /etc/hosts || echo "${GATEWAY_IP} keycloak.local" | sudo tee -a /etc/hosts
grep -q "^${ESCAPED_IP}[[:space:]].*\bopencloud\.local\b" /etc/hosts || echo "${GATEWAY_IP} opencloud.local" | sudo tee -a /etc/hosts

# Test ArgoCD
echo ""
echo "--- Testing ArgoCD ---"
test_http_endpoint "ArgoCD UI" "https://argocd.local/" 200

# Test Keycloak
echo ""
echo "--- Testing Keycloak ---"
# Keycloak may redirect, so we follow redirects
response=$(curl -k -s -o /dev/null -w "%{http_code}" -L --connect-timeout 10 --max-time 30 "https://keycloak.local/" 2>/dev/null) || true
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
response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 "https://opencloud.local/" 2>/dev/null) || true
if [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "303" ]; then
  echo "✓ Opencloud is accessible (HTTP $response)"
else
  echo "✗ Opencloud returned HTTP $response (expected 200/302/303)"
  exit 1
fi

echo ""
echo "=== All HTTP health checks passed ==="
