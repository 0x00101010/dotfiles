import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[2] / "home/dot_local/bin/executable_work-planner"
CLOCK = """
import datetime, os, runpy, subprocess, sys
Real = datetime.datetime
class Clock(Real):
    @classmethod
    def now(cls, tz=None):
        return Real.fromisoformat(os.environ['TEST_NOW']).astimezone(tz)
datetime.datetime = Clock
run = subprocess.run
def bounded_run(*args, **kwargs):
    if 'timeout' in kwargs and 'TEST_TIMEOUT' in os.environ:
        kwargs['timeout'] = float(os.environ['TEST_TIMEOUT'])
    return run(*args, **kwargs)
subprocess.run = bounded_run
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name='__main__')
"""
AGENT = """#!/usr/bin/env python3
import os, re, sys, time
from pathlib import Path
prompt = sys.stdin.read()
root = Path.home()
(root / 'prompt').write_text(prompt)
day = re.search(r'^Local date: (.+)$', prompt, re.M)[1]
with (root / 'deliveries').open('a') as f:
    f.write(day + '\\n')
scenario = os.environ.get('SCENARIO', 'success')
if scenario == 'slow':
    time.sleep(1)
if scenario == 'timeout':
    print('Uncertain issue: https://linear.app/demo/issue/D-1', flush=True)
    time.sleep(10)
if scenario == 'fail':
    print('Write outcome uncertain')
    sys.exit(1)
if scenario == 'no-receipt':
    print('All done!')
elif scenario == 'wrong-date':
    print('WORK_PLANNER_OK 2026-10-01 https://linear.app/demo/issue/D-1 https://linear.app/demo/issue/W-1')
else:
    print(f'WORK_PLANNER_OK {day} https://linear.app/demo/issue/D-1 https://linear.app/demo/issue/W-1')
"""


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / ".config/dotfiles/work-planner"
        self.config.parent.mkdir(parents=True)
        self.config.write_text("enabled yes\ntimezone America/Los_Angeles\nat 08:00\n\n"
                               "# Synthetic planner\nat most three deep-work tasks\n")
        self.state = self.home / ".local/state/work-planner"
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        for name, source in [("amp", AGENT), ("launchctl", "#!/bin/sh\nexit 0\n")]:
            executable = bin_dir / name
            executable.write_text(source)
            executable.chmod(0o700)
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{bin_dir}:{Path(sys.executable).parent}:{os.defpath}",
            "TEST_NOW": "2026-10-12T15:00:00+00:00",
        }

    def run_planner(self, *args, **env):
        return subprocess.run(
            [sys.executable, "-c", CLOCK, str(RUNNER), *args],
            env=self.env | env, capture_output=True, text=True, timeout=10,
        )

    def test_schedule_boundary_catchup_and_repeat(self):
        result = self.run_planner(TEST_NOW="2026-10-12T14:59:00+00:00")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "deliveries").exists())
        for instant in ["2026-10-12T15:00:00+00:00", "2026-10-12T20:00:00+00:00",
                        "2026-10-14T19:00:00+00:00"]:
            result = self.run_planner(TEST_NOW=instant)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.home / "deliveries").read_text().splitlines(), ["2026-10-12", "2026-10-14"])
        prompt = (self.home / "prompt").read_text()
        self.assertIn("Week Monday: 2026-10-12", prompt)
        self.assertIn("Cutoff: 2026-10-12T08:00:00-07:00", prompt)
        self.assertEqual((self.state / "2026-10-14.receipt").stat().st_mode & 0o777, 0o600)

    def test_pause_preview_and_invalid_config_never_invoke_agent(self):
        self.config.write_text(self.config.read_text().replace("enabled yes", "enabled no"))
        self.assertEqual(self.run_planner("--run-now").returncode, 0)
        result = self.run_planner("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("# Synthetic planner", result.stdout)
        self.config.write_text(self.config.read_text().replace("at 08:00", "at 08:00\nat 09:00"))
        self.assertNotEqual(self.run_planner().returncode, 0)
        self.assertFalse((self.home / "deliveries").exists())

    def test_uncertain_write_blocks_later_runs_until_explicit_reconciliation(self):
        self.assertNotEqual(self.run_planner(SCENARIO="fail").returncode, 0)
        self.assertTrue((self.state / "pending").exists())
        self.assertFalse(list(self.state.glob("*.receipt")))
        result = self.run_planner(TEST_NOW="2026-10-13T16:00:00+00:00")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.home / "deliveries").read_text().splitlines(), ["2026-10-12"])
        result = self.run_planner("--retry", TEST_NOW="2026-10-13T16:00:00+00:00", SCENARIO="fail")
        self.assertNotEqual(result.returncode, 0)
        result = self.run_planner("--retry", TEST_NOW="2026-10-14T16:00:00+00:00")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Date: 2026-10-12", (self.home / "prompt").read_text())
        self.assertIn("Date: 2026-10-13", (self.home / "prompt").read_text())
        self.assertFalse((self.state / "pending").exists())

    def test_timeout_preserves_output_for_reconciliation(self):
        result = self.run_planner(SCENARIO="timeout", TEST_TIMEOUT="0.5")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("https://linear.app/demo/issue/D-1", (self.state / "2026-10-12.log").read_text())
        self.assertTrue((self.state / "pending").exists())
        self.assertFalse(list(self.state.glob("*.receipt")))

    def test_exit_zero_without_matching_receipt_is_not_success(self):
        for scenario in ["no-receipt", "wrong-date"]:
            result = self.run_planner("--retry", SCENARIO=scenario)
            self.assertNotEqual(result.returncode, 0, scenario)
            self.assertFalse(list(self.state.glob("*.receipt")))

    def test_overlapping_invocations_deliver_once(self):
        first = subprocess.Popen(
            [sys.executable, "-c", CLOCK, str(RUNNER)], env=self.env | {"SCENARIO": "slow"},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            second = self.run_planner(SCENARIO="slow")
            stdout, stderr = first.communicate(timeout=10)
            self.assertEqual(first.returncode, 0, stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual((self.home / "deliveries").read_text().splitlines(), ["2026-10-12"])
        finally:
            if first.poll() is None:
                first.kill()
                first.wait()

    def test_dst_uses_local_clock(self):
        self.assertEqual(self.run_planner(TEST_NOW="2026-11-01T15:59:00+00:00").returncode, 0)
        self.assertFalse((self.home / "deliveries").exists())
        result = self.run_planner(TEST_NOW="2026-11-01T16:00:00+00:00")
        self.assertEqual(result.returncode, 0, result.stderr)
        prompt = (self.home / "prompt").read_text()
        self.assertIn("Cutoff: 2026-11-01T08:00:00-08:00", prompt)
        self.assertIn("Week Monday: 2026-10-26", prompt)

    @unittest.skipUnless(sys.platform == "darwin", "macOS installer")
    def test_install_preserves_existing_launchagent(self):
        result = self.run_planner("--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        plist, = (self.home / "Library/LaunchAgents").glob("*.plist")
        with plist.open("rb") as f:
            spec = plistlib.load(f)
        self.assertTrue(spec["RunAtLoad"])
        self.assertEqual(spec["StartCalendarInterval"], {"Minute": 0})
        self.assertEqual(spec["StartInterval"], 900)
        before = plist.read_bytes()
        self.assertNotEqual(self.run_planner("--install").returncode, 0)
        self.assertEqual(plist.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
