#!/usr/bin/env python3
"""Inventory application use cases/controllers and their measured line coverage.

Run `flutter test --coverage` first. This reports execution, not proof that every
business rule has an assertion; review scenarios alongside the numeric report.
"""
import argparse
import json
import re
from pathlib import Path


def read_coverage(path):
    result = {}
    current = None
    for line in path.read_text().splitlines():
        if line.startswith('SF:'):
            current = line[3:]
            if '/lib/' in current:
                current = 'lib/' + current.split('/lib/', 1)[1]
            result.setdefault(current, {})
        elif line.startswith('DA:') and current:
            number, count, *_ = line[3:].split(',')
            result[current][int(number)] = int(count)
    return result


def class_ranges(source):
    # Keep offsets while excluding braces in comments and string literals.
    literals = re.compile(
        r'//[^\n]*|/\*.*?\*/|r?""".*?"""|r?\x27\x27\x27.*?\x27\x27\x27'
        r'|r?\x27(?:\\.|[^\x27\\])*\x27|r?"(?:\\.|[^"\\])*"', re.DOTALL)
    clean = literals.sub(lambda m: ''.join('\n' if c == '\n' else ' ' for c in m.group()), source)
    declaration = re.compile(r'\b(?P<abstract>abstract\s+)?(?:interface\s+)?class\s+(?P<name>\w*(?:UseCase|Controller)\w*)\b')
    for match in declaration.finditer(clean):
        start = clean.find('{', match.end())
        if start < 0:
            continue
        depth, end = 1, start + 1
        while end < len(clean) and depth:
            depth += (clean[end] == '{') - (clean[end] == '}')
            end += 1
        yield dict(name=match['name'], abstract=bool(match['abstract']),
                   first_line=clean.count('\n', 0, match.start()) + 1,
                   last_line=clean.count('\n', 0, end) + 1)


def inventory(root, coverage):
    tests = sorted((root / 'test').rglob('*.dart'))
    imports = {}
    support_imports = {}
    for test in tests:
        for source in re.findall(r"(?:import|export)\s+'package:diabeatthis/([^']+)'", test.read_text()):
            destination = imports if test.name.endswith('_test.dart') else support_imports
            destination.setdefault('lib/' + source, []).append(str(test.relative_to(root)))
    rows = []
    for path in sorted((root / 'lib').rglob('*.dart')):
        if path.name.endswith(('.g.dart', '.freezed.dart')):
            continue
        source = path.read_text()
        declarations = list(class_ranges(source))
        names = [item['name'] for item in declarations]
        relative = str(path.relative_to(root))
        function_use_case = not names and (
            '/use_cases/' in relative or path.name.endswith('_use_case.dart'))
        if not names and not function_use_case:
            continue
        lines = coverage.get(relative, {})
        covered = sum(count > 0 for count in lines.values())
        for declaration in declarations:
            class_lines = {n: c for n, c in lines.items()
                           if declaration['first_line'] <= n <= declaration['last_line']}
            declaration['executable_lines'] = len(class_lines)
            declaration['covered_lines'] = sum(c > 0 for c in class_lines.values())
        rows.append(dict(path=relative, classes=names, class_coverage=declarations,
                         function_use_case=function_use_case,
                         executable_lines=len(lines), covered_lines=covered,
                         coverage_percent=round(100 * covered / len(lines), 1) if lines else None,
                         uncovered_lines=[number for number, count in lines.items() if count == 0],
                         abstract_only=all(re.search(r'abstract\s+(?:interface\s+)?class\s+' + name + r'\b', source) for name in names),
                         directly_importing_tests=imports.get(relative, []),
                         directly_importing_test_support=support_imports.get(relative, [])))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lcov', type=Path, default=Path('coverage/lcov.info'))
    parser.add_argument('--additional-lcov', type=Path, action='append', default=[],
                        help='Merge execution from an additional test suite or shard')
    parser.add_argument('--require-executed', action='store_true', help='Fail if any concrete behavior file has no executed lines')
    parser.add_argument('--output', type=Path, default=Path('coverage/behavior_inventory.json'))
    args = parser.parse_args()
    root = Path.cwd()
    coverage = read_coverage(args.lcov)
    for extra in args.additional_lcov:
        for source, lines in read_coverage(extra).items():
            merged = coverage.setdefault(source, {})
            for number, count in lines.items():
                merged[number] = merged.get(number, 0) + count
    rows = inventory(root, coverage)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(rows, indent=2) + '\n')
    print(f'{len(rows)} source files; {sum(len(row["classes"]) for row in rows)} use cases/controllers')
    for row in sorted(rows, key=lambda r: (r['coverage_percent'] or 0, r['path'])):
        if row['coverage_percent'] is None or row['coverage_percent'] < 80:
            print(f'{str(row["coverage_percent"]):>5}% {row["path"]}')
    missing = [row['path'] + ':' + item['name'] for row in rows
               for item in row['class_coverage']
               if not item['abstract'] and item['covered_lines'] == 0]
    missing.extend(row['path'] for row in rows
                   if row['function_use_case'] and row['covered_lines'] == 0)
    if args.require_executed and missing:
        parser.exit(1, 'Concrete behavior has no execution coverage: ' + ', '.join(missing) + '\n')


if __name__ == '__main__':
    main()
