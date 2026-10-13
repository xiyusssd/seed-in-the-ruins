"""Freeze, export and verify the compact roadside-stone patch in the background."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
ENGINE = ROOT / '.tools/Godot.app/Contents/MacOS/Godot'
VERSION = '1.13.1'
SNAPSHOT = ROOT / '.tools/compact-stele-release'
SUITES = ['maintenance_record', 'stele_clearance', 'later_visibility',
          'sun_console_access', 'fps', 'puzzle', 'menu', 'tutorial']
ENVIRONMENT = os.environ.copy()


def fingerprint(directory):
    result = {}
    for path in sorted(directory.rglob('*')):
        if not path.is_file() or '.godot' in path.parts or path.name == '.DS_Store':
            continue
        data = path.read_bytes()
        if path.suffix == '.import':
            data = data.decode().split('[params]', 1)[-1].encode()
        result[str(path.relative_to(directory))] = hashlib.sha256(data).hexdigest()
    return result


def run(args, label, expected=None):
    path = OUT / f'v1131-{label}.log'
    with path.open('w') as log:
        subprocess.run([str(arg) for arg in args], stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=300, env=ENVIRONMENT)
    content = path.read_text()
    assert 'ERROR:' not in content, path
    if expected is not None:
        assert expected in content, path
    print(label, 'OK', flush=True)


def main():
    suites = {}
    for suite in SUITES:
        log = (OUT / f'v1131-{suite}-tests.log').read_text()
        assert 'ERROR:' not in log and 'failures=[]' in log, suite
        suites[suite] = int(re.findall(r'(\d+) checks; failures=\[\]', log)[-1])
    assert not SNAPSHOT.exists(), 'Preserve previous snapshot'
    source = fingerprint(ROOT / 'game')
    shutil.copytree(ROOT / 'game', SNAPSHOT,
                    ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
    assert fingerprint(SNAPSHOT) == source
    (OUT / 'compact-stele-release-source.json').write_text(
        json.dumps({'version': VERSION, 'files': source}, indent=2) + '\n')
    temporary = ROOT / '.tools/compact-stele-export-temp'
    temporary.mkdir(exist_ok=True)
    ENVIRONMENT['TMPDIR'] = str(temporary) + '/'
    run([ENGINE, '--headless', '--editor', '--path', SNAPSHOT, '--import', '--quit'],
        'release-import')
    assert fingerprint(SNAPSHOT) == source
    archive = OUT / f'SeedInTheRuins-{VERSION}-macOS.zip'
    app = OUT / f'SeedInTheRuins-{VERSION}.app'
    assert not archive.exists() and not app.exists(), 'Preserve previous packages'
    run([ENGINE, '--headless', '--path', SNAPSHOT, '--export-release', 'macOS', archive],
        'release-export')
    stage = ROOT / '.tools/compact-stele-macos-extracted'
    assert not stage.exists()
    subprocess.run(['ditto', '-x', '-k', str(archive), str(stage)], check=True)
    packages = list(stage.glob('*.app'))
    assert len(packages) == 1
    shutil.move(str(packages[0]), app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == VERSION
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    binary.chmod(0o755)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    for suite, count in suites.items():
        run([binary, '--headless', f'res://tests/{suite}_flow.tscn'],
            f'exported-{suite}-tests', f'{count} checks; failures=[]')
    exported_rendering = {}
    for scene, folder, audit_file, expected in [
        ('maintenance_render_review', 'compact-stele-exported-native',
         'maintenance-render-audit.json', '13 frames; failures=[]'),
        ('stele_clearance_flow', 'compact-path-exported-native',
         'stele-clearance-audit.json', '18 checks; failures=[]')]:
        run([binary, '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy',
             '--disable-vsync', '--position', '-20000,-20000', f'res://tests/{scene}.tscn',
             '--', '--offscreen-capture', '--review-dir=' + str(OUT / folder)],
            f'exported-{scene}-render', expected)
        audit = json.loads((OUT / folder / audit_file).read_text())
        assert not audit['failures']
        exported_rendering[folder] = audit
    rendering = {}
    for folder, filename in [('compact-stele-native', 'maintenance-render-audit.json'),
                             ('compact-stele-compatible', 'maintenance-render-audit.json'),
                             ('compact-path-native', 'stele-clearance-audit.json'),
                             ('compact-path-compatible', 'stele-clearance-audit.json')]:
        audit_path = OUT / folder / filename
        audit = json.loads(audit_path.read_text())
        assert audit['version'] == VERSION and audit['failures'] == [], folder
        rendering[folder] = audit
    capture_source = json.loads((OUT / 'compact-stele-capture-source.json').read_text())['files']
    changed = [name for name in source if source[name] != capture_source.get(name)]
    assert changed == ['scripts/puzzle_world.gd'], changed
    previous = (ROOT / '.tools/compact-stele-candidate-before-target-fix/scripts/puzzle_world.gd').read_text()
    aligned = previous.replace('Vector3(1.25,1.55,.28)', 'Vector3(1.25,1.30,.28)').replace(
        'target.position=Vector3(0,1.02,.07)', 'target.position=Vector3(0,1.25,.07)')
    assert aligned == (ROOT / 'game/scripts/puzzle_world.gd').read_text()
    source_zip = OUT / f'SeedInTheRuins-{VERSION}-Source.zip'
    assert not source_zip.exists()
    with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for directory in ['game', 'tools', 'docs']:
            for path in sorted((ROOT / directory).rglob('*')):
                if path.is_file() and '.godot' not in path.parts and '__pycache__' not in path.parts and path.name != '.DS_Store':
                    zipped.write(path, str(path.relative_to(ROOT)))
        for name in ['README.md', '启动游戏.command']:
            zipped.write(ROOT / name, name)
    assert fingerprint(ROOT / 'game') == source and fingerprint(SNAPSHOT) == source
    report = {'version': VERSION, 'source_checks': suites, 'source_total': sum(suites.values()),
              'exported_checks': suites, 'exported_total': sum(suites.values()),
              'source_rendering': rendering, 'exported_rendering': exported_rendering,
              'compatibility_capture_source': 'compact-stele-capture-source.json',
              'compatibility_capture_note': 'Captured identical visible geometry before the invisible investigation box was centred on the inscription; final tutorial verified separately. Native exported captures use the final code.',
              'signature': 'codesign --verify --deep --strict passed',
              'background_only': True, 'source_manifest': 'compact-stele-release-source.json',
              'packages': {path.name: {'bytes': path.stat().st_size,
                           'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                           for path in [archive, source_zip]}, 'failures': []}
    (OUT / 'compact-stele-release-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('COMPACT_STELE_RELEASE_OK', sum(suites.values()), 'source and exported checks', flush=True)


if __name__ == '__main__':
    main()
