#!/bin/bash
set -e

echo "=== Setting up Flutter SDK on Vercel ==="
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
else
  echo "Flutter directory already cached, updating..."
  (cd flutter && git pull) || true
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "Flutter version:"
flutter --version

echo "=== Building Flutter Web Application ==="
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"

echo "=== Build finished successfully ==="
