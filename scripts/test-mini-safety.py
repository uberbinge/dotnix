#!/usr/bin/env python3
"""Synthetic checks: no live services, volumes, credentials, or activation."""
import sys
sys.dont_write_bytecode = True

import importlib.util
import re
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MINI = ROOT / "darwin/mini"
spec = importlib.util.spec_from_file_location("env_reader", MINI / "with-container-env.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SafetyTests(unittest.TestCase):
    def test_environment_is_data(self):
        value = b"spaces 'quotes' $(touch /tmp/never) ; = newline\nvalue"
        raw = b"=".join((b"BORG_PASSPHRASE", value)) + b"\0OTHER=ignored\0BORG_EMPTY=\0"
        self.assertEqual(module.read_environment(raw, b"BORG_"),
                         {b"BORG_PASSPHRASE": value, b"BORG_EMPTY": b""})

    def test_actual_activation_snippets_do_not_write_in_dry_run(self):
        for name in ("borgmatic.nix", "services/home-assistant.nix"):
            source = (MINI / name).read_text()
            body = source[source.index("  home.activation."):].split("''", 1)[1].rsplit("'';", 1)[0]
            # Resolve Nix substitutions to inert fixture paths; retain shell expansion.
            body = body.replace("''${DRY_RUN_CMD:-}", "${DRY_RUN_CMD:-}")
            body = "\n".join(line[4:] if line.startswith("    ") else line for line in body.splitlines())
            with tempfile.TemporaryDirectory() as directory:
                body = re.sub(r"\$\{(?!DRY_RUN_CMD)[^}]+\}", directory, body)
                target = Path(directory) / "configuration.yaml"
                target.write_text("original")
                before = {x.name: x.read_bytes() for x in Path(directory).iterdir()}
                subprocess.run(["bash", "-euc", body], env={**os.environ, "DRY_RUN_CMD": "echo"}, check=True, capture_output=True)
                after = {x.name: x.read_bytes() for x in Path(directory).iterdir()}
                self.assertEqual(before, after)

    def test_volume_enrollment(self):
        spec = importlib.util.spec_from_file_location("volumes", MINI / "verify-backup-volumes.py")
        volumes = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(volumes)
        good = {"/source": {"MountPoint": "/source", "VolumeUUID": "AAA"},
                "/dest": {"MountPoint": "/dest", "VolumeUUID": "BBB"}}
        volumes.validate("/source", "/dest", "aaa", "bbb", good.get)
        for first, second in (("", "BBB"), ("BBB", "AAA"), ("AAA", "AAA"), ("wrong", "BBB")):
            with self.assertRaises(ValueError):
                volumes.validate("/source", "/dest", first, second, good.get)
        with self.assertRaises(ValueError):
            volumes.validate("/source", "/dest", "AAA", "BBB", lambda _: {"MountPoint": "/", "VolumeUUID": "AAA"})

    def test_raw_env_secret_write_preserves_literals(self):
        source = (MINI / "services/immich.nix").read_text()
        body = source.split("    case ", 1)[1].split("  '';", 1)[0]
        body = "case " + body
        body = "\n".join(line[4:] if line.startswith("    ") else line for line in body.splitlines())
        with tempfile.TemporaryDirectory() as directory:
            body = body.replace("${serviceConfigDir}", directory)
            value = "abc $DOLLAR ${literal} 'single' \"double\" \\backslash"
            subprocess.run(["bash", "-euc", body], env={**os.environ, "DB_PASSWORD": value}, check=True)
            target = Path(directory) / "secrets.env"
            self.assertIn("DB_PASSWORD=" + value + "\n", target.read_text())
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            result = subprocess.run(["bash", "-euc", body], env={**os.environ, "DB_PASSWORD": "bad\nvalue"}, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("DB_PASSWORD=" + value + "\n", target.read_text())

    def test_local_mirror_dry_run_does_not_create_files(self):
        source = (MINI / "local-backup.nix").read_text()
        body = source.split("    text = ''", 1)[1].split("    '';", 1)[0]
        body = "\n".join(line[6:] if line.startswith("      ") else line for line in body.splitlines())
        body = body.replace("''${1:-}", "${1:-}")
        # Exercise the actual shell with the independently tested disk verifier stubbed.
        start = body.index("${pkgs.python3}")
        end = body.index('if [ ! -d', start)
        body = body[:start] + "true\n" + body[end:]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "source/library").mkdir(parents=True)
            (root / "source/postgres").mkdir()
            for key, value in {"backupSource": str(root / "source"), "backupDest": str(root / "dest"), "logDir": str(root / "logs")}.items():
                body = body.replace("${" + key + "}", value)
            body = 'rsync() { [ "$1" = "-avn" ]; };\n' + body
            subprocess.run(["bash", "-euc", body, "_", "--dry-run"], check=True, capture_output=True)
            self.assertFalse((root / "dest").exists())
            self.assertFalse((root / "logs").exists())

    def test_failed_secret_fetch_discards_partial_output(self):
        source = (MINI / "lib.nix").read_text()
        expression = source.split("    ''$(if secret_value=", 1)[1].split("fi)'';", 1)[0]
        expression = "$(if secret_value=" + expression + "fi)"
        expression = expression.replace("${pkgs.coreutils}/bin/timeout --kill-after=2 20 ", "")
        expression = re.sub(r"\$\{[^}]+\}", "fixture", expression)
        for code in (1, 124, 137):
            script = f"op() {{ printf partial; return {code}; }}; value=" + expression + '; printf "%s" "$value"'
            result = subprocess.run(["bash", "-ec", script], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"")
            self.assertIn(b"failed or timed out", result.stderr)

    def test_borg_late_read_failure_preserves_existing_keys(self):
        source = (MINI / "borgmatic.nix").read_text()
        body = source.split("  secretSetup = ''", 1)[1].split("  '';", 1)[0]
        body = "\n".join(line[4:] if line.startswith("    ") else line for line in body.splitlines())
        body = re.sub(r"\$\{fetch1PasswordSecret \{.*?\}\}", "$(fake_read)", body)
        body = re.sub(r"\$\{validate1PasswordSecret \{.*?\}\}", "", body)
        for fail_at in (4, 5, 6):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "ssh").mkdir()
                (root / "ssh/id_rsa").write_text("original-key")
                (root / "ssh/known_hosts").write_text("original-hosts")
                (root / "secrets.env").write_text("original-env")
                fixture = body.replace("${serviceConfigDir}", directory)
                fixture = re.sub(r"\$\{[^}]+\}", directory, fixture)
                prefix = 'fake_read() { count=$(cat "$COUNTER" 2>/dev/null || echo 0); count=$((count + 1)); echo "$count" > "$COUNTER"; printf dummy; [ "$count" -ne "$FAIL_AT" ]; };\n'
                result = subprocess.run(["bash", "-ec", prefix + fixture], env={**os.environ, "COUNTER": str(root / "counter"), "FAIL_AT": str(fail_at)}, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((root / "ssh/id_rsa").read_text(), "original-key")
                self.assertEqual((root / "ssh/known_hosts").read_text(), "original-hosts")
                self.assertEqual((root / "secrets.env").read_text(), "original-env")
                self.assertFalse(list(root.glob(".secrets.*")))

    def test_bounded_reads_and_network_bindings(self):
        self.assertNotIn("eval $(", (MINI / "borgmatic.nix").read_text())
        self.assertIn("timeout --kill-after=2 20 op read", (MINI / "lib.nix").read_text())
        for name, port in (("immich", 2283), ("paperless", 8000), ("home-assistant", 8123)):
            self.assertIn(f'127.0.0.1:{port}:{port}', (MINI / f"services/{name}.nix").read_text())


if __name__ == "__main__":
    unittest.main()
