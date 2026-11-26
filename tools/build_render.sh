#!/usr/bin/env bash
# Build web para Docker/Render. La imagen no trae Flutter: se instala aqui.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.3}"
FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C "$(dirname "$FLUTTER_ROOT")"
fi

export PATH="$PATH:$FLUTTER_ROOT/bin"
git config --global --add safe.directory "$FLUTTER_ROOT"
flutter --version

: "${SUPABASE_URL:?falta SUPABASE_URL}"
: "${SUPABASE_PUBLISHABLE_KEY:?falta SUPABASE_PUBLISHABLE_KEY}"

printf 'SUPABASE_URL=%s\nSUPABASE_PUBLISHABLE_KEY=%s\n' \
  "$SUPABASE_URL" "$SUPABASE_PUBLISHABLE_KEY" > .env

flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define-from-file=.env
