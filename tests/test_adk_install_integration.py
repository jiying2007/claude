"""Real ADK 10.x source-to-isolated-Claude-home plan/apply/rollback regression.

No provider credentials, model calls, network, or user live home. The CI workflow
pins the source checkout independently and must set CLAUDE_E2E_ADK_ROOT.
"""
from __future__ import annotations
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA = "af4304d080aa32753b5d717f591fb6d2d715b8fb"


class ActualADKInstallTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        value = os.environ.get("CLAUDE_E2E_ADK_ROOT")
        if not value:
            raise RuntimeError("CLAUDE_E2E_ADK_ROOT required: no simulated provider")
        cls.provider = Path(value).resolve()
        output = subprocess.check_output(
            ["git", "-C", str(cls.provider), "rev-parse", "HEAD"], text=True
        ).strip()
        if output != SOURCE_SHA:
            raise RuntimeError(f"ADK source identity drift: {output}")
        if subprocess.check_output(
            ["git", "-C", str(cls.provider), "status", "--porcelain=v1", "--untracked-files=all"],
            text=True,
        ).strip():
            raise RuntimeError("ADK source checkout must be clean")

    def env(self, home: Path, target: Path):
        return {
            **os.environ,
            "HOME": str(home),
            "CLAUDE_CONFIG_DIR": str(target),
            "ADK_ROOT": str(self.provider),
        }

    def wrapper(self, env: dict[str, str], *args: str):
        return subprocess.run(
            ["bash", str(ROOT / "control/scripts/install.sh"), *args],
            env=env, text=True, capture_output=True, timeout=150,
        )

    def test_plan_apply_and_rollback_do_not_change_user_settings(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "private-home"
            home.mkdir()
            target = home / "custom-claude-config"
            target.mkdir()
            settings = target / "settings.json"
            settings.write_text('{"user_owned":true}', encoding="utf-8")
            command = target / "commands" / "local.md"
            command.parent.mkdir()
            command.write_text("# User command", encoding="utf-8")
            agent = target / "agents" / "local.md"
            agent.parent.mkdir()
            agent.write_text("# User agent", encoding="utf-8")
            env = self.env(home, target)
            plan_path = Path(td) / "reviewed-plan.json"
            result = self.wrapper(env, "--profile", "core", "--plan-out", str(plan_path))
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertFalse((target / "skills").exists())
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            self.assertEqual(plan["tool"], "claude-code")
            self.assertEqual(plan["asset_kind"], "skill")
            self.assertEqual(plan["status"], "ready")
            self.assertEqual(plan["target"], str(target.resolve()))
            self.assertTrue(plan["operations"])
            self.assertTrue(all(op["destination"].startswith("skills/") for op in plan["operations"]))
            applied = self.wrapper(env, "--apply-plan", str(plan_path))
            self.assertEqual(applied.returncode, 0, applied.stderr + applied.stdout)
            self.assertTrue((target / "skills" / "adk-runtime-router" / "SKILL.md").is_file())
            receipt = target / ".adk-install-receipt.json"
            self.assertTrue(receipt.is_file())
            self.assertEqual(settings.read_text(encoding="utf-8"), '{"user_owned":true}')
            self.assertEqual(command.read_text(encoding="utf-8"), "# User command")
            self.assertEqual(agent.read_text(encoding="utf-8"), "# User agent")
            # Exact reviewed receipt is required for the ADK native rollback.
            rollback = subprocess.run(
                ["bash", str(self.provider / "scripts/devkit.sh"),
                 "install", "rollback", "--receipt", str(receipt)],
                env=env, text=True, capture_output=True, timeout=150,
            )
            self.assertEqual(rollback.returncode, 0, rollback.stderr + rollback.stdout)
            self.assertFalse((target / "skills" / "adk-runtime-router" / "SKILL.md").exists())
            self.assertEqual(settings.read_text(encoding="utf-8"), '{"user_owned":true}')
            self.assertTrue(command.is_file())
            self.assertTrue(agent.is_file())

    def test_unmanaged_skill_blocks_reviewed_apply_without_overwrite(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "home"
            home.mkdir()
            target = home / ".claude"
            target.mkdir()
            marker = target / "skills" / "adk-runtime-router" / "SKILL.md"
            marker.parent.mkdir(parents=True)
            marker.write_bytes(b"Unmanaged user Skill")
            env = self.env(home, target)
            plan_path = Path(td) / "conflict.json"
            planned = self.wrapper(env, "--profile", "core", "--plan-out", str(plan_path))
            self.assertEqual(planned.returncode, 0, planned.stderr + planned.stdout)
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            self.assertEqual(plan["status"], "needs-review")
            blocked = self.wrapper(env, "--apply-plan", str(plan_path))
            self.assertNotEqual(blocked.returncode, 0)
            self.assertEqual(marker.read_bytes(), b"Unmanaged user Skill")
            self.assertFalse((target / "skills" / "adk-requirements-triage").exists())
            self.assertFalse((target / ".adk-install-receipt.json").exists())

    def test_wrong_live_root_rejected_before_adk_apply(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "home"
            home.mkdir()
            one = home / "config-one"
            two = home / "config-two"
            one.mkdir()
            two.mkdir()
            plan_path = Path(td) / "prepared.json"
            prepared = self.wrapper(self.env(home, one), "--plan-out", str(plan_path))
            self.assertEqual(prepared.returncode, 0, prepared.stderr + prepared.stdout)
            blocked = self.wrapper(self.env(home, two), "--apply-plan", str(plan_path))
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("target differs", blocked.stderr)
            self.assertFalse((one / "skills").exists())
            self.assertFalse((two / "skills").exists())


if __name__ == "__main__":
    unittest.main()
