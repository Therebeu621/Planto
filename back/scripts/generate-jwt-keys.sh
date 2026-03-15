#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="$ROOT_DIR/src/main/resources"
PRIVATE_KEY="$RESOURCES_DIR/privateKey.pem"
PUBLIC_KEY="$RESOURCES_DIR/publicKey.pem"
TMP_RSA_KEY="$RESOURCES_DIR/rsaPrivateKey.pem"

mkdir -p "$RESOURCES_DIR"

if [[ -f "$PRIVATE_KEY" || -f "$PUBLIC_KEY" ]]; then
  echo "JWT key files already exist in $RESOURCES_DIR"
  echo "Remove them first if you want to regenerate the pair."
  exit 1
fi

openssl genrsa -out "$TMP_RSA_KEY" 2048
openssl pkcs8 -topk8 -inform PEM -in "$TMP_RSA_KEY" -out "$PRIVATE_KEY" -nocrypt
openssl rsa -in "$TMP_RSA_KEY" -pubout -out "$PUBLIC_KEY"
rm -f "$TMP_RSA_KEY"

echo "Generated:"
echo "  - $PRIVATE_KEY"
echo "  - $PUBLIC_KEY"
