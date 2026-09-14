#!/usr/bin/env python3
"""Build a release APK with a persistent, local-only personal signing key."""
from pathlib import Path
import json
import os
import secrets
import shutil
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
signing = ROOT / 'android/signing'
signing.mkdir(mode=0o700, exist_ok=True)
credentials = signing / 'credentials.json'
keystore = signing / 'release.jks'
if not credentials.exists():
    if keystore.exists():
        raise SystemExit('Existing key has no credentials; restore credentials.json from backup.')
    with open(credentials, 'x', opener=lambda path, flags: os.open(path, flags, 0o600)) as file:
        json.dump({'password': secrets.token_urlsafe(32)}, file)
password = json.loads(credentials.read_text())['password']
env = dict(os.environ, ANDROID_KEYSTORE_PATH=str(keystore), ANDROID_KEYSTORE_PASSWORD=password,
           ANDROID_KEY_ALIAS='finance-inbox', ANDROID_KEY_PASSWORD=password)
if not keystore.exists():
    keytool = shutil.which('keytool')
    if not keytool:
        raise SystemExit('Add JDK bin to PATH before building.')
    subprocess.run([keytool, '-genkeypair', '-keystore', str(keystore), '-storetype', 'JKS',
        '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD', '-keypass:env', 'ANDROID_KEY_PASSWORD',
        '-alias', 'finance-inbox', '-keyalg', 'RSA', '-keysize', '3072', '-validity', '10000',
        '-dname', 'CN=Finance Inbox', '-noprompt'], env=env, check=True, capture_output=True)
    keystore.chmod(0o600)
subprocess.run([sys.executable, str(ROOT / 'linux/tool/flutter_client.py'), 'android',
                'build', 'apk', '--release'], env=env, check=True)
output = ROOT / 'android/build/installers'
output.mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / 'android/build/app/outputs/flutter-apk/app-release.apk', output / 'finance-inbox-1.0.0.apk')
print('APK: android/build/installers/finance-inbox-1.0.0.apk')
print('Back up android/signing privately; the same key is required for future updates.')
