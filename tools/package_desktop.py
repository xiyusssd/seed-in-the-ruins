"""Create the Mac drag-to-Applications installer from the exported ZIP."""
import plistlib
import shutil
import stat
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
STAGE = ROOT / '.tools' / 'desktop-installer'
EXTRACT = ROOT / '.tools' / 'desktop-extracted'

def run(*args):
    subprocess.run(args, check=True)

for directory in (STAGE, EXTRACT):
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)
run('ditto', '-x', '-k', str(OUT / 'SeedInTheRuins-macOS.zip'), str(EXTRACT))
apps = list(EXTRACT.glob('*.app'))
if len(apps) != 1:
    raise RuntimeError('Expected one exported app')
info = plistlib.loads((apps[0] / 'Contents/Info.plist').read_bytes())
# Each release has its own checkout app, so a running older preview stays intact.
app = OUT / ('SeedInTheRuins-' + info['CFBundleShortVersionString'] + '.app')
if app.exists():
    shutil.rmtree(app)
shutil.move(str(apps[0]), app)
executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
# Preserve the launch permission even when reusing an older ZIP made by ditto.
executable.chmod(executable.stat().st_mode | 0o111)
run('codesign', '--verify', '--deep', '--strict', str(app))
with (OUT / 'software-mac-runtime.log').open('w') as log:
    subprocess.run([str(app / 'Contents/MacOS' / info['CFBundleExecutable']), '--headless', '--', '--verify-build'],
                   stdout=log, stderr=subprocess.STDOUT, timeout=30, check=True)
if 'SPATIAL_BUILD_OK' not in (OUT / 'software-mac-runtime.log').read_text():
    raise RuntimeError('Native app scene verification failed')
with zipfile.ZipFile(OUT / 'SeedInTheRuins-macOS.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    # One writer keeps UTF-8 filenames and Unix modes intact. Appending with a
    # second ZIP implementation can reinterpret ditto's unflagged UTF-8 names.
    for path in sorted(app.rglob('*')):
        name = str(path.relative_to(OUT))
        if path.is_symlink():
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(entry, str(path.readlink()))
        else:
            archive.write(path, name)
    archive.write(ROOT / 'docs/安装与操作.md', '安装与操作.md')
    for name in ['GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt', 'ASSET_LICENSES.md']:
        archive.write(ROOT / 'docs' / name, 'licenses/' + name)
    archive.write(ROOT / 'game/assets/OFL.txt', 'licenses/OFL.txt')
    archive.write(ROOT / 'game/assets/OFL-NotoSerifSC.txt', 'licenses/OFL-NotoSerifSC.txt')
    archive.write(ROOT / 'game/assets/OFL-ZCOOL.txt', 'licenses/OFL-ZCOOL.txt')
    archive.write(ROOT / 'game/assets/OFL-ShareTechMono.txt', 'licenses/OFL-ShareTechMono.txt')
run('ditto', str(app), str(STAGE / '废墟里的种子.app'))
(STAGE / 'Applications').symlink_to('/Applications')
shutil.copyfile(ROOT / 'docs/安装与操作.md', STAGE / '安装与操作.txt')
licenses = STAGE / 'licenses'
licenses.mkdir()
for name in ['GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt', 'ASSET_LICENSES.md']:
    shutil.copyfile(ROOT / 'docs' / name, licenses / name)
shutil.copyfile(ROOT / 'game/assets/OFL.txt', licenses / 'OFL.txt')
shutil.copyfile(ROOT / 'game/assets/OFL-NotoSerifSC.txt', licenses / 'OFL-NotoSerifSC.txt')
shutil.copyfile(ROOT / 'game/assets/OFL-ZCOOL.txt', licenses / 'OFL-ZCOOL.txt')
shutil.copyfile(ROOT / 'game/assets/OFL-ShareTechMono.txt', licenses / 'OFL-ShareTechMono.txt')
# Leave room for the filesystem and atomic temporary copies during creation.
payload_bytes=sum(path.stat().st_size for path in STAGE.rglob('*') if path.is_file() and not path.is_symlink())
image_megabytes=max(512,2*((payload_bytes+1024**2-1)//1024**2))
run('hdiutil', 'create', '-volname', '废墟里的种子', '-srcfolder', str(STAGE),
    '-fs', 'HFS+', '-size', str(image_megabytes)+'m',
    '-ov', '-format', 'UDZO', str(OUT / 'SeedInTheRuins-macOS.dmg'))
run('hdiutil', 'verify', str(OUT / 'SeedInTheRuins-macOS.dmg'))
print('DESKTOP_INSTALLER_OK')
