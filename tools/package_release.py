"""Build a local release after both actual render reviews pass."""
import hashlib
import json
import argparse
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
ENGINE=ROOT/'.tools/Godot.app/Contents/MacOS/Godot'
parser=argparse.ArgumentParser()
parser.add_argument('--version',choices=['1.7.0','1.7.1','1.8.0','1.8.1','1.8.2','1.8.3','1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0','1.11.1','1.12.0','1.12.1'],default='1.7.0')
VERSION=parser.parse_args().version
PREFIX={'1.7.0':'v17','1.7.1':'v171','1.8.0':'v18','1.8.1':'v181','1.8.2':'v182','1.8.3':'v183','1.8.4':'v184','1.9.0':'v19','1.9.1':'v191','1.10.0':'v110','1.10.1':'v1101','1.10.2':'v1102','1.11.0':'v111','1.11.1':'v1111','1.12.0':'v112','1.12.1':'v1121'}[VERSION]
if VERSION=='1.12.1':
    subprocess.run(['python3',str(ROOT/'tools/check_maintenance_release.py')],check=True)
elif VERSION=='1.12.0':
    subprocess.run(['python3',str(ROOT/'tools/check_model_refinement_release.py')],check=True)
elif VERSION=='1.11.1':
    subprocess.run(['python3',str(ROOT/'tools/check_w01_release.py')],check=True)
else:
    for method in ['forward_plus','gl_compatibility']:
        label=PREFIX+'-final' if VERSION in ['1.8.3','1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0'] else 'v18-final' if VERSION in ['1.8.0','1.8.1','1.8.2'] else 'v17-final'
        report=json.loads((OUT/'render-iterations'/label/method/'model-render-audit.json').read_text())
        assert not report['failures']
    for name in ['menu','fps','puzzle','playability','wasteland','scenery']+(['tutorial'] if VERSION in ['1.8.0','1.8.1','1.8.2','1.8.3','1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0'] else []):
        log=(OUT/(PREFIX+'-'+name+'-tests.log')).read_text()
        assert 'failures=[]' in log and 'ERROR:' not in log,name
    assert (OUT/(PREFIX+'-render-pixel-verification.json' if VERSION in ['1.8.3','1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0'] else 'v18-render-pixel-verification.json' if VERSION in ['1.8.0','1.8.1','1.8.2'] else 'v17-render-pixel-verification.json')).exists()
    if VERSION in ['1.8.3','1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0']:
        verification=json.loads((OUT/(PREFIX+'-render-pixel-verification.json')).read_text())
        materials=json.loads((OUT/(PREFIX+'-material-verification.json')).read_text())
        assert materials['failures']==[] and len(materials['assets'])==7
        assert '32 checks; failures=[]' in (OUT/(PREFIX+'-audio-animation-tests.log')).read_text()
        for method in ['forward_plus','gl_compatibility']:
            assert len(verification[method]['frames'])=={'1.8.3':54,'1.8.4':58,'1.9.0':64,'1.9.1':68,'1.10.0':74,'1.10.1':76,'1.10.2':78,'1.11.0':98}[VERSION]
            for relative,digest in verification[method]['source_files'].items():
                assert hashlib.sha256((ROOT/'game'/relative).read_bytes()).hexdigest()==digest,relative
    if VERSION in ['1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0']:
        city=json.loads((OUT/(PREFIX+'-city-material-verification.json')).read_text())
        assert city['failures']==[] and len(city['assets'])==6
    if VERSION in ['1.9.1','1.10.0','1.10.1','1.10.2','1.11.0']:
        garden=json.loads((OUT/(PREFIX+'-garden-material-verification.json')).read_text())
        assert garden['failures']==[] and len(garden['assets'])==3
        tests=json.loads((OUT/(PREFIX+'-test-summary.json')).read_text())
        assert tests['failures']==[] and tests['total']=={'1.9.1':603,'1.10.0':622,'1.10.1':629,'1.10.2':651,'1.11.0':776}[VERSION]
    if VERSION in ['1.10.0','1.10.1','1.10.2','1.11.0']:
        models=ROOT/'models'/VERSION
        model_log=(OUT/(PREFIX+'-model-load-tests.log')).read_text()
        assert 'MODEL_SCENE_LOAD: 3 scenes; failures=[]' in model_log and 'ERROR:' not in model_log
        loaded=json.loads((models/'model-verification.json').read_text())
        assert loaded['failures']==[] and len(loaded['models'])==3
        for entry in loaded['models']:
            assert entry['finite_geometry'] and entry['instances']>1000
            assert hashlib.sha256((models/('chapter-%d.tscn'%entry['chapter'])).read_bytes()).hexdigest()==entry['sha256']
    if VERSION=='1.11.0':
        assert '125 checks; failures=[]' in (OUT/(PREFIX+'-repair-feedback-tests.log')).read_text()
        repairs=json.loads((OUT/(PREFIX+'-repair-render-verification.json')).read_text())
        assert repairs['failures']==[] and all(len(v)==9 for v in repairs['renderers'].values())
    if VERSION=='1.8.0':
        verification=json.loads((OUT/'v18-render-pixel-verification.json').read_text())
        for method in ['forward_plus','gl_compatibility']:
            assert len(verification[method]['frames'])==51
            for relative,digest in verification[method]['source_files'].items():
                assert hashlib.sha256((ROOT/'game'/relative).read_bytes()).hexdigest()==digest,relative
    if VERSION=='1.7.1':
        verification=json.loads((OUT/'v171-story-verification.json').read_text())
        assert verification['failures']==[] and verification['images']==16
        for relative,digest in verification['source_files'].items():
            assert hashlib.sha256((ROOT/'game'/relative).read_bytes()).hexdigest()==digest,relative
    if VERSION=='1.8.1':
        verification=json.loads((OUT/'v181-story-verification.json').read_text())
        assert verification['failures']==[] and verification['images']==28
        for relative,digest in verification['source_files'].items():
            assert hashlib.sha256((ROOT/'game'/relative).read_bytes()).hexdigest()==digest,relative
    if VERSION=='1.8.2':
        verification=json.loads((OUT/'v182-story-verification.json').read_text())
        assert verification['failures']==[] and verification['images']==32
        audio=json.loads((OUT/'v182-audio-verification.json').read_text())
        assert audio['failures']==[] and len(audio['mix']['segments'])==9
        log=(OUT/'v182-audio-animation-tests.log').read_text()
        assert '32 checks; failures=[]' in log and 'ERROR:' not in log
        for relative,digest in verification['source_files'].items():
            assert hashlib.sha256((ROOT/'game'/relative).read_bytes()).hexdigest()==digest,relative
