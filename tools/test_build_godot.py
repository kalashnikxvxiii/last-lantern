"""Regression tests for the tester package's test gate."""
import subprocess
import unittest
from unittest.mock import patch

import build_godot


class BuildGodotTests(unittest.TestCase):
    def test_failed_tests_stop_before_export_or_cleanup(self):
        def fail_tests(cmd, **kwargs):
            # Native Windows cannot execute a .sh file without an interpreter.
            self.assertEqual(cmd[0], 'bash')
            self.assertEqual(cmd[1], 'tools/test.sh')
            self.assertEqual(kwargs['cwd'], build_godot.ROOT)
            self.assertTrue(kwargs['check'])
            raise subprocess.CalledProcessError(1, cmd)

        with patch.object(build_godot.subprocess, 'run', side_effect=fail_tests) as run:
            with patch.object(build_godot.shutil, 'rmtree') as cleanup:
                with self.assertRaises(subprocess.CalledProcessError):
                    build_godot.main()
                run.assert_called_once()
                cleanup.assert_not_called()


if __name__ == '__main__':
    unittest.main()
