#!/usr/bin/python3
"""Descriptor-bound runner tests. Uses a temp HOME / XDG_RUNTIME_DIR / plugin tree."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUNNER_SRC = os.path.join(ROOT, "bin", "aegis-run")


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def digest_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write(path: str, data: str, mode: int = 0o644) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(data)
    os.chmod(path, mode)


def layout(tmp: str, fake_cli: str) -> dict[str, str]:
    home = os.path.join(tmp, "home")
    xdg = os.path.join(tmp, "run")
    plugin = os.path.join(tmp, "plugin")
    local_bin = os.path.join(home, ".local", "bin")
    os.makedirs(local_bin, mode=0o700)
    os.makedirs(xdg, mode=0o700)
    os.makedirs(os.path.join(plugin, "bin"), mode=0o700)
    os.chmod(home, 0o700)
    shutil.copy(RUNNER_SRC, os.path.join(plugin, "bin", "aegis-run"))
    os.chmod(os.path.join(plugin, "bin", "aegis-run"), 0o755)
    dest = os.path.join(local_bin, "aegis")
    shutil.copy(fake_cli, dest)
    os.chmod(dest, 0o755)
    write(os.path.join(plugin, "cli.sha256"), digest_of(dest) + "  aegis-x86_64-unknown-linux-gnu\n")
    return {
        "home": home,
        "xdg": xdg,
        "plugin": plugin,
        "runner": os.path.join(plugin, "bin", "aegis-run"),
        "cli": dest,
    }


def env_for(paths: dict[str, str]) -> dict[str, str]:
    return {
        "HOME": paths["home"],
        "XDG_RUNTIME_DIR": paths["xdg"],
        "PATH": "/usr/bin:/bin",
        "LC_ALL": "C",
    }


def run_helper(paths: dict[str, str], args: list[str], stdin: bytes | None = None, timeout: float = 8) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["/usr/bin/python3", paths["runner"], *args],
        input=stdin,
        capture_output=True,
        env=env_for(paths),
        timeout=timeout,
        check=False,
    )


def test_resolve_and_mismatch() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        paths = layout(tmp, "/usr/bin/true")
        got = run_helper(paths, ["resolve"])
        if got.returncode != 0:
            fail(f"resolve failed: {got.stderr!r}")
        if paths["cli"] not in got.stdout.decode():
            fail(f"resolve stdout {got.stdout!r}")
        write(os.path.join(paths["plugin"], "cli.sha256"), "0" * 64 + "  aegis\n")
        bad = run_helper(paths, ["resolve"])
        if bad.returncode == 0:
            fail("resolve accepted a mismatched digest")
        err = bad.stderr.decode()
        if "digest" not in err.lower() and "attested" not in err.lower():
            fail(f"mismatch error unclear: {err!r}")


def test_passfile_via_run() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        fake = os.path.join(tmp, "fake-cli")
        write(
            fake,
            "#!/usr/bin/python3\n"
            "import os, sys, stat\n"
            "i = sys.argv.index('--passphrase-file')\n"
            "path = sys.argv[i + 1]\n"
            "st = os.stat(path)\n"
            "assert stat.S_ISREG(st.st_mode)\n"
            "assert (st.st_mode & 0o777) == 0o600\n"
            "print(open(path).read(), end='')\n",
            0o755,
        )
        paths = layout(tmp, fake)
        payload = json.dumps({"pass": "hunter2-secret"}) + "\n"
        got = run_helper(
            paths,
            ["run", "--timeout-ms", "5000", "--max-bytes", "4096", "--role", "pass", "--"],
            stdin=payload.encode(),
        )
        if got.returncode != 0:
            fail(f"run/passfile failed: {got.stderr!r} {got.stdout!r}")
        if "hunter2-secret" not in got.stdout.decode():
            fail(f"passfile content not delivered: {got.stdout!r}")
        leftover = []
        runtime = os.path.join(paths["xdg"], "aegis-omarchy")
        if os.path.isdir(runtime):
            leftover = os.listdir(runtime)
        if leftover:
            fail(f"passfile leaked: {leftover}")


def test_timeout_kills_group() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        paths = layout(tmp, "/usr/bin/sleep")
        t0 = time.monotonic()
        got = run_helper(
            paths,
            ["run", "--timeout-ms", "400", "--max-bytes", "4096", "--", "2"],
            stdin=b"{}\n",
            timeout=8,
        )
        elapsed = time.monotonic() - t0
        if got.returncode == 0:
            fail("sleep should have been killed")
        if elapsed > 3:
            fail(f"timeout too slow: {elapsed:.2f}s")
        if b"timed out" not in got.stderr:
            fail(f"timeout stderr {got.stderr!r}")


def test_output_cap() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        paths = layout(tmp, "/usr/bin/yes")
        got = run_helper(
            paths,
            ["run", "--timeout-ms", "3000", "--max-bytes", "256", "--"],
            stdin=b"{}\n",
            timeout=8,
        )
        if got.returncode == 0:
            fail("yes should have been capped")
        if b"exceeded" not in got.stderr:
            fail(f"cap stderr {got.stderr!r}")


def test_symlink_xdg_rejected() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        paths = layout(tmp, "/usr/bin/true")
        real = os.path.join(tmp, "real-run")
        os.makedirs(real, mode=0o700)
        os.symlink(real, os.path.join(tmp, "xdg-link"))
        env = env_for(paths)
        env["XDG_RUNTIME_DIR"] = os.path.join(tmp, "xdg-link")
        got = subprocess.run(
            [
                "/usr/bin/python3",
                paths["runner"],
                "run",
                "--timeout-ms",
                "2000",
                "--role",
                "pass",
                "--",
            ],
            input=json.dumps({"pass": "x"}).encode() + b"\n",
            capture_output=True,
            env=env,
            timeout=8,
            check=False,
        )
        if got.returncode == 0:
            fail("symlink XDG_RUNTIME_DIR was accepted")
        if b"symlink" not in got.stderr and b"refusing" not in got.stderr:
            fail(f"symlink reject unclear: {got.stderr!r}")


def test_source_invariants() -> None:
    src = open(RUNNER_SRC, encoding="utf-8").read()
    qml = open(os.path.join(ROOT, "Service.qml"), encoding="utf-8").read()
    overlay = open(os.path.join(ROOT, "Overlay.qml"), encoding="utf-8").read()
    if "#!/usr/bin/env" in src:
        fail("aegis-run uses env shebang")
    if "mktemp" in src:
        fail("aegis-run uses mktemp")
    if ".cargo/bin" in src:
        fail("aegis-run still searches ~/.cargo/bin")
    if "PATH=" in src and '"PATH": "/usr/bin:/bin"' not in src:
        fail("closed env PATH missing")
    if "bash -c" in qml or "command -v" in qml:
        fail("Service.qml still discovers CLI via bash/PATH")
    if "waitForEnd: true" in qml or "waitForEnd: true" in overlay:
        fail("unbounded StdioCollector(waitForEnd: true) still present")
    if "abortJob" not in qml or "proc.signal(15)" not in qml:
        fail("Service.qml missing TERM/KILL watchdog")
    if "liveLines" not in qml or "text.length > 256" not in qml:
        fail("lock watcher missing a live line cap")
    if '"env"' in qml and "/usr/bin/env" not in qml:
        fail("Service.qml still PATH-resolves env")
    if "/usr/bin/python3" not in qml or "/usr/bin/setpriv" not in qml:
        fail("Service.qml missing absolute helpers")
    if '["wl-copy"]' in overlay or '["git"' in overlay or "xdg-open" in overlay:
        fail("Overlay.qml still PATH-resolves helpers")
    if "git clone" in overlay or "cargo install" in overlay:
        fail("Overlay.qml still documents cargo source build")
    for dead in ("bin/aegis-passfile", "bin/aegis-session-watch"):
        if os.path.exists(os.path.join(ROOT, dead)):
            fail(f"leftover helper {dead}")


def main() -> None:
    test_source_invariants()
    test_resolve_and_mismatch()
    test_passfile_via_run()
    test_timeout_kills_group()
    test_output_cap()
    test_symlink_xdg_rejected()
    print("aegis-run-test.py ok")


if __name__ == "__main__":
    main()