def run_log(name,args):
    with (OUT/name).open('w') as log:subprocess.run(args,stdout=log,stderr=subprocess.STDOUT,check=True)
run_log(PREFIX+'-export-macos.log',[str(ENGINE),'--headless','--path',str(ROOT/'game'),'--export-release','macOS'])
run_log(PREFIX+'-export-windows.log',[str(ENGINE),'--headless','--path',str(ROOT/'game'),'--export-release','Windows Desktop'])
run_log(PREFIX+'-installer.log',['python3',str(ROOT/'tools/package_desktop.py')])
with zipfile.ZipFile(OUT/'SeedInTheRuins-Windows.zip','w',zipfile.ZIP_DEFLATED) as archive:
    archive.write(OUT/'windows/SeedInTheRuins.exe','SeedInTheRuins.exe')
    archive.write(ROOT/'README.md','README.md')
    archive.write(ROOT/'docs/安装与操作.md','安装与操作.md')
    for name in ['GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','ASSET_LICENSES.md']:
        archive.write(ROOT/'docs'/name,'licenses/'+name)
    for path in (ROOT/'game/assets').glob('OFL*.txt'):archive.write(path,'licenses/'+path.name)
source=OUT/('SeedInTheRuins-'+VERSION+'-Source.zip')
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as archive:
    for folder in ['game','tools','docs','backend']+(['models'] if VERSION in ['1.10.0','1.10.1','1.10.2','1.11.0','1.11.1','1.12.0','1.12.1'] else []):
        for path in sorted((ROOT/folder).rglob('*')):
            if not path.is_file() or any(part in ['.godot','.venv','__pycache__'] for part in path.parts):continue
            if path.suffix=='.pyc' or path.name in ['.env','.DS_Store']:continue
            # Import settings are source: retain mipmaps, normal encoding and LOD.
            archive.write(path,'SeedInTheRuins/'+str(path.relative_to(ROOT)))
    for name in ['README.md','启动游戏.command']:archive.write(ROOT/name,'SeedInTheRuins/'+name)
names=['SeedInTheRuins-macOS.zip','SeedInTheRuins-macOS.dmg','SeedInTheRuins-Windows.zip',source.name]
hashes={}
for name in names:
    path=OUT/name
    if path.suffix=='.zip':
        with zipfile.ZipFile(path) as archive:assert archive.testzip() is None,name
    hashes[name]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
(OUT/('SHA256-'+VERSION+'.json')).write_text(json.dumps(hashes,indent=2))
print('RELEASE_PACKAGE_OK',VERSION)
