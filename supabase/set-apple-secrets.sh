#!/usr/bin/env bash
#
# set-apple-secrets.sh — the last backend step before submission.
#
# Turns on Sign in with Apple token revocation (App Store Guideline 5.1.1(v)):
# stores the Apple key as Supabase secrets, then redeploys the two functions
# that use it.
#
# Usage, from the repo root:
#
#   ./supabase/set-apple-secrets.sh <KEY_ID> <path/to/AuthKey_KEYID.p8>
#
# The Key ID is the 10-character ID shown next to the key in the Apple Developer
# portal (Certificates, Identifiers & Profiles → Keys). The .p8 is the file you
# downloaded when creating it — Apple only lets you download it once.
#
# Never commit the .p8. Keep it in a password manager.

set -euo pipefail

TEAM_ID="C2N3Q4846H"          # from DEVELOPMENT_TEAM in project.pbxproj
CLIENT_ID="com.spasht.app"    # the app's bundle ID — NOT com.spasht.app1

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <KEY_ID> <path/to/AuthKey_KEYID.p8>" >&2
  exit 1
fi

KEY_ID="$1"
P8_PATH="$2"

if [[ ! "$KEY_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "✗ Key ID should be 10 capital letters/digits, e.g. AB12CD34EF. Got: $KEY_ID" >&2
  exit 1
fi

if [[ ! -f "$P8_PATH" ]]; then
  echo "✗ No file at $P8_PATH" >&2
  exit 1
fi

if ! grep -q "BEGIN PRIVATE KEY" "$P8_PATH"; then
  echo "✗ $P8_PATH doesn't look like an Apple .p8 key (no BEGIN PRIVATE KEY line)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

echo "→ Setting Apple secrets (team $TEAM_ID, client $CLIENT_ID, key $KEY_ID)…"
supabase secrets set \
  APPLE_TEAM_ID="$TEAM_ID" \
  APPLE_CLIENT_ID="$CLIENT_ID" \
  APPLE_KEY_ID="$KEY_ID" \
  APPLE_PRIVATE_KEY="$(cat "$P8_PATH")"

# Redeployed so the functions pick up the corrected bundle-ID fallback in
# _shared/apple.ts as well as the new secrets. verify_jwt stays on (the
# default) — never pass --no-verify-jwt here.
echo "→ Redeploying apple-register-code and delete-account…"
supabase functions deploy apple-register-code
supabase functions deploy delete-account

echo "→ Checking…"
missing=0
secrets="$(supabase secrets list)"
for name in APPLE_TEAM_ID APPLE_CLIENT_ID APPLE_KEY_ID APPLE_PRIVATE_KEY; do
  if grep -q "$name" <<<"$secrets"; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name missing"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "✗ Some secrets didn't save. Re-run the script." >&2
  exit 1
fi

cat <<'EOF'

✓ Done. To prove it works, on a physical iPhone:
  1. Sign in with Apple in Spasht.
  2. Supabase → Table Editor → apple_tokens: a row for that user should appear.
     (If not: supabase functions logs apple-register-code)
  3. Profile → Delete Account → complete the flow.
  4. iPhone Settings → [your name] → Sign in with Apple:
     Spasht should no longer be listed.
EOF
