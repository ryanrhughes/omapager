import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('omapager_action', str(ROOT / 'bin/omapager-action'))
spec = importlib.util.spec_from_loader(loader.name, loader)
actions = importlib.util.module_from_spec(spec)
loader.exec_module(actions)


class NotificationActions(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_local_file_preserves_spaces_unicode_and_uri_metacharacters(self):
        file = self.root / 'received résumé #1%?.txt'
        file.write_text('received content')
        self.assertEqual(actions.action_command(['xdg-open', str(file)]),
                         ['/usr/bin/xdg-open', file.as_uri()])

    def test_rejects_urls_options_relative_paths_and_traversal(self):
        for value in ['https://example.com/', 'http://127.0.0.1/', 'file:///etc/passwd',
                      'custom-handler:payload', '--help', 'relative.txt', '//server/share',
                      '/tmp/../etc/passwd', '/tmp/./file', '/tmp/file\x00', '/tmp/file\n',
                      '/tmp/a\\b', '/tmp/' + 'a' * 4096]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                actions.action_command(['xdg-open', value])

    def test_rechecks_file_type_and_existence_at_activation(self):
        file = self.root / 'received.txt'
        file.write_text('ordinary file')
        actions.action_command(['xdg-open', str(file)])
        file.unlink()
        with self.assertRaises(FileNotFoundError):
            actions.action_command(['xdg-open', str(file)])
        os.mkfifo(file)
        with self.assertRaises(ValueError):
            actions.action_command(['xdg-open', str(file)])
        file.unlink()
        file.mkdir()
        with self.assertRaises(ValueError):
            actions.action_command(['xdg-open', str(file)])

    def test_rejects_symlinks_executables_and_desktop_launchers(self):
        file = self.root / 'received.txt'
        file.write_text('data')
        link = self.root / 'link.txt'
        link.symlink_to(file)
        with self.assertRaises(ValueError):
            actions.action_command(['xdg-open', str(link)])
        file.chmod(0o700)
        with self.assertRaises(ValueError):
            actions.action_command(['xdg-open', str(file)])
        launcher = self.root / 'received.DESKTOP'
        launcher.write_text('[Desktop Entry]\nExec=anything\n')
        with self.assertRaises(ValueError):
            actions.action_command(['xdg-open', str(launcher)])

    def test_crash_uses_configured_installation_and_only_numeric_pid(self):
        with patch.dict(os.environ, OMARCHY_PATH='/omarchy'):
            self.assertEqual(actions.action_command(['omarchy-agent-crash', '12345']),
                             ['/omarchy/bin/omarchy-agent-crash', '12345'])
            for pid in ['0', '-1', '01', '2147483648', '123\n', '--help', 'x' * 10000]:
                with self.subTest(pid=pid), self.assertRaises(ValueError):
                    actions.action_command(['omarchy-agent-crash', pid])
        with patch.dict(os.environ, OMARCHY_PATH='relative'):
            with self.assertRaises(ValueError):
                actions.action_command(['omarchy-agent-crash', '12345'])

    def test_broker_rejects_unknown_programs_and_extra_arguments(self):
        for argv in [[], ['sh', '-c'], ['/tmp/xdg-open', '/tmp/a'],
                     ['xdg-open', '/tmp/a', '/tmp/b'],
                     ['omarchy-agent-crash', '12345', 'sender prompt'],
                     ['omarchy-agent-crash', 12345]]:
            with self.subTest(argv=argv), self.assertRaises(ValueError):
                actions.action_command(argv)


if __name__ == '__main__':
    unittest.main()
