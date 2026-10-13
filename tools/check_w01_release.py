"""Validate the W-01 delta against the fully reviewed 1.11.0 release."""
import hashlib
import json
import re
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
old=json.loads((OUT/'v111-production-freeze.json').read_text())['files']
current=json.loads((OUT/'v1111-production-freeze.json').read_text())['files']
allowed={'export_presets.cfg'}|{'scripts/'+name+'.gd' for name in ['garden','puzzle_world','worksite_details','restoration_effects','repair_focus','pump_tutorial']}
assert set(current)==set(old)
changed={name for name in current if current[name]!=old[name]}
assert changed==allowed,changed
for name,value in current.items():assert digest(ROOT/'game'/name)==value,name
tests=json.loads((OUT/'v1111-test-summary.json').read_text())
assert tests['failures']==[] and tests['total']==810 and len(tests['suites'])==10
for name,count in tests['suites'].items():
    log=(OUT/f'v1111-{name}-tests.log').read_text()
    assert f'{count} checks; failures=[]' in log and 'ERROR:' not in log,name
assert 'W-01 nameplate faces the reachable landing rather than the water' in (OUT/'v1111-w01-before-tests.log').read_text()
prior=json.loads((OUT/'v111-release-verification.json').read_text())
assert prior['checks']==776 and prior['actual_render_captures']==196
assert prior['source_archive_matches_game']=='passed'
models=json.loads((ROOT/'models/1.11.0/model-verification.json').read_text())
assert models['failures']==[] and len(models['models'])==3
model_log=(OUT/'v1111-model-load-tests.log').read_text()
assert 'MODEL_SCENE_LOAD: 3 scenes; failures=[]' in model_log and 'ERROR:' not in model_log
for entry in models['models']:assert digest(ROOT/f'models/1.11.0/chapter-{entry["chapter"]}.tscn')==entry['sha256']
result={'version':'1.11.1','checks':810,'changed_production_files':sorted(changed),'unchanged_production_files':len(current)-len(changed),'unchanged_building_models':'models/1.11.0; 3 hashes verified','renderers':{},'failures':[]}
def values(text):return np.array([float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?',text)])
for method in ['forward_plus','gl_compatibility']:
    newfolder=OUT/'render-iterations/v1111-w01-final'/method
    oldfolder=OUT/'render-iterations/v1111-w01-baseline'/method
    reports=[];images=[]
    for folder,count,label,source in [(newfolder,6,'v1111-w01-final',current),(oldfolder,4,'v1111-w01-baseline',old)]:
        report=json.loads((folder/'w01-render-audit.json').read_text())
        assert report['failures']==[] and report['renderer']==method and report['display']=='X11'
        assert len(report['captures'])==count
        log=(folder/'w01_render_review-render.log').read_text()
        assert f'W01_RENDER_AUDIT: {count} frames; failures=[]' in log and 'ERROR:' not in log
        clone=ROOT/'.tools/render-background'/label/method
        for name,value in source.items():assert digest(clone/name)==value,(label,method,name)
        assert (clone/'tests/w01_render_review.gd').read_bytes()==(ROOT/'game/tests/w01_render_review.gd').read_bytes()
        frames={}
        for entry in report['captures']:
            path=folder/(entry['name']+'.png');rgb=np.asarray(Image.open(path).convert('RGB'),dtype=np.float32)
            assert rgb.shape==(800,1280,3) and rgb.std()>8,entry['name']
            frames[entry['name']]={'sha256':digest(path),'std':float(rgb.std()),'colour_fraction':float((rgb.max(2)-rgb.min(2)>5).mean())}
        progression=[frames[f'w01-0{i}-player-'+name]['colour_fraction'] for i,name in [(2,'grayscale'),(3,'early-colour'),(4,'full-colour')]]
        assert progression[0]==0 and 0<progression[1]<progression[2],progression
        reports.append(report);images.append(frames)
    newentries={e['name']:e for e in reports[0]['captures']};oldentries={e['name']:e for e in reports[1]['captures']}
    name='w01-04-player-full-colour'
    assert np.allclose(values(newentries[name]['camera']),values(oldentries[name]['camera']),atol=.005)
    before,after=[np.asarray(Image.open(folder/(name+'.png')).convert('RGB'),dtype=np.float32)[:650] for folder in [oldfolder,newfolder]]
    delta=abs(after-before);assert float((delta.max(2)>12).mean())>.005
    pair=['w01-05-repair-before','w01-06-repair-after']
    assert np.allclose(values(newentries[pair[0]]['camera']),values(newentries[pair[1]]['camera']),atol=.0001)
    assert all(newentries[n]['recovery']==1 and newentries[n]['fov']==58 for n in pair)
    before,after=[np.asarray(Image.open(newfolder/(n+'.png')).convert('RGB'),dtype=np.float32)[:650] for n in pair]
    delta=abs(after-before);mad=float(delta.mean());fraction=float((delta.max(2)>12).mean())
    assert mad>.4 and fraction>.003,(method,mad,fraction)
    result['renderers'][method]={'new_frames':images[0],'baseline_frames':images[1],'same_player_camera':True,'repair_same_camera':True,'repair_banner_excluded':True,'repair_mean_absolute_rgb_change':mad,'repair_fraction_changed_by_more_than_12':fraction}
result['new_actual_frames']=12;result['baseline_actual_frames']=8
(OUT/'v1111-w01-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('W01_RELEASE_CHECK_OK: 810 checks; 12 new + 8 baseline actual images; 158 unchanged production files')
