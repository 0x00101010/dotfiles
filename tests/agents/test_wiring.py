#!/usr/bin/env python3
"""Apply only agent files in disposable homes; never run machine bootstrap."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
OVERRIDES = REPO / "home/.chezmoiscripts/run_after_30_configure_agent_overrides.sh.tmpl"
SKILLS = ("agent-browser", "beautiful-mermaid", "plan", "pr")


class AgentWiringTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home with 'quotes' and $dollars"
        self.home.mkdir()
        # Deliberately use the install.sh symlink layout, not only --source REPO.
        self.source = self.root / "source link"
        self.source.symlink_to(REPO / "home", target_is_directory=True)
        self.env = dict(os.environ)
        for key in ("CLAUDE_CONFIG_DIR", "CODEX_HOME", "CHEZMOI_SOURCE_DIR"):
            self.env.pop(key, None)
        self.env.update(
            HOME=str(self.home),
            XDG_CONFIG_HOME=str(self.home / ".config"),
            XDG_DATA_HOME=str(self.home / ".local/share"),
            XDG_CACHE_HOME=str(self.home / ".cache"),
            XDG_STATE_HOME=str(self.home / ".local/state"),
        )

    def cm(self, *args, input=None, check=True):
        result = subprocess.run(
            ["chezmoi", "--source", str(self.source), "--destination", str(self.home),
             "--no-tty", *args],
            input=input, env=self.env, cwd=self.home, text=True, capture_output=True,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def init(self, profile="work", agents="claude/codex/amp"):
        self.cm("init", "--prompt", "--promptChoice", f"Machine profile={profile}",
                "--promptMultichoice", f"Coding agents to install={agents}",
                "--promptString", "What is your email address=test@example.com",
                "--promptString", "What is your name=Test",
                "--promptString", "What is your GPG signing key=TEST")

    def apply(self):
        paths = self.cm("managed", "--include=files,symlinks").stdout.splitlines()
        targets = [str(self.home / p) for p in paths if p.startswith(
            (".claude/", ".codex/", ".config/amp/", ".agents/skills/")
        )]
        # No targets must never turn into a whole-home apply.
        if targets:
            self.cm("apply", "--exclude=scripts", "--parent-dirs", "--force", *targets)
        script = self.cm("execute-template", input=OVERRIDES.read_text()).stdout
        result = subprocess.run(["bash"], input=script, env=self.env, cwd=self.home,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def skills(self, destination):
        for name in SKILLS:
            source = REPO / "ai/skills" / name
            self.assertTrue((destination / name / "SKILL.md").is_file())
            for file in source.rglob("*"):
                if file.is_file():
                    installed = destination / name / file.relative_to(source)
                    self.assertTrue(installed.is_symlink(), installed)
                    self.assertEqual(installed.resolve(), file)
                    self.assertEqual(installed.read_bytes(), file.read_bytes())
                    self.assertEqual(installed.stat().st_mode & 0o111, file.stat().st_mode & 0o111)
        plan = (destination / "plan/SKILL.md").read_text()
        self.assertIn("~/.agents/skills/_shared/instructions.md", plan)
        self.assertIn("<plan-root>/<project>/plans/<plan-name>.md", plan)
        self.assertTrue((destination / "_shared/instructions.md").is_file())
        for stale in ("~/src/workspace", "workspace.md", "`repos`", "`workon`"):
            self.assertNotIn(stale, plan)

    def instructions(self, paths, profile):
        context = self.home / ("src/0x00101010/coinbase" if profile == "work" else "src/workspace")
        projects = context / ("projects" if profile == "work" else "projects/personal")
        shared = self.home / ".agents/skills/_shared/instructions.md"
        for path in [*paths, shared]:
            text = path.read_text()
            if path != shared:
                self.assertTrue(text.startswith((REPO / "ai/instructions/AGENTS.md").read_text()))
                self.assertIn(str(shared), text)
            self.assertIn(f"- Machine profile: `{profile}`.", text)
            self.assertIn(f"- Plan root: `{projects}`;", text)
            self.assertIn(f"`{context}/knowledge/references/repos.md`", text)
            self.assertNotIn("src/workspace" if profile == "work" else "0x00101010/coinbase", text)
        text = shared.read_text()
        self.assertIn(f"All paths below are relative to `{context}`.", text)
        self.assertNotIn("todos/", text)
        self.assertNotIn("## Archive procedure", text)
        self.assertIn("## Retired task lists", text)
        if profile == "work":
            self.assertIn("setup/", text)
            self.assertNotIn("identity/", text)
            self.assertNotIn("schedules/", text)
        else:
            self.assertIn("schedules/<YYYY>/", text)
            self.assertIn("inbox.md\nschedules/", text)
            self.assertNotIn("projects/work", text)
        return projects

    def test_fresh_work_and_repeat(self):
        self.init()
        self.apply()
        paths = [self.home / p for p in (".claude/CLAUDE.md", ".codex/AGENTS.md")]
        projects = self.instructions(paths, "work")
        settings = self.home / ".claude/settings.json"
        self.assertEqual(json.loads(settings.read_text())["plansDirectory"], str(projects))
        self.skills(self.home / ".claude/skills")
        self.skills(self.home / ".agents/skills")
        self.assertEqual(sorted(p.name for p in (self.home / ".claude/skills").iterdir()),
                         ["_shared", *SKILLS])
        shared = self.home / ".agents/skills/_shared/instructions.md"
        self.assertEqual((self.home / ".claude/skills/_shared/instructions.md").resolve(), shared)
        self.assertFalse((self.home / ".claude/skills/_shared/workspace.md").exists())
        self.assertFalse((self.home / "src/workspace").exists())
        self.assertFalse((self.home / ".config/amp/AGENTS.md").exists())
        before = [p.read_bytes() for p in [*paths, settings, shared]]
        self.apply()
        self.assertEqual(before, [p.read_bytes() for p in [*paths, settings, shared]])
        self.skills(self.home / ".claude/skills")
        self.skills(self.home / ".agents/skills")

    def test_personal(self):
        self.source = REPO  # Also cover the .chezmoiroot layout.
        self.init("personal")
        self.apply()
        self.instructions([self.home / ".claude/CLAUDE.md"], "personal")
        self.skills(self.home / ".claude/skills")
        self.skills(self.home / ".agents/skills")
        self.assertTrue((self.home / ".claude/skills/qmd/SKILL.md").exists())
        self.assertTrue((self.home / ".claude/skills/journal/SKILL.md").exists())
        self.assertFalse((self.home / ".claude/skills/add/SKILL.md").exists())
        self.assertNotIn(".claude/skills/add/SKILL.md", self.cm("managed").stdout.splitlines())
        self.assertFalse((self.home / "src/0x00101010/coinbase").exists())
        for name in ("journal", "prio"):
            skill = self.home / ".claude/skills" / name
            text = (skill / "SKILL.md").read_text()
            self.assertIn("../_shared/instructions.md", text)
            self.assertTrue((skill / "../_shared/instructions.md").is_file())
            for stale in ("workspace.md", "~/src/workspace", "work.md", "projects/work",
                          "todos/", "archive procedure"):
                self.assertNotIn(stale, text)

    def test_context_changes_with_profile_without_deleting_local_notes(self):
        self.init()
        self.write(self.home / ".claude/skills/_shared/local.md", "local notes")
        self.write(self.home / ".claude/skills/_shared/workspace.md", "legacy copy for review")
        for profile in ("work", "personal", "work"):
            self.init(profile)
            self.apply()
            self.instructions([self.home / ".claude/CLAUDE.md"], profile)
            self.assertEqual((self.home / ".claude/skills/_shared/instructions.md").read_bytes(),
                             (self.home / ".agents/skills/_shared/instructions.md").read_bytes())
        self.assertEqual((self.home / ".claude/skills/_shared/local.md").read_text(), "local notes")
        self.assertEqual((self.home / ".claude/skills/_shared/workspace.md").read_text(),
                         "legacy copy for review")

    def test_existing_settings_and_stale_managed_files(self):
        self.init()
        settings = self.home / ".claude/settings.json"
        original = {
            "model": "company-model", "sandbox": {"enabled": True},
            "permissions": {"allow": [], "deny": ["Bash(curl:*)"],
                            "ask": ["Bash(git push:*)"], "defaultMode": "plan"},
            "env": {"COMPANY_SETTING": "keep", "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "0"},
            "enabledPlugins": {"company-plugin": True, "hookify@claude-plugins-official": False},
            "hooks": {"SessionStart": []}, "statusLine": {"type": "command", "command": "custom-status"},
        }
        self.write(settings, json.dumps(original))
        self.write(self.home / ".claude/CLAUDE.md", "old instructions")
        self.write(self.home / ".claude/skills/pr/SKILL.md", "old PR skill")
        for root in (".claude/skills", ".agents/skills"):
            for file in ("plan/SKILL.md", "beautiful-mermaid/scripts/render.ts",
                         "agent-browser/references/authentication.md"):
                self.write(self.home / root / file, "old managed copy")
        preserved = [".claude/skills/company/SKILL.md", ".claude/skills/pr/local-notes.md",
                     ".claude/skills/agent-browser/references/local.md",
                     ".agents/skills/beautiful-mermaid/scripts/local.ts",
                     ".agents/skills/plan/notes.md",
                     ".claude/managed-settings.json", ".codex/config.toml", ".codex/auth.json",
                     ".config/amp/settings.json", ".config/amp/plugins/company.ts",
                     ".cache/amp/global-skills/company/SKILL.md"]
        for p in preserved:
            self.write(self.home / p, "untouched")
        (self.home / ".config/amp/AGENTS.md").symlink_to(self.home / ".claude/CLAUDE.md")
        self.apply()
        result = json.loads(settings.read_text())
        for key in ("model", "sandbox", "env", "hooks", "statusLine"):
            self.assertEqual(result[key], original[key])
        self.assertEqual(result["permissions"]["allow"], [])
        self.assertEqual(result["permissions"]["ask"], ["Bash(git push:*)"])
        self.assertEqual(result["permissions"]["defaultMode"], "plan")
        self.assertEqual(set(result["permissions"]["deny"]),
                         {"Bash(curl:*)", "Read(.env*)", "Read(**/secrets/**)", "Read(**/*.key)"})
        self.assertFalse(result["enabledPlugins"]["hookify@claude-plugins-official"])
        self.assertTrue(result["enabledPlugins"]["company-plugin"])
        self.assertTrue((self.home / ".config/amp/AGENTS.md").is_symlink())
        self.assertEqual((self.home / ".config/amp/AGENTS.md").readlink(), self.home / ".claude/CLAUDE.md")
        self.skills(self.home / ".claude/skills")
        self.skills(self.home / ".agents/skills")
        for p in preserved:
            self.assertEqual((self.home / p).read_text(), "untouched")

    def test_amp_only_installs_shared_skill_without_configuration(self):
        self.init(agents="amp")
        self.apply()
        self.assertFalse((self.home / ".config/amp/AGENTS.md").exists())
        self.assertFalse(any(p.startswith(".config/amp/") for p in self.cm("managed").stdout.splitlines()))
        self.assertFalse((self.home / ".claude").exists())
        self.assertFalse((self.home / ".codex").exists())
        self.skills(self.home / ".agents/skills")
        self.instructions([], "work")

    def test_codex_only_installs_shared_bundles(self):
        self.init(agents="codex")
        self.apply()
        self.skills(self.home / ".agents/skills")
        self.instructions([self.home / ".codex/AGENTS.md"], "work")
        self.assertFalse((self.home / ".claude").exists())
        self.assertFalse((self.home / ".config/amp/AGENTS.md").exists())

    def test_no_agents_preserves_existing_files(self):
        self.init(agents="")
        self.write(self.home / ".claude/CLAUDE.md", "not selected")
        self.apply()
        self.assertEqual((self.home / ".claude/CLAUDE.md").read_text(), "not selected")
        for name in SKILLS:
            self.assertFalse((self.home / ".agents/skills" / name).exists())
        self.assertFalse((self.home / ".agents/skills/_shared/instructions.md").exists())

    def test_personal_claude_override(self):
        claude = self.root / "Claude's $custom config"
        self.env["CLAUDE_CONFIG_DIR"] = str(claude)
        self.init("personal", "claude")
        self.apply()
        self.instructions([claude / "CLAUDE.md"], "personal")
        self.skills(claude / "skills")
        self.assertFalse((claude / "skills/add/SKILL.md").exists())
        for p in ("qmd/SKILL.md", "journal/SKILL.md"):
            self.assertEqual((claude / "skills" / p).read_bytes(),
                             (REPO / "home/dot_claude/skills" / p).read_bytes())
        self.assertEqual((claude / "skills/_shared/instructions.md").resolve(),
                         self.home / ".agents/skills/_shared/instructions.md")
        for name in SKILLS:
            self.assertFalse((self.home / ".agents/skills" / name).exists())

    def test_native_overrides_outside_home(self):
        for key, folder in (("CLAUDE_CONFIG_DIR", "custom claude"), ("CODEX_HOME", "custom codex"),
                            ("XDG_CONFIG_HOME", "custom config")):
            self.env[key] = str(self.root / folder)
        self.init()
        amp_instructions = Path(self.env["XDG_CONFIG_HOME"]) / "amp/AGENTS.md"
        self.write(amp_instructions, "unmanaged Amp instructions")
        claude = Path(self.env["CLAUDE_CONFIG_DIR"])
        self.write(claude / "skills/beautiful-mermaid/scripts/render.ts", "old renderer")
        self.write(claude / "skills/beautiful-mermaid/scripts/local.ts", "local script")
        self.apply()
        paths = [claude / "CLAUDE.md", Path(self.env["CODEX_HOME"]) / "AGENTS.md"]
        self.instructions(paths, "work")
        self.assertEqual(amp_instructions.read_text(), "unmanaged Amp instructions")
        self.assertFalse((self.home / ".claude/CLAUDE.md").exists())
        self.assertFalse((self.home / ".codex/AGENTS.md").exists())
        self.assertFalse((self.home / ".config/amp/AGENTS.md").exists())
        self.skills(claude / "skills")
        self.skills(self.home / ".agents/skills")
        self.assertEqual((claude / "skills/_shared/instructions.md").resolve(),
                         self.home / ".agents/skills/_shared/instructions.md")
        settings = json.loads((claude / "settings.json").read_text())
        self.assertIn("custom\\ claude/statusline.sh", settings["statusLine"]["command"])
        self.apply()
        self.assertEqual(settings, json.loads((claude / "settings.json").read_text()))
        self.skills(claude / "skills")
        self.assertEqual((claude / "skills/beautiful-mermaid/scripts/local.ts").read_text(), "local script")

    def test_invalid_override_settings_are_not_replaced(self):
        claude = self.root / "custom claude"
        self.env["CLAUDE_CONFIG_DIR"] = str(claude)
        self.init()
        self.write(claude / "settings.json", "{broken")
        script = self.cm("execute-template", input=OVERRIDES.read_text()).stdout
        result = subprocess.run(["bash"], input=script, env=self.env, cwd=self.home,
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((claude / "settings.json").read_text(), "{broken")
        self.assertFalse((claude / "CLAUDE.md").exists())

    def test_invalid_settings_are_not_replaced(self):
        self.init()
        path = self.home / ".claude/settings.json"
        for invalid in ("{broken", "[]", "null", '{}\n{"second": "object"}'):
            self.write(path, invalid)
            result = self.cm("apply", "--exclude=scripts", "--force", str(path), check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(path.read_text(), invalid)


if __name__ == "__main__":
    unittest.main(verbosity=2)
