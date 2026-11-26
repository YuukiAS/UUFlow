import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / "scripts" / "install_transaction.zsh"


def make_app(path: Path, *, name="UUFlow", bundle="com.zephyr4123.snug", marker="new"):
    (path / "Contents" / "MacOS").mkdir(parents=True)
    with (path / "Contents" / "Info.plist").open("wb") as file:
        plistlib.dump({"CFBundleDisplayName": name, "CFBundleIdentifier": bundle, "CFBundleExecutable": "UUFlow"}, file)
    executable = path / "Contents" / "MacOS" / "UUFlow"
    executable.write_text("#!/bin/sh\n")
    executable.chmod(0o755)
    (path / "marker").write_text(marker)


class InstallTransactionTests(unittest.TestCase):
    def run_zsh(self, body, cwd):
        return subprocess.run(["zsh", "-c", f'source "{HELPER}"\n{body}'], cwd=cwd, text=True, capture_output=True)

    def test_legacy_removed_only_after_commit(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); apps = root / "Applications"; apps.mkdir()
            make_app(root / "UUFlow.app")
            make_app(apps / "Snug.app", name="Snug", marker="legacy")
            result = self.run_zsh('uuflow_prepare_install "$PWD/UUFlow.app" "$PWD/Applications" || exit\n'
                                  '[[ -d Applications/Snug.app && -d Applications/UUFlow.app ]] || exit 3\n'
                                  'uuflow_commit_install', root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((apps / "Snug.app").exists())
            self.assertEqual((apps / "UUFlow.app" / "marker").read_text(), "new")

    def test_invalid_candidate_keeps_existing_apps(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); apps = root / "Applications"; apps.mkdir()
            make_app(root / "UUFlow.app", bundle="invalid.bundle")
            make_app(apps / "UUFlow.app", marker="old")
            make_app(apps / "Snug.app", name="Snug", marker="legacy")
            result = self.run_zsh('uuflow_prepare_install "$PWD/UUFlow.app" "$PWD/Applications"', root)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((apps / "UUFlow.app" / "marker").read_text(), "old")
            self.assertTrue((apps / "Snug.app").exists())

    def test_rollback_restores_previous_uuflow_and_keeps_legacy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); apps = root / "Applications"; apps.mkdir()
            make_app(root / "UUFlow.app", marker="new")
            make_app(apps / "UUFlow.app", marker="old")
            make_app(apps / "Snug.app", name="Snug", marker="legacy")
            result = self.run_zsh('uuflow_prepare_install "$PWD/UUFlow.app" "$PWD/Applications" || exit\n'
                                  'uuflow_rollback_install', root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((apps / "UUFlow.app" / "marker").read_text(), "old")
            self.assertTrue((apps / "Snug.app").exists())


if __name__ == "__main__":
    unittest.main()
