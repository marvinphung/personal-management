#!/usr/bin/env python3
"""Build PMV with the existing private signing identity. Never generate a replacement key."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
credentials = ROOT / 'android/signing/credentials.json'
keystore = ROOT / 'android/signing/release.jks'
env = dict(os.environ)
if not all(env.get(k) for k in ['ANDROID_KEYSTORE_PATH','ANDROID_KEYSTORE_PASSWORD','ANDROID_KEY_ALIAS','ANDROID_KEY_PASSWORD']):
    if not credentials.exists() or not keystore.exists():
        sys.exit('Restore the existing android/signing key and credentials, or set all four ANDROID_KEYSTORE_* / ANDROID_KEY_* signing variables. A new key cannot update the installed app.')
    private = json.loads(credentials.read_text())
    env.update(ANDROID_KEYSTORE_PATH=str(keystore), ANDROID_KEYSTORE_PASSWORD=private['password'],
               ANDROID_KEY_PASSWORD=private['password'], ANDROID_KEY_ALIAS=private.get('alias','finance-inbox'))
subprocess.run([sys.executable,str(ROOT/'linux/tool/flutter_client.py'),'android','build','apk','--release','--target-platform','android-arm64'],env=env,check=True)
version = next(line.split(':',1)[1].strip().split('+')[0] for line in (ROOT/'android/pubspec.yaml').read_text().splitlines() if line.startswith('version:'))
out = ROOT/'android/build/installers'/f'quan-ly-pmv-{version}.apk'
out.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'android/build/app/outputs/flutter-apk/app-release.apk',out)
print(f'APK: {out.relative_to(ROOT)}')
