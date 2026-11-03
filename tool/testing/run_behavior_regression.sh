#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 -m unittest discover -s tool/testing -p 'test_*.py'
flutter test --no-pub --coverage "$@"
python3 tool/testing/audit_behavior_coverage.py --require-executed
