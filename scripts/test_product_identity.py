import os
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def text(path):
    return (ROOT / path).read_text()


class ProductIdentityContractTests(unittest.TestCase):
    def test_canonical_cli_exists_and_is_executable(self):
        cli = ROOT / "scripts" / "uuflow"
        self.assertTrue(cli.is_file())
        self.assertTrue(os.access(cli, os.X_OK))

    def test_old_cli_is_not_kept_as_a_second_entrypoint(self):
        self.assertFalse((ROOT / "scripts" / "snug").exists())

    def test_canonical_cli_supports_external_build_storage(self):
        cli = text("scripts/uuflow")
        self.assertIn("UUFLOW_BUILD_ROOT", cli)
        self.assertIn("prepare_build_storage", cli)
        self.assertLess(cli.index("prepare_build_storage\ncase"), cli.index('case "${1:-help}"'))

    def test_bundle_visible_identity_is_uuflow(self):
        cli = text("scripts/uuflow")
        for line in ["<string>UUFlow</string>", "build/UUFlow.app", "Contents/MacOS/UUFlow"]:
            self.assertIn(line, cli)

    def test_bundle_id_stays_compatible(self):
        self.assertIn('readonly BUNDLE_ID="com.zephyr4123.snug"', text("scripts/uuflow"))

    def test_canonical_install_target_is_uuflow(self):
        self.assertIn("/Applications/UUFlow.app", text("scripts/uuflow"))

    def test_install_commits_only_after_new_process_is_seen(self):
        cli = text("scripts/uuflow")
        self.assertLess(cli.index("uuflow_prepare_install"), cli.index("open /Applications/UUFlow.app"))
        self.assertLess(cli.index("pgrep -f '^/Applications/UUFlow.app"), cli.index("uuflow_commit_install"))

    def test_legacy_app_is_removed_only_by_commit(self):
        helper = text("scripts/install_transaction.zsh")
        before_commit, commit = helper.split("uuflow_commit_install()", 1)
        self.assertNotIn('rm -rf "$UUFLOW_INSTALL_LEGACY"', before_commit)
        self.assertIn('rm -rf "$UUFLOW_INSTALL_LEGACY"', commit)

    def test_runtime_source_has_no_upstream_update_feed(self):
        runtime = "\n".join(path.read_text(errors="ignore") for path in (ROOT / "Sources" / "Snug").rglob("*.swift"))
        self.assertNotIn("dl.zephyrxiang.com/snug", runtime)
        self.assertNotIn("github.com/zephyr4123/snug/releases", runtime)
        self.assertNotIn("latest/update.json", runtime)

    def test_runtime_updater_and_update_ui_are_removed(self):
        for path in ["Sources/Snug/Update/Updater.swift", "Sources/Snug/Update/UpdateClient.swift", "Sources/Snug/UI/UpdateViews.swift"]:
            self.assertFalse((ROOT / path).exists())

    def test_runtime_ui_has_no_update_controls(self):
        runtime = "\n".join(path.read_text(errors="ignore") for path in (ROOT / "Sources" / "Snug").rglob("*.swift"))
        for label in ["软件更新", "更新源", "立即更新", "检查更新", "发现新版本"]:
            self.assertNotIn(label, runtime)

    def test_release_target_is_not_linked_into_the_package(self):
        package = text("Package.swift")
        self.assertNotIn("SnugRelease", package)
        self.assertNotIn("snug-release", package)

    def test_readme_uses_uuflow_repo_without_upstream_downloads(self):
        readme = text("README.md")
        self.assertIn("github.com/YuukiAS/UUFlow", readme)
        self.assertNotIn("zephyr4123/snug/releases", readme)
        self.assertNotIn("dl.zephyrxiang.com/snug", readme)

    def test_about_uses_uuflow_as_primary_identity(self):
        about = text("Sources/Snug/UI/AboutView.swift")
        self.assertIn("AppIdentity.name", about)
        self.assertIn("github.com/YuukiAS/UUFlow", about)


if __name__ == "__main__":
    unittest.main()
