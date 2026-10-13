"""Verify readable maintenance records and preserve the reviewed 1.12.0 scene."""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
parser=argparse.ArgumentParser()
parser.add_argument('--project',type=Path,default=ROOT/'game')
PROJECT=parser.parse_args().project.resolve()
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
old=json.loads((OUT/'v112-production-freeze.json').read_text())['files']
frozen=json.loads((OUT/'v1121-production-freeze.json').read_text())['files']
assert set(old)==set(frozen)
changed={n for n in frozen if old[n]!=frozen[n]}
assert changed=={'export_presets.cfg'}|{'scripts/'+n+'.gd' for n in ['puzzle_world','garden_ui','garden','restoration_effects','worksite_details']},changed
for name,value in frozen.items():assert digest(PROJECT/name)==value,name
tests=json.loads((OUT/'v1121-test-summary.json').read_text())
assert tests['failures']==[] and tests['total']==948 and len(tests['suites'])==13
for name,count in tests['suites'].items():
    log=(OUT/f'v1121-{name}-tests.log').read_text()
    assert f'{count} checks; failures=[]' in log and 'ERROR:' not in log,name
prior=json.loads((OUT/'v112-release-verification.json').read_text())
assert prior['checks']==849 and prior['actual_render_captures']==200 and prior['source_archive_matches_game']=='passed'
models=json.loads((ROOT/'models/1.12.0/model-verification.json').read_text())
assert models['failures']==[] and len(models['models'])==3
for entry in models['models']:assert digest(ROOT/f'models/1.12.0/chapter-{entry["chapter"]}.tscn')==entry['sha256']
keys={'route','pressure','power','mirrors','beds','roots'}
expected={key+'-'+kind for key in keys for kind in ['world','document']}|{'route-world-grayscale'}
result={'version':'1.12.1','checks':948,'changed_production_files':sorted(changed),'unchanged_production_files':len(frozen)-len(changed),'inherited_building_models':'models/1.12.0; all three hashes unchanged','inherited_full_scene_review':'1.12.0, 200 captures; records separately rerendered below','actual_new_captures':26,'renderers':{},'failures':[]}
for method in ['forward_plus','gl_compatibility']:
    folder=OUT/'render-iterations/v1121-records-final'/method
    report=json.loads((folder/'maintenance-render-audit.json').read_text())
    assert report['failures']==[] and report['renderer']==method and report['display']=='X11'
    assert len(report['captures'])==13 and {e['name'] for e in report['captures']}==expected
    log=(folder/'maintenance_render_review-render.log').read_text()
    assert 'ERROR:' not in log and 'MAINTENANCE_RENDER_AUDIT: 13 frames; failures=[]' in log
    clone=ROOT/'.tools/render-background/v1121-records-final'/method
    for name,value in frozen.items():assert digest(clone/name)==value,(method,name)
    assert (clone/'tests/maintenance_render_review.gd').read_bytes()==(PROJECT/'tests/maintenance_render_review.gd').read_bytes()
    frames={}
    for entry in report['captures']:
        path=folder/(entry['name']+'.png');rgb=np.asarray(Image.open(path).convert('RGB'),dtype=np.float32)
        assert rgb.shape==(800,1280,3) and rgb.std()>8,entry['name']
        if entry['name'].endswith('-world'):
            assert entry['ray_reachable'] and entry['supported_walkway'] and entry['body_projected_character_height']>=18
        if entry['name'].endswith('-document'):
            assert entry['archived'] and len(entry['printed_ui'])>=5
        frames[entry['name']]={'sha256':digest(path),'std':float(rgb.std())}
    result['renderers'][method]=frames
review=json.loads((OUT/'v1121-visual-review.json').read_text())
assert review['status']=='reviewed' and len(review['pages'])==8
for entry in review['pages']:assert digest(Path(entry['path']))==entry['sha256']
(OUT/'v1121-maintenance-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('MAINTENANCE_RELEASE_OK: 948 checks; 26 actual new record captures; 160 unchanged production files')
