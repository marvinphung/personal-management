#!/usr/bin/env python3
"""Generate launcher sizes from the supplied logo (requires Pillow)."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
# Wallet only; leave the original wordmark artwork untouched.
logo = Image.open(ROOT / 'logo.png').convert('RGB').crop((275, 200, 995, 870))
canvas = Image.new('RGB', (800, 800), 'white')
canvas.paste(logo, ((800-logo.width)//2, (800-logo.height)//2))
res = ROOT / 'android/android/app/src/main/res'
for density, size in {'mdpi':48, 'hdpi':72, 'xhdpi':96, 'xxhdpi':144, 'xxxhdpi':192}.items():
    target = res / f'mipmap-{density}'
    target.mkdir(parents=True, exist_ok=True)
    canvas.resize((size,size), Image.Resampling.LANCZOS).save(target / 'ic_launcher.png')
canvas.resize((512,512), Image.Resampling.LANCZOS).save(ROOT / 'linux/packaging/finance-inbox.png')
