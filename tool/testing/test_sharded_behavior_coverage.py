import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class ShardedBehaviorCoverageTest(unittest.TestCase):
    def test_combined_shards_cover_behavior_that_each_shard_alone_cannot(self):
        script = Path(__file__).with_name('audit_behavior_coverage.py').resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'lib').mkdir()
            (root / 'test').mkdir()
            for name in ['First', 'Second']:
                (root / 'lib' / f'{name.lower()}_use_case.dart').write_text(
                    f'class {name}UseCase {{\n  void call() {{}}\n}}\n')

            reports = []
            for index in range(2):
                report = root / f'shard-{index}.info'
                report.write_text(''.join(
                    f'SF:lib/{name}_use_case.dart\n'
                    f'DA:2,{int(index == owner)}\nend_of_record\n'
                    for owner, name in enumerate(['first', 'second'])))
                reports.append(report)
                result = subprocess.run(
                    [sys.executable, str(script), '--lcov', str(report),
                     '--require-executed'], cwd=root,
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn('Concrete behavior has no execution coverage', result.stderr)

            combined = subprocess.run(
                [sys.executable, str(script), '--lcov', str(reports[0]),
                 '--additional-lcov', str(reports[1]), '--require-executed'],
                cwd=root, capture_output=True, text=True)
            self.assertEqual(combined.returncode, 0, combined.stdout + combined.stderr)


if __name__ == '__main__':
    unittest.main()
