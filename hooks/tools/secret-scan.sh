#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r file; do
  # Ignore empty lines in the input stream.
  [[ -z "$file" ]] && continue

  base_name="$(basename "$file")"

  case "$base_name" in
    .env*|*.pem|*.key|credentials.json|secrets.json|secrets.yml|id_rsa|id_ed25519|.npmrc|.netrc|service-account.json|gcloud-credentials.json)
      echo "SKIP: $file (dangerous filename)" >&2
      continue
      ;;
  esac

  if [[ -f "$file" ]]; then
    if grep -E -q 'AKIA[0-9A-Z]{16}|-----BEGIN.*PRIVATE KEY-----|ghp_[a-zA-Z0-9]{36}|xox[baprs]-[0-9]{10}' "$file"; then
      echo "SKIP: $file (secret-like content detected)" >&2
      continue
    fi
  fi

  printf '%s\n' "$file"
done
