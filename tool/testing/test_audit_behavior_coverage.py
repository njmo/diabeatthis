import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from audit_behavior_coverage import class_ranges, inventory, read_coverage


class BehaviorCoverageAuditTest(unittest.TestCase):
    def test_comments_and_json_strings_do_not_invent_or_close_classes(self):
        source = '''
// class ImaginaryController {}
abstract interface class PortController {}
class ActualUseCase {
  final payload = '{ "class FakeController {}": "}" }';
  void call() {}
}
'''
        declarations = list(class_ranges(source))
        self.assertEqual([item['name'] for item in declarations],
                         ['PortController', 'ActualUseCase'])
        self.assertTrue(declarations[0]['abstract'])
        self.assertFalse(declarations[1]['abstract'])
        self.assertEqual(declarations[1]['last_line'], 7)

    def test_coverage_keeps_unexecuted_lines_and_normalizes_absolute_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'lcov.info'
            path.write_text('SF:/checkout/lib/example.dart\nDA:2,3\nDA:3,0\nend_of_record\n')
            self.assertEqual(read_coverage(path), {'lib/example.dart': {2: 3, 3: 0}})

    def test_provider_execution_cannot_hide_two_unexecuted_classes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'test').mkdir()
            path = root / 'lib' / 'example.dart'
            path.write_text('final provider = 1;\nclass FirstController {\n void call() {}\n}\n'
                            'class SecondUseCase {\n void call() {}\n}\n')
            (root / 'test' / 'example_test.dart').write_text(
                "import 'package:diabeatthis/example.dart';\n")
            rows = inventory(root, {'lib/example.dart': {1: 10, 3: 0, 6: 0}})
            self.assertEqual(rows[0]['covered_lines'], 1)
            self.assertEqual([item['covered_lines'] for item in rows[0]['class_coverage']], [0, 0])
            self.assertEqual(rows[0]['directly_importing_tests'], ['test/example_test.dart'])

    def test_function_use_cases_are_included_and_generated_files_are_excluded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib' / 'use_cases').mkdir(parents=True)
            (root / 'test').mkdir()
            (root / 'lib' / 'use_cases' / 'read_use_case.dart').write_text('void read() {}\n')
            (root / 'lib' / 'generated.g.dart').write_text('class GeneratedController {}')
            rows = inventory(root, {})
            self.assertEqual(len(rows), 1)
            self.assertTrue(rows[0]['function_use_case'])
            self.assertEqual(rows[0]['covered_lines'], 0)

    def test_gate_rejects_an_unexecuted_new_use_case_and_accepts_executed_behavior(self):
        script = Path(__file__).with_name('audit_behavior_coverage.py').resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'test').mkdir()
            (root / 'lib' / 'new_use_case.dart').write_text('class NewUseCase {\n void call() {}\n}\n')
            coverage = root / 'lcov.info'
            for count, expected_exit in [(0, 1), (1, 0)]:
                coverage.write_text(f'SF:lib/new_use_case.dart\nDA:2,{count}\nend_of_record\n')
                result = subprocess.run([sys.executable, str(script), '--lcov', str(coverage),
                                         '--require-executed'], cwd=root,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, expected_exit, result.stdout + result.stderr)
                if expected_exit:
                    self.assertIn('NewUseCase', result.stderr)


if __name__ == '__main__':
    unittest.main()
