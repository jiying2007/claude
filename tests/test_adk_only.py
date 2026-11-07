"""Offline regression for the ADK-only Claude consumer; no provider token needed."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
R2 = ROOT / "control/scripts/runtime-r2-local.sh"
START = '"$PYTHON_BIN" - "$MAT/runtime-distribution.json" "$MAT/distribution" "$R2_HOME/.claude" <<\'PY\''


def copy_code():
    raw = R2.read_text()
    after = raw.split(START, 1)[1]
    return after.split("\nPY\n", 1)[0]


class ADKOnlyTests(unittest.TestCase):
    def test_no_live_superpowers_or_injection(self):
        self.assertFalse((ROOT / "vendor/plugins/superpowers").exists())
        self.assertFalse((ROOT / "control/scripts/session-start.sh").exists())
        self.assertFalse((ROOT / "commands/using-skills.md").exists())
        for rel in ("settings.json", "CLAUDE.md", "control/scripts/install.sh",
                    "control/scripts/doctor.sh"):
            s = (ROOT / rel).read_text()
            self.assertNotIn("using-skills", s.lower() if rel == "settings.json" else "")
        self.assertNotIn("SessionStart", (ROOT / "settings.json").read_text())
        self.assertNotIn("hooks", json.loads((ROOT / "settings.json").read_text()))
        self.assertFalse((ROOT / "control/scripts/activate-profile.sh").exists())

    def test_installer_refuses_missing_source_without_live_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            live = home / ".claude"
            live.mkdir()
            marker = live / "settings.json"
            marker.write_text('{"keep":true}')
            env = dict(os.environ, HOME=str(home))
            env.pop("ADK_ROOT", None)
            p = subprocess.run(["bash", str(ROOT/"control/scripts/install.sh")],
                               env=env, text=True, capture_output=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertEqual(marker.read_text(), '{"keep":true}')

    def _probe(self, entries, source_files, existing=None, symlink_parent=False):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            src=root/"source"
            target=root/"target"
            src.mkdir()
            target.mkdir()
            for path,data in source_files.items():
                asset=src/path
                asset.parent.mkdir(parents=True,exist_ok=True)
                asset.write_bytes(data)
            if existing:
                for path,data in existing.items():
                    asset=target/path
                    asset.parent.mkdir(parents=True,exist_ok=True)
                    asset.write_bytes(data)
            if symlink_parent:
                outside=root/"outside"
                outside.mkdir()
                (target/"skills").symlink_to(outside, target_is_directory=True)
            manifest=root/"manifest.json"
            manifest.write_text(json.dumps({"files":entries}))
            p=subprocess.run([sys.executable,"-",str(manifest),str(src),str(target)],
                             input=copy_code(), text=True, capture_output=True)
            values={}
            for path in source_files:
                asset=target/path
                values[path]=asset.read_bytes() if asset.is_file() else None
            return p.returncode,p.stderr,values

    def test_copy_success_and_idempotence(self):
        import hashlib
        data=b"native skill"
        entry={"path":"skills/s/SKILL.md","sha256":hashlib.sha256(data).hexdigest()}
        code,stderr,observed=self._probe([entry],{entry["path"]:data})
        self.assertEqual(code,0,stderr)
        self.assertEqual(observed[entry["path"]],data)
        code,stderr,observed=self._probe([entry],{entry["path"]:data},existing={entry["path"]:data})
        self.assertEqual(code,0,stderr)

    def test_conflict_fails_closed_before_any_copy(self):
        import hashlib
        data=b"adk"
        entries=[
            {"path":"skills/new/SKILL.md","sha256":hashlib.sha256(data).hexdigest()},
            {"path":"skills/old/SKILL.md","sha256":hashlib.sha256(data).hexdigest()},
        ]
        code,stderr,observed=self._probe(entries,{x["path"]:data for x in entries},
                      existing={"skills/old/SKILL.md":b"user-owned"})
        self.assertNotEqual(code,0)
        self.assertIsNone(observed["skills/new/SKILL.md"])
        self.assertEqual(observed["skills/old/SKILL.md"],b"user-owned")

    def test_parent_symlink_fails_closed(self):
        import hashlib
        data=b"adk"
        entry={"path":"skills/s/SKILL.md","sha256":hashlib.sha256(data).hexdigest()}
        code,stderr,_=self._probe([entry],{entry["path"]:data},symlink_parent=True)
        self.assertNotEqual(code,0)
        self.assertIn("symlink",stderr)


if __name__ == "__main__":
    unittest.main()
