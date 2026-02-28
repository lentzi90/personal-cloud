#!/bin/bash
set -e

echo "=== Testing TLS Certificates ==="

# Get the gateway's external IP for connections
GATEWAY_IP=$(kubectl get gateway envoy-private -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')
if [ -z "$GATEWAY_IP" ]; then
  echo "✗ Failed to get gateway IP"
  exit 1
fi
echo "Gateway IP: $GATEWAY_IP"

# Function to check certificate
check_certificate() {
  local name=$1
  local host=$2
  
  echo "Checking certificate for $name ($host)..."
  
  # Get certificate info (connect to gateway IP with SNI)
  cert_info=$(echo | openssl s_client -servername "$host" -connect "$GATEWAY_IP:443" 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null || echo "FAILED")
  
  if [ "$cert_info" = "FAILED" ]; then
    echo "✗ Failed to retrieve certificate for $name"
    return 1
  fi
  
  echo "$cert_info"
  
  # Check if certificate is valid (not expired)
  if echo | openssl s_client -servername "$host" -connect "$GATEWAY_IP:443" 2>/dev/null | openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
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
