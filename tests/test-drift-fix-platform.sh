#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"
trap cleanup_test_repo EXIT
setup_test_repo
cd "$TEST_REPO"

git mv src/api src/http
git commit -q -m "test: rename api directory to http"

# Neither flock nor GNU realpath is part of a standard macOS installation.
# Poison both names to ensure the actual command uses its portable operations.
mkdir -p test-bin
for command_name in flock realpath; do
  cat > "test-bin/$command_name" <<'SH'
#!/usr/bin/env bash
echo "unexpected platform-specific command: $0" >&2
exit 97
SH
  chmod +x "test-bin/$command_name"
done

OUTPUT="$(PATH="$TEST_REPO/test-bin:$PATH" "$SCRIPT_DIR/../scripts/drift-fix.sh")"
echo "$OUTPUT" | jq -e '.links_fixed | length >= 2' >/dev/null
grep -q 'src/http/AGENTS.md' AGENTS.md
grep -q '../http/AGENTS.md' src/core/AGENTS.md
echo "PASS: portable platform operations"
