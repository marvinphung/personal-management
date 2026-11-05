#!/usr/bin/env python3
"""Pass ONLY public client configuration to Flutter; never load DB credentials."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('platform', choices=['android', 'linux'])
parser.add_argument('flutter_args', nargs=argparse.REMAINDER)
args = parser.parse_args()
allowed = {'SUPABASE_URL', 'SUPABASE_ANON_KEY'}
values = {key: os.environ.get(key, '') for key in allowed}
file = ROOT / '.env'
if file.exists():
    for line in file.read_text().splitlines():
        key, separator, value = line.partition('=')
        if separator and key.strip() in allowed and not values[key.strip()]:
            values[key.strip()] = value.strip().strip('"').strip("'")
if any(not values[key] for key in allowed):
    sys.exit('Missing SUPABASE_URL or SUPABASE_ANON_KEY. Add the project URL and public key from Supabase Dashboard to .env. Database credentials cannot be substituted.')
flutter = shutil.which('flutter')
if not flutter:
    sys.exit('Flutter was not found on PATH. Install Flutter and add its bin directory to PATH.')
command = args.flutter_args or ['run']
if command[0] not in {'run', 'build'}:
    sys.exit('This wrapper supports flutter run and flutter build only. Run tests/analyze directly.')
env = {key: value for key, value in os.environ.items() if not key.startswith('SUPABASE_')}
result = subprocess.run([flutter, *command, *[f'--dart-define={key}={values[key]}' for key in sorted(allowed)]], cwd=ROOT / args.platform, env=env)
sys.exit(result.returncode)
