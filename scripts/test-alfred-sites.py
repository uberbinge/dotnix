#!/usr/bin/env python3
"""Synthetic tests: no real home, app, account, or credentials accessed."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

SOURCE = Path(os.environ.get('ALFRED_SITES_SOURCE', str(Path(__file__).resolve().parents[1] / 'darwin/alfred-sites.py')))
spec = importlib.util.spec_from_file_location('alfred_sites', SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RefreshTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.target = self.home / '.config/alfred/sites.json'
        self.personal = self.home / 'personal.json'
        self.personal.write_text('[{"title":"public","arg":"https://example.org"}]')
        self.args = ['refresh', '--personal-file', str(self.personal), '--op', '/fake/op', '--account', 'fake']

    def run_mode(self, *mode, result=None, error=None):
        with patch.object(sys, 'argv', self.args + list(mode)), patch.dict(os.environ, HOME=str(self.home)), patch.object(module.subprocess, 'run', return_value=result, side_effect=error) as call:
            status = module.main()
            return status, call

    def seed(self):
        self.target.parent.mkdir(parents=True)
        self.target.write_text('[{"title":"keep"}]')
        return self.target.read_bytes()

    def test_initialize_never_calls_op_and_preserves_existing(self):
        status, call = self.run_mode('--initialize')
        self.assertEqual(status, 0)
        call.assert_not_called()
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o600)
        before = self.target.read_bytes()
        self.personal.write_text('[]')
        self.run_mode('--initialize')
        self.assertEqual(self.target.read_bytes(), before)

    def test_work_requires_opt_in(self):
        status, call = self.run_mode('--work')
        self.assertEqual(status, 1)
        call.assert_not_called()
        self.assertFalse(self.target.exists())

    def test_failure_preserves_existing(self):
        before = self.seed()
        for error in [subprocess.TimeoutExpired('/fake/op', 45), subprocess.CalledProcessError(1, '/fake/op')]:
            status, call = self.run_mode('--work', '--allow-work', error=error)
            self.assertEqual(status, 1)
            self.assertEqual(call.call_args.kwargs['timeout'], 45)
            self.assertEqual(self.target.read_bytes(), before)
        for payload in [b'broken', b'{}', b'{"fields":[]}', b'{"fields":[{"type":"STRING"}]}', b'{"fields":[{"type":"URL","label":"","value":"x"}]}', b'{"fields":[{"type":"URL","label":3}]}']:
            status, _ = self.run_mode('--work', '--allow-work', result=subprocess.CompletedProcess([], 0, payload))
            self.assertEqual(status, 1)
            self.assertEqual(self.target.read_bytes(), before)
        self.assertEqual(list(self.target.parent.glob('.sites-*')), [])

    def test_success_merges_and_personal_reset_is_explicit(self):
        self.seed()
        result = subprocess.CompletedProcess([], 0, b'{"fields":[{"type":"URL","label":"work","value":"https://example.test"}]}')
        status, _ = self.run_mode('--work', '--allow-work', result=result)
        self.assertEqual(status, 0)
        self.assertEqual(len(json.loads(self.target.read_text())), 2)
        self.assertEqual(self.target.stat().st_mode & 0o777, 0o600)
        self.run_mode('--personal')
        self.assertEqual(len(json.loads(self.target.read_text())), 1)

    def test_symlink_not_replaced(self):
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(self.personal)
        status, call = self.run_mode('--personal')
        self.assertEqual(status, 1)
        call.assert_not_called()
        self.assertTrue(self.target.is_symlink())


if __name__ == '__main__':
    unittest.main()
