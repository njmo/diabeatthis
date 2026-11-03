import tempfile
import unittest
from pathlib import Path

from audit_behavior_coverage import inventory


class BehaviorAuditTestProvenanceTest(unittest.TestCase):
    def test_importing_a_controller_in_a_fake_is_not_reported_as_a_direct_test(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'test' / 'helpers').mkdir(parents=True)
            (root / 'lib' / 'example.dart').write_text('class ExampleController {}\n')
            (root / 'test' / 'helpers' / 'fake_controller.dart').write_text(
                "import 'package:diabeatthis/example.dart';\n")
            row, = inventory(root, {})
            self.assertEqual(row['directly_importing_tests'], [])
            self.assertEqual(row['directly_importing_test_support'],
                             ['test/helpers/fake_controller.dart'])
            self.assertEqual(row['covered_lines'], 0)

    def test_actual_test_and_support_imports_remain_separate_and_sorted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'test' / 'helpers').mkdir(parents=True)
            (root / 'lib' / 'example.dart').write_text('class ExampleUseCase {}\n')
            for name in ['z_test.dart', 'a_test.dart', 'helpers/fake.dart']:
                (root / 'test' / name).write_text(
                    "import 'package:diabeatthis/example.dart';\n")
            row, = inventory(root, {})
            self.assertEqual(row['directly_importing_tests'],
                             ['test/a_test.dart', 'test/z_test.dart'])
            self.assertEqual(row['directly_importing_test_support'],
                             ['test/helpers/fake.dart'])


if __name__ == '__main__':
    unittest.main()
