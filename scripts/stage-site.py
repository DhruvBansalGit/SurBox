#!/usr/bin/env python3
"""Prepare public downloads without credentials, caches or raw website sessions.
Run after building the native app. Hosting is static; it never runs the app.
"""
from pathlib import Path
import hashlib, shutil, subprocess, zipfile
root = Path(__file__).resolve().parent.parent
site = root / 'site'
downloads = site / 'downloads'
downloads.mkdir(parents=True, exist_ok=True)
app = root / 'artifacts/SurBox.app'
assert (app / 'Contents/MacOS/SurBox').exists(), 'Build the native app first'
subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
app_zip = root / 'artifacts/SurBox-macOS-arm64.zip'
subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(app_zip)], check=True)

# Documentation is served as inert text; the source archive retains Markdown.
for source, target in [('TESTING.md', 'verification.txt'), ('LID_TRACKING.md', 'lid-tracking.txt')]:
    shutil.copy2(root / source, site / target)

files = [root / name for name in ['Package.swift', 'README.md', 'TESTING.md', 'LID_TRACKING.md', '.gitignore', '.gitattributes']]
if (root / 'PUBLISHING.md').exists(): files.append(root / 'PUBLISHING.md')
for folder in ['Sources', 'Tests', 'scripts', 'Resources', 'AudioSource', 'SurBox.xcodeproj', 'site']:
    for path in (root / folder).rglob('*'):
        if not path.is_file(): continue
        if any(part in ['.vercel', 'downloads', 'node_modules', 'AppIcon.iconset', '.DS_Store', 'xcuserdata', '__pycache__'] for part in path.parts): continue
        if path.name in ['source-page.html', 'source-decoded.wav'] or path.name.startswith('.env'): continue
        files.append(path)
# Include compact evidence and the main interface images, not machine build logs.
for path in (root / 'artifacts/testing').rglob('*'):
    if path.is_file() and (path.name in ['native-results.txt', 'core-results.txt'] or (path.parent.name == 'native' and path.suffix == '.png')):
        files.append(path)
source_zip = root / 'artifacts/SurBox-source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(set(files)):
        archive.write(path, Path('SurBox') / path.relative_to(root))
with zipfile.ZipFile(source_zip) as archive:
    assert archive.testzip() is None
    assert not any('/.vercel/' in name or name.endswith('source-page.html') for name in archive.namelist())
for archive in [app_zip, source_zip]: shutil.copy2(archive, downloads / archive.name)
checksums = ''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n' for path in sorted(downloads.glob('*.zip')))
(downloads / 'SHA256SUMS.txt').write_text(checksums)
print(checksums, end='')
print('Prepared static site and verified source archive. No credentials or developer paths are required by the app.')
