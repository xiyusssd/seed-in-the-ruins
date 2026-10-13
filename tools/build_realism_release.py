"""Export and verify the 1.13.0 macOS application from an isolated source copy."""
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
VERSION = '1.13.0'
SNAPSHOT = ROOT / '.tools/realism-release'
ENVIRONMENT = os.environ.copy()


def fingerprint(directory):
    files = {}
    for path in sorted(directory.rglob('*')):
        if not path.is_file() or '.godot' in path.parts or path.name == '.DS_Store':
            continue
        data = path.read_bytes()
        # Import remap/dependency paths are generated; keep the authored settings.
        if path.suffix == '.import':
            data = data.decode().split('[params]', 1)[-1].encode()
        files[str(path.relative_to(directory))] = hashlib.sha256(data).hexdigest()
    return files


def run(args, name, expected=None, timeout=300):
    log_path = OUT / name
    with log_path.open('w') as log:
        subprocess.run([str(arg) for arg in args], stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=timeout, env=ENVIRONMENT)
    content = log_path.read_text()
    assert 'ERROR:' not in content, log_path
    if expected is not None:
        assert expected in content, log_path


def main():
    summary = json.loads((OUT / 'v1130-test-summary.json').read_text())
    audio = json.loads((OUT / 'realism-audio/realism-audio-audit.json').read_text())
    assert not summary['failures'] and summary['version'] == VERSION
    assert audio['checks'] == 30 and not audio['failures']
    for suite, count in summary['suites'].items():
        log = (OUT / f'v1130-{suite}-tests.log').read_text()
        assert 'ERROR:' not in log and f'{count} checks; failures=[]' in log, suite
    for directory, audit_file in [('realism-native', 'realism-render-audit.json'),
                                  ('realism-compatible', 'realism-render-audit.json'),
                                  ('stele-native', 'maintenance-render-audit.json'),
                                  ('stele-compatible', 'maintenance-render-audit.json')]:
        assert not json.loads((OUT / directory / audit_file).read_text())['failures'], directory
    assert not SNAPSHOT.exists(), 'Preserve existing release snapshot; use a fresh output name.'
    shutil.copytree(ROOT / 'game', SNAPSHOT,
                    ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
    production = fingerprint(ROOT / 'game')
    assert fingerprint(SNAPSHOT) == production
    source_report = {'version': VERSION, 'files': production,
                     'import_fingerprints': 'Authored [params] only; generated remap/deps excluded'}
    (OUT / 'realism-release-source.json').write_text(json.dumps(source_report, indent=2) + '\n')
    temporary = ROOT / '.tools/realism-export-temp'
    temporary.mkdir(exist_ok=True)
    ENVIRONMENT['TMPDIR'] = str(temporary) + '/'
    run([ENGINE, '--headless', '--editor', '--import', '--quit', '--path', SNAPSHOT],
        'v1130-release-import.log')
    assert fingerprint(SNAPSHOT) == production, 'Imported snapshot differs from authored game files'
    archive = OUT / f'SeedInTheRuins-{VERSION}-macOS.zip'
    app = OUT / f'SeedInTheRuins-{VERSION}.app'
    assert not archive.exists() and not app.exists(), 'Preserve previous release outputs'
    run([ENGINE, '--headless', '--path', SNAPSHOT, '--export-release', 'macOS', archive],
        'v1130-release-export.log')
    stage = ROOT / '.tools/realism-macos-extracted'
    assert not stage.exists(), stage
    subprocess.run(['ditto', '-x', '-k', str(archive), str(stage)], check=True)
    packages = list(stage.glob('*.app'))
    assert len(packages) == 1
    shutil.move(str(packages[0]), app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString'] == VERSION
    binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
    binary.chmod(0o755)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    verified = {}
    # Every gameplay scene uses its own isolated save file.
    for suite in ['menu', 'puzzle', 'maintenance_record', 'sun_console_access', 'later_visibility']:
        expected = summary['suites'][suite]
        run([binary, '--headless', f'res://tests/{suite}_flow.tscn'],
            f'v1130-exported-{suite}-tests.log', f'{expected} checks; failures=[]')
        verified[suite] = expected
    run([binary, '--headless', '--audio-driver', 'Dummy',
         'res://tests/realism_audio_review.tscn', '--',
         '--review-dir=' + str(OUT / 'realism-exported-audio')],
        'v1130-exported-audio-tests.log', '30 checks; failures=[]')
    verified['realism_audio'] = 30
    # The review is also run through the packaged renderer, rather than merely
    # treating source-project screenshots as proof of the exported app.
    run([binary, '--rendering-method', 'forward_plus', '--audio-driver', 'Dummy',
         '--position', '-20000,-20000', 'res://tests/maintenance_render_review.tscn',
         '--', '--offscreen-capture', '--review-dir=' + str(OUT / 'stele-exported-native')],
        'v1130-exported-stele-render.log', '13 frames; failures=[]')
    source_zip = OUT / f'SeedInTheRuins-{VERSION}-Source.zip'
    assert not source_zip.exists()
    with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
        for directory in ['game', 'tools', 'docs']:
            for path in sorted((ROOT / directory).rglob('*')):
                if path.is_file() and '.godot' not in path.parts and '__pycache__' not in path.parts and path.name != '.DS_Store':
                    zipped.write(path, str(path.relative_to(ROOT)))
        for name in ['README.md', '启动游戏.command']:
            zipped.write(ROOT / name, name)
    assert fingerprint(ROOT / 'game') == production, 'Game changed while packaging'
    assert fingerprint(SNAPSHOT) == production
    report = {'version': VERSION, 'functional_tests': summary,
              'engine_audio_checks': audio['checks'], 'exported_checks': verified,
              'exported_total': sum(verified.values()), 'exported_stele_frames': 13,
              'signature': 'codesign --verify --deep --strict passed',
              'source': 'realism-release-source.json',
              'packages': {p.name: {'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
                                     'bytes': p.stat().st_size} for p in [archive, source_zip]},
              'failures': []}
    (OUT / 'realism-release-verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('REALISM_RELEASE_OK', summary['total'], '+', audio['checks'],
          'source checks;', report['exported_total'], 'exported checks; 13 exported render frames', flush=True)


if __name__ == '__main__':
    main()
