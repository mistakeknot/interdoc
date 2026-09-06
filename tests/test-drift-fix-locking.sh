#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/fixtures/setup-test-repo.sh"
trap cleanup_test_repo EXIT
setup_test_repo
cd "$TEST_REPO"

python3 - "$SCRIPT_DIR/../scripts/drift-fix.sh" <<'PY'
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

script = sys.argv[1]
root = Path.cwd()
lock_path = root / ".git/interdoc/fix.lock"
lock_path.parent.mkdir(parents=True)
before = {p: p.read_bytes() for p in root.rglob("AGENTS.md")}
with lock_path.open("w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    result = subprocess.run([script], capture_output=True, text=True, timeout=10)
    assert result.returncode == 1, result
    assert json.loads(result.stdout)["error"] == "another drift-fix instance is running", result
    assert before == {p: p.read_bytes() for p in before}, "contending command changed docs"

# Pause the first real replacement, after acquisition has returned. The lock
# must still belong to the shell while its short-lived lock helper has exited.
bin_dir = root / "test-bin"
bin_dir.mkdir()
marker = root / "replacement-started"
release = root / "release-replacement"
wrapper = bin_dir / "mv"
wrapper.write_text('''#!/usr/bin/env python3
import os,sys,time
from pathlib import Path
Path(os.environ["TEST_LOCK_MARKER"]).touch()
deadline=time.monotonic()+10
while not Path(os.environ["TEST_LOCK_RELEASE"]).exists():
    if time.monotonic()>deadline: raise SystemExit("replacement wait expired")
    time.sleep(0.01)
os.execv(os.environ["TEST_REAL_MV"], [os.environ["TEST_REAL_MV"], *sys.argv[1:]])
''')
wrapper.chmod(0o755)
env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
           TEST_LOCK_MARKER=str(marker), TEST_LOCK_RELEASE=str(release), TEST_REAL_MV=shutil.which("mv"))
worker = subprocess.Popen([script], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    deadline = time.monotonic() + 10
    while not marker.exists():
        assert worker.poll() is None, worker.communicate()
        assert time.monotonic() < deadline, "replacement never started"
        time.sleep(0.01)
    with lock_path.open("w") as contender:
        try:
            fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            pass
        else:
            raise AssertionError("lock was released before document replacements finished")
finally:
    release.touch()
    stdout, stderr = worker.communicate(timeout=15)
assert worker.returncode == 0, (stdout, stderr)
assert json.loads(stdout)["files_modified"], stdout
with lock_path.open("w") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
print("PASS: contention, lock lifetime, and release")
PY
