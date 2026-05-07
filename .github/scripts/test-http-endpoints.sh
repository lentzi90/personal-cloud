#!/bin/bash
set -e

echo "=== Testing HTTP Endpoints ==="

# Function to test HTTP endpoint
test_http_endpoint() {
  local name=$1
  local host=$2
  local expected_status=${3:-200}
  local extra_args=${4:-}

  local url="https://${host}:${LOCAL_HTTPS_PORT}/"
  echo "Testing $name at $url..."
  response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 \
    --resolve "${host}:${LOCAL_HTTPS_PORT}:127.0.0.1" $extra_args "$url" 2>/dev/null) || true

  if [ "$response" = "$expected_status" ]; then
    echo "✓ $name is accessible (HTTP $response)"
    return 0
  else
    echo "✗ $name returned HTTP $response (expected $expected_status)"
    return 1
  fi
}

# Wait for envoy gateway proxy to be ready
echo "Waiting for envoy gateway to be ready..."
kubectl wait --namespace envoy-gateway-system \
  --for=condition=ready pod \
  --selector=gateway.envoyproxy.io/owning-gateway-name=envoy-private \
  --timeout=120s

# Find the envoy gateway proxy service
echo "Finding envoy gateway proxy service..."
PROXY_SVC=$(kubectl get svc -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-private \
  -o jsonpath='{.items[0].metadata.name}')
if [ -z "$PROXY_SVC" ]; then
  echo "✗ Failed to find envoy gateway proxy service"
  exit 1
fi
echo "Proxy service: $PROXY_SVC"

# Port-forward to the gateway proxy service
LOCAL_HTTPS_PORT=8443
echo "Starting port-forward to $PROXY_SVC (local port $LOCAL_HTTPS_PORT -> 443)..."
kubectl port-forward -n envoy-gateway-system "svc/$PROXY_SVC" "${LOCAL_HTTPS_PORT}:443" &
PF_PID=$!

# Ensure port-forward is cleaned up on exit
cleanup() {
  echo "Cleaning up port-forward (PID $PF_PID)..."
  kill "$PF_PID" 2>/dev/null || true
  wait "$PF_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for port-forward to be ready
echo "Waiting for port-forward to be ready..."
for i in $(seq 1 10); do
  if curl -k -s -o /dev/null --connect-timeout 1 "https://127.0.0.1:${LOCAL_HTTPS_PORT}" 2>/dev/null; then
    echo "Port-forward is ready"
    break
  fi
  if [ "$i" = "10" ]; then
    echo "✗ Port-forward failed to become ready"
    exit 1
  fi
  sleep 1
done

# Test ArgoCD
echo ""
echo "--- Testing ArgoCD ---"
test_http_endpoint "ArgoCD UI" "argocd.local" 200

# Test Keycloak
echo ""
echo "--- Testing Keycloak ---"
# Keycloak may redirect, so we follow redirects
test_http_endpoint "Keycloak" "keycloak.local" 200 "-L"

# Test Opencloud
echo ""
echo "--- Testing Opencloud ---"
# OpenCloud may return 200, 302, or 303 for root path
response=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 30 \
  --resolve "opencloud.local:${LOCAL_HTTPS_PORT}:127.0.0.1" \
  "https://opencloud.local:${LOCAL_HTTPS_PORT}/" 2>/dev/null) || true
if [ "$response" = "200" ] || [ "$response" = "302" ] || [ "$response" = "303" ]; then
  echo "✓ Opencloud is accessible (HTTP $response)"
else
  echo "✗ Opencloud returned HTTP $response (expected 200/302/303)"
  exit 1
fi

echo ""
echo "=== All HTTP health checks passed ==="
