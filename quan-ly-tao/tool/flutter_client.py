#!/usr/bin/env python3
"""Pass ONLY public client configuration (e.g. API_BASE_URL) to Flutter; never load DB credentials."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('platform', choices=['user', 'collector'], help='Target app: user or collector')
parser.add_argument('flutter_args', nargs=argparse.REMAINDER)
args = parser.parse_args()

app_dirs = {
    'user': ROOT / 'apps/user_app',
    'collector': ROOT / 'apps/collector_app',
}
target_dir = app_dirs[args.platform]

allowed = {'API_BASE_URL'}
values = {key: os.environ.get(key, '') for key in allowed}

env_file = ROOT / '.env'
if env_file.exists():
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        key, separator, value = line.partition('=')
        key = key.strip()
        if separator and key in allowed and not values.get(key):
            values[key] = value.strip().strip('"').strip("'")

if not values.get('API_BASE_URL'):
    # Default local dev API endpoint
    values['API_BASE_URL'] = 'http://10.0.2.2:8000/v1'

flutter = shutil.which('flutter')
if not flutter:
    sys.exit('Flutter was not found on PATH. Install Flutter and add its bin directory to PATH.')

command = args.flutter_args or ['run']
# Pass public dart-defines
dart_defines = [f'--dart-define={key}={values[key]}' for key in sorted(allowed) if values.get(key)]

# Sanitize environment: never leak postgres/backend secret env vars
safe_env = {
    key: value for key, value in os.environ.items()
    if not (key.startswith('POSTGRES_') or key.startswith('SUPABASE_') or 'SECRET' in key or ('PASSWORD' in key and not key.startswith('ANDROID_')))
}

result = subprocess.run([flutter, *command, *dart_defines], cwd=target_dir, env=safe_env)
sys.exit(result.returncode)
