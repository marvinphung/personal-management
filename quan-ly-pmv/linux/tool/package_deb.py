#!/usr/bin/env python3
"""Package an already-built Linux release bundle for Ubuntu 24.04 amd64."""
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[2]
bundle = ROOT / 'linux/build/linux/x64/release/bundle'
if not (bundle / 'finance_linux').is_file():
    raise SystemExit('Build first: python3 linux/tool/flutter_client.py linux build linux')
output = ROOT / 'linux/build/installers'
output.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='finance-deb-') as tmp:
    stage = Path(tmp)
    shutil.copytree(bundle, stage / 'opt/finance-inbox')
    apps = stage / 'usr/share/applications'
    apps.mkdir(parents=True)
    shutil.copy2(ROOT / 'linux/packaging/app.personalfinance.finance_linux.desktop', apps)
    icons = stage / 'usr/share/icons/hicolor/512x512/apps'
    icons.mkdir(parents=True)
    shutil.copy2(ROOT / 'linux/packaging/finance-inbox.png', icons / 'app.personalfinance.finance_linux.png')
    control = stage / 'DEBIAN'
    control.mkdir()
    (control / 'control').write_text('''Package: finance-inbox
Version: 1.0.0-1
Section: office
Priority: optional
Architecture: amd64
Maintainer: Finance Inbox <marvinphung@users.noreply.github.com>
Depends: libc6 (>= 2.39), libgtk-3-0t64, libsecret-1-0, libstdc++6, libgcc-s1, libepoxy0, libglib2.0-0t64, libsqlite3-0
Recommends: gnome-keyring
Description: Personal finance with offline storage and Supabase synchronization
 Android bank inbox companion and personal finance desktop application.
''')
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage), str(output / 'finance-inbox_1.0.0-1_amd64.deb')], check=True)
