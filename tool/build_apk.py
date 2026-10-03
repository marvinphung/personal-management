#!/usr/bin/env python3
"""Build a release APK with a persistent, local-only personal signing key."""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('target', choices=['user', 'collector'], default='user', nargs='?', help='Target app')
args = parser.parse_args()

target_name = 'user' if args.target == 'user' else 'collector'
app_dir = ROOT / ('apps/user_app' if target_name == 'user' else 'apps/collector_app')

signing = ROOT / 'apps/user_app/signing'
signing.mkdir(mode=0o700, exist_ok=True)
credentials = signing / 'credentials.json'
keystore = signing / 'release.jks'

if not credentials.exists():
    if keystore.exists():
        raise SystemExit('Existing key has no credentials; restore credentials.json from backup.')
    with open(credentials, 'x', opener=lambda path, flags: os.open(path, flags, 0o600)) as file:
        json.dump({'password': secrets.token_urlsafe(32)}, file)

creds_data = json.loads(credentials.read_text())
password = creds_data['password']
alias = creds_data.get('alias', 'finance-inbox')
env = dict(
    os.environ,
    ANDROID_KEYSTORE_PATH=str(keystore),
    ANDROID_KEYSTORE_PASSWORD=password,
    ANDROID_KEY_ALIAS=alias,
    ANDROID_KEY_PASSWORD=password,
)

if not keystore.exists():
    keytool = shutil.which('keytool')
    if not keytool:
        raise SystemExit('Add JDK bin to PATH before building.')
    subprocess.run(
        [
            keytool, '-genkeypair', '-keystore', str(keystore), '-storetype', 'JKS',
            '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD', '-keypass:env', 'ANDROID_KEY_PASSWORD',
            '-alias', 'quanlytao', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
            '-dname', 'CN=Quan Ly Tao', '-noprompt',
        ],
        env=env,
        check=True,
        capture_output=True,
    )
    keystore.chmod(0o600)

subprocess.run(
    [sys.executable, str(ROOT / 'tool/flutter_client.py'), target_name, 'build', 'apk', '--release'],
    env=env,
    check=True,
)

output = app_dir / 'build/installers'
output.mkdir(parents=True, exist_ok=True)
apk_source = app_dir / 'build/app/outputs/flutter-apk/app-release.apk'
if apk_source.exists():
    apk_dest = output / f'{target_name}-release-1.0.0.apk'
    shutil.copy2(apk_source, apk_dest)
    print(f'APK: {apk_dest}')

print('Back up apps/user_app/signing privately; the same key is required for future updates.')
