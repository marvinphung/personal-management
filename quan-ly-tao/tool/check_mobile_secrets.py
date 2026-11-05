#!/usr/bin/env python3
"""Scan mobile app source code and artifacts for leaked secrets without printing values."""
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

SENSITIVE_PATTERNS = [
    re.compile(r'service_role', re.IGNORECASE),
    re.compile(r'supabase[_-]service[_-]key', re.IGNORECASE),
    re.compile(r'postgres://[^:]+:[^@]+@', re.IGNORECASE),
    re.compile(r'postgresql://[^:]+:[^@]+@', re.IGNORECASE),
    re.compile(r'BEGIN (?:RSA )?PRIVATE KEY'),
    re.compile(r'DEDUP_KEY\s*=\s*["\'][^"\']+["\']'),
]

SCAN_DIRS = [
    ROOT / 'apps/user_app/lib',
    ROOT / 'apps/user_app/android/app/src',
    ROOT / 'apps/user_app/ios',
    ROOT / 'apps/collector_app/lib',
    ROOT / 'apps/collector_app/android/app/src',
    ROOT / 'packages/api_client/lib',
    ROOT / 'packages/finance_core/lib',
]

EXCLUDED_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.jks', '.keystore', '.jar', '.class'}

violations = 0
for scan_dir in SCAN_DIRS:
    if not scan_dir.exists():
        continue
    for path in scan_dir.rglob('*'):
        if not path.is_file() or path.suffix in EXCLUDED_EXTENSIONS:
            continue
        try:
            content = path.read_text(encoding='utf-8', errors='ignore')
        except Exception:
            continue
        for pattern in SENSITIVE_PATTERNS:
            match = pattern.search(content)
            if match:
                print(f"SECRET LEAK DETECTED in {path.relative_to(ROOT)}: matches sensitive pattern (value redacted)")
                violations += 1

if violations > 0:
    print(f"\nFailed: Found {violations} potential secret pattern(s) in mobile code.")
    sys.exit(1)
else:
    print("Secret scan passed: No secrets detected in mobile source code.")
    sys.exit(0)
