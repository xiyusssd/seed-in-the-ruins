"""Release gate for the complete 1.12.0 model and raster review."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
frozen=json.loads((OUT/'v112-production-freeze.json').read_text())['files']
previous=json.loads((OUT/'v1111-production-freeze.json').read_text())['files']
changed={p for p in previous if frozen[p]!=previous[p]}
assert changed=={'export_presets.cfg','scripts/cinematic_ruins.gd','scripts/reference_reconstruction.gd','shaders/ruins_glass.gdshader','shaders/coastal_foliage.gdshader'},changed
assert set(frozen)-set(previous)=={'scripts/structural_refinement.gd'}
for name,value in frozen.items():assert digest(ROOT/'game'/name)==value,name
tests=json.loads((OUT/'v112-test-summary.json').read_text())
assert tests['total']==849 and tests['failures']==[] and len(tests['suites'])==11
for name,count in tests['suites'].items():
    log=(OUT/f'v112-{name}-tests.log').read_text()
    assert f'{count} checks; failures=[]' in log and 'ERROR:' not in log,name
maps=0
for suffix,count in [('material',7),('city-material',6),('garden-material',3)]:
    report=json.loads((OUT/f'v112-{suffix}-verification.json').read_text())
    assert report['failures']==[] and len(report['assets'])==count
    maps+=count
pixels=json.loads((OUT/'v112-render-pixel-verification.json').read_text())
repairs=json.loads((OUT/'v112-repair-render-verification.json').read_text())
assert repairs['failures']==[] and all(len(v)==9 for v in repairs['renderers'].values())
for method in ['forward_plus','gl_compatibility']:
    folder=OUT/'render-iterations/v112-final'/method
    report=json.loads((folder/'model-render-audit.json').read_text())
    assert not report['failures'] and len(report['captures'])==100 and len(pixels[method]['frames'])==100
    log=(folder/'render.log').read_text();assert 'ERROR:' not in log
    assert {v['chapter'] for v in report['structural_members']}=={0,1,2}
    assert all(v['contacts_verified']==v['members']>0 for v in report['structural_members'])
    for relative,value in frozen.items():
        clone=ROOT/'.tools/render-background/v112-final'/method/relative
        assert digest(clone)==value,(method,relative)
    assert (ROOT/'.tools/render-background/v112-final'/method/'tests/render_review.gd').read_bytes()==(ROOT/'game/tests/render_review.gd').read_bytes()
models=ROOT/'models/1.12.0'
loaded=json.loads((models/'model-verification.json').read_text())
assert loaded['failures']==[] and len(loaded['models'])==3
for entry in loaded['models']:
    assert entry['finite_geometry'] and entry['instances']>1000
    assert digest(models/f'chapter-{entry["chapter"]}.tscn')==entry['sha256']
log=(OUT/'v112-model-load-tests.log').read_text()
assert 'MODEL_SCENE_LOAD: 3 scenes; failures=[]' in log and 'ERROR:' not in log
review=json.loads((OUT/'v112-visual-review.json').read_text())
assert len(review['pages'])==10 and all(digest(Path(p['path']))==p['sha256'] for p in review['pages'])
result={'version':'1.12.0','checks':849,'actual_frames':200,'original_maps':maps,'changed_production_files':sorted(changed),'new_production_files':sorted(set(frozen)-set(previous)),'native_models':3,'repair_pairs':18,'failures':[]}
(OUT/'v112-model-refinement-verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('MODEL_REFINEMENT_RELEASE_OK',result)
