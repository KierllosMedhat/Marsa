#!/bin/bash
set -e

# Prevent git safe directory ownership errors on Linux CI/CD (Vercel)
git config --global --add safe.directory "*" || true

echo "=== Setting up Flutter SDK on Vercel ==="
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
else
  echo "Flutter directory already exists, updating..."
  (cd flutter && git pull) || true
fi

export PATH="$PATH:$(pwd)/flutter/bin"

# Disable analytics and telemetry to avoid prompt delays
flutter config --no-analytics

echo "Flutter environment:"
flutter --version

echo "=== Installing dependencies ==="
flutter pub get

echo "=== Building Flutter Web Application ==="
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"

echo "=== Build finished successfully ==="
