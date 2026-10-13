"""Release boundaries: immutable assets, preset restoration and README concurrency."""
import base64
from contextlib import redirect_stderr
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SHA = "1" * 40


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class ReleaseTools(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "docs").mkdir()
        (self.root / "docs/RELEASE-TEMPLATE.md").write_text(
            (ROOT / "docs/RELEASE-TEMPLATE.md").read_text())
        self.publisher = module("publish_release")
        self.addCleanup(patch.stopall)
        patch.object(self.publisher, "ROOT", self.root).start()

    def publish_args(self, *extra):
        return patch.object(sys, "argv", ["publish_release.py", "--tag", "v0.1.0-preview.2",
                                        "--commit", SHA, *extra])

    def test_failed_export_restores_platform_metadata(self):
        packaging = module("package_release")
        original = (ROOT / "export_presets.cfg").read_text()
        presets = self.root / "export_presets.cfg"
        presets.write_text(original)
        def fail_export():
            configured = presets.read_text()
            self.assertIn('application/short_version="9.8.7"', configured)
            self.assertIn('application/file_version="9.8.7.0"', configured)
            raise RuntimeError("Export failed")
        with (
            patch.object(packaging, "ROOT", self.root),
            patch.object(packaging, "package", fail_export),
            patch.object(sys, "argv", ["package_release.py", "--tag", "v9.8.7-preview.1"]),
        ):
            with self.assertRaisesRegex(RuntimeError, "Export failed"):
                packaging.main()
        self.assertEqual(presets.read_text(), original)

    def test_malformed_tag_does_not_start_export(self):
        packaging = module("package_release")
        with (
            patch.object(packaging, "package") as export,
            patch.object(sys, "argv", ["package_release.py", "--tag", "v1.2"]),
            redirect_stderr(io.StringIO()),
        ):
            with self.assertRaises(SystemExit):
                packaging.main()
        export.assert_not_called()

    def test_changed_tag_is_rejected_before_release_mutation(self):
        ref = json.dumps({"object": {"type": "commit", "sha": "2" * 40}})
        with (
            self.publish_args(), patch.object(self.publisher, "gh", return_value=ref) as gh,
            patch.object(self.publisher.subprocess, "run") as mutate,
        ):
            with self.assertRaisesRegex(RuntimeError, "Remote tag no longer"):
                self.publisher.main()
        mutate.assert_not_called()
        self.assertTrue(all(call.args[0] == "api" for call in gh.call_args_list))

    def test_published_release_is_never_clobbered(self):
        ref = json.dumps({"object": {"type": "commit", "sha": SHA}})
        existing = subprocess.CompletedProcess([], 0, stdout=json.dumps({"isDraft": False}), stderr="")
        with (
            self.publish_args(), patch.object(self.publisher, "gh", return_value=ref) as gh,
            patch.object(self.publisher.subprocess, "run", return_value=existing),
        ):
            with self.assertRaisesRegex(RuntimeError, "already published"):
                self.publisher.main()
        self.assertTrue(all(call.args[0] == "api" for call in gh.call_args_list))

    def test_prepare_notes_requires_no_github_access(self):
        with self.publish_args("--prepare-only"), patch.object(self.publisher, "gh") as gh:
            self.publisher.main()
        notes = (self.root / "build/releases/release-notes.md").read_text()
        self.assertNotIn("{{", notes)
        self.assertIn("/download/v0.1.0-preview.2/Hearthwillow-Windows-x64.zip", notes)
        self.assertIn(SHA, notes)
        gh.assert_not_called()

    def test_readme_conflict_preserves_concurrent_content(self):
        text = "Download **0.1.0-preview.1** from [release](https://github.com/CipherAtlas/Hearthwillow/releases/tag/v0.1.0-preview.1).\nKeep this paragraph.\n"
        responses = [
            json.dumps({"sha": "a" * 40, "content": base64.b64encode(text.encode()).decode()}),
            json.dumps({"sha": "b" * 40, "content": base64.b64encode((text+"Concurrent addition.\n").encode()).decode()}),
        ]
        submitted = []
        def update(args, **kwargs):
            body = json.loads(Path(args[-1]).read_text())
            submitted.append(body)
            return subprocess.CompletedProcess(args, 1 if len(submitted)==1 else 0, stdout="",
                                               stderr="HTTP 409" if len(submitted)==1 else "")
        with (
            patch.object(self.publisher, "gh", side_effect=responses),
            patch.object(self.publisher.subprocess, "run", side_effect=update),
        ):
            self.publisher.refresh_readme("CipherAtlas/Hearthwillow", "v0.1.0-preview.2")
        final = base64.b64decode(submitted[-1]["content"]).decode()
        self.assertEqual(submitted[-1]["sha"], "b" * 40)
        self.assertIn("/tag/v0.1.0-preview.2", final)
        self.assertIn("Keep this paragraph.\nConcurrent addition.", final)

    def test_older_build_does_not_replace_newer_readme_links(self):
        text = "[release](https://github.com/CipherAtlas/Hearthwillow/releases/tag/v0.1.0-preview.10)"
        response = json.dumps({"content": base64.b64encode(text.encode()).decode()})
        with (
            patch.object(self.publisher, "gh", return_value=response),
            patch.object(self.publisher.subprocess, "run") as mutate,
        ):
            self.publisher.refresh_readme("CipherAtlas/Hearthwillow", "v0.1.0-preview.2")
        mutate.assert_not_called()


if __name__ == "__main__":
    unittest.main()
