#!/bin/bash
set -e

echo "=== Testing TLS Certificates ==="

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
LOCAL_HTTPS_PORT=8444
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

# Function to check certificate
check_certificate() {
  local name=$1
  local host=$2
  
  echo "Checking certificate for $name ($host)..."
  
  # Get certificate info (connect via port-forward with SNI)
  cert_info=$(echo | openssl s_client -servername "$host" -connect "127.0.0.1:${LOCAL_HTTPS_PORT}" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "FAILED")
  
  if [ "$cert_info" = "FAILED" ]; then
    echo "✗ Failed to retrieve certificate for $name"
    return 1
  fi
  
  echo "$cert_info"
  
  # Check if certificate is valid (not expired)
  if echo | openssl s_client -servername "$host" -connect "127.0.0.1:${LOCAL_HTTPS_PORT}" 2>/dev/null | openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
    echo "✓ Certificate for $name is valid"
    return 0
  else
    echo "✗ Certificate for $name is expired or invalid"
    return 1
  fi
}

# Test certificates
echo "--- Testing ArgoCD Certificate ---"
check_certificate "ArgoCD" "argocd.local"

echo ""
echo "--- Testing Keycloak Certificate ---"
check_certificate "Keycloak" "keycloak.local"

echo ""
echo "--- Testing Opencloud Certificate ---"
check_certificate "Opencloud" "opencloud.local"

echo ""
echo "=== All certificate checks passed ==="
