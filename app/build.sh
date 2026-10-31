#!/usr/bin/env bash
set -e

echo "=== Preparing Marsa Clinic Flutter Web Portal for Vercel ==="
mkdir -p build/web
if [ -d "../web/public/ota-bundle" ]; then
  cp -rf ../web/public/ota-bundle/* build/web/
  if [ -f "build/web/index.html" ]; then
    sed -i 's|href="/ota-bundle/"|href="/"|g' build/web/index.html
  fi
  echo "=== Copied pre-built OTA Web Bundle to build/web successfully ==="
  exit 0
fi
echo "=== Build finished ==="
