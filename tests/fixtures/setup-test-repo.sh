#!/usr/bin/env bash

set -euo pipefail

setup_test_repo() {
  TEST_REPO=$(mktemp -d)
  export TEST_REPO

  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test User"

  mkdir -p "$TEST_REPO/src/api" "$TEST_REPO/src/core" "$TEST_REPO/lib"

  cat > "$TEST_REPO/AGENTS.md" <<'AGENTS'
# Root AGENTS

## Key Files

| File | Purpose |
|------|---------|
| `src/api/handler.ts` | API request handler |
| `src/core/engine.ts` | Core engine |
| `lib/utils.ts` | Shared utilities |

## Architecture

See [API docs](src/api/AGENTS.md) and [Core docs](src/core/AGENTS.md).
AGENTS

  cat > "$TEST_REPO/src/api/AGENTS.md" <<'AGENTS'
# API AGENTS

## Key Files

| File | Purpose |
|------|---------|
| `handler.ts` | Request handler |
| `middleware.ts` | Auth middleware |
| `routes.ts` | Route definitions |

## Related

- See [Core docs](../core/AGENTS.md).
AGENTS

  cat > "$TEST_REPO/src/core/AGENTS.md" <<'AGENTS'
# Core AGENTS

## Key Files

- `engine.ts` — Engine runtime
- `scheduler.ts` — Scheduling logic
- `worker.ts` — Worker pool

## Related

- See [API docs](../api/AGENTS.md).
AGENTS

  cat > "$TEST_REPO/src/api/handler.ts" <<'EOF_HANDLER'
export const handler = () => "handler";
EOF_HANDLER

  cat > "$TEST_REPO/src/api/middleware.ts" <<'EOF_MW'
export const middleware = () => "middleware";
EOF_MW

  cat > "$TEST_REPO/src/api/routes.ts" <<'EOF_ROUTES'
export const routes = [];
EOF_ROUTES

  cat > "$TEST_REPO/src/core/engine.ts" <<'EOF_ENGINE'
export const engine = () => "engine";
EOF_ENGINE

  cat > "$TEST_REPO/src/core/scheduler.ts" <<'EOF_SCHED'
export const scheduler = () => "scheduler";
EOF_SCHED

  cat > "$TEST_REPO/src/core/worker.ts" <<'EOF_WORKER'
export const worker = () => "worker";
EOF_WORKER

  cat > "$TEST_REPO/lib/utils.ts" <<'EOF_UTILS'
export const utils = {};
EOF_UTILS

  git -C "$TEST_REPO" add -A
  git -C "$TEST_REPO" commit -q -m "test: initial docs and files"

  git -C "$TEST_REPO" mv src/api/handler.ts src/api/controller.ts
  git -C "$TEST_REPO" commit -q -m "test: rename handler to controller"

  git -C "$TEST_REPO" rm -q src/core/worker.ts
  git -C "$TEST_REPO" commit -q -m "test: remove worker"

  cat > "$TEST_REPO/src/core/cache.ts" <<'EOF_CACHE'
export const cache = new Map();
EOF_CACHE
  git -C "$TEST_REPO" add src/core/cache.ts
  git -C "$TEST_REPO" commit -q -m "test: add cache file"

  git -C "$TEST_REPO" mv src/api/middleware.ts src/api/auth.ts
  git -C "$TEST_REPO" commit -q -m "test: rename middleware to auth"
}

cleanup_test_repo() {
  if [ -n "${TEST_REPO:-}" ] && [ -d "$TEST_REPO" ]; then
    rm -rf "$TEST_REPO"
  fi
  unset TEST_REPO || true
}

export -f setup_test_repo
export -f cleanup_test_repo
