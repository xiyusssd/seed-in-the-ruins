"""Check every rendered frame and the exact 0/50/100 colour progression."""
import json
import hashlib
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--label',default='v17-final')
parser.add_argument('--count',type=int,default=42)
parser.add_argument('--prefix',default='v17')
args=parser.parse_args()
base=ROOT/'builds/render-iterations'/args.label
summary={}
for method in ['forward_plus','gl_compatibility']:
    folder=base/method
    report=json.loads((folder/'model-render-audit.json').read_text())
    assert not report['failures'],report['failures']
    assert report['renderer']==method
    assert len(report['captures'])==args.count and len({c['name'] for c in report['captures']})==args.count
    assert report['renderables'] and report['unique_meshes']>0
    if args.prefix in ['v1101','v1102','v111','v112']:
        assert report['environment']['sky_shader']=='res://shaders/coastal_morning.gdshader'
        assert report['environment']['sky_panorama']=='res://assets/scenery/coastal_daylight.hdr'
        assert report['reflections'] and {r['chapter'] for r in report['reflections']}=={0,1,2}
        assert all((r['cull_mask'] & r['water_layers'])==0 and (r['reflection_mask'] & r['water_layers'])!=0 and r['shadows'] for r in report['reflections'])
    frames={}
    for entry in report['captures']:
        rgb=np.asarray(Image.open(folder/(entry['name']+'.png')).convert('RGB'),dtype=np.int16)
        assert tuple(rgb.shape[:2])==((480,640) if entry['name'].startswith('ui-story-small') else (800,1280)),entry['name']
        assert rgb.std()>8,(entry['name'],'blank/flat image')
        frames[entry['name']]={'mean':float(rgb.mean()),'std':float(rgb.std()),'colour_fraction':float((rgb.max(2)-rgb.min(2)>5).mean())}
    progression=[frames[n]['colour_fraction'] for n in ['11-monochrome','12-half-colour','13-full-colour']]
    assert progression[0]==0 and 0<progression[1]<progression[2],progression
    assert all(frames[n]['colour_fraction']>.01 for n in frames if n.startswith('ui-'))
    source_files={}
    clone=ROOT/'.tools/render-background'/args.label/method
    for path in sorted((ROOT/'game').rglob('*')):
        if not path.is_file() or '.godot' in path.parts or 'tests' in path.relative_to(ROOT/'game').parts:continue
        if path.suffix in ['.import','.uid']:continue # platform-generated metadata
        relative=path.relative_to(ROOT/'game')
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        assert hashlib.sha256((clone/relative).read_bytes()).hexdigest()==digest,(method,str(relative),'source changed after capture')
        source_files[str(relative)]=digest
    summary[method]={'frames':frames,'colour_progression':progression,'renderables':len(report['renderables']),'unique_meshes':report['unique_meshes'],'adapter':report['adapter'],'source_files':source_files}
(ROOT/('builds/'+args.prefix+'-render-pixel-verification.json')).write_text(json.dumps(summary,indent=2))
print('RENDER_PIXEL_CHECK_OK',sum(len(v['frames']) for v in summary.values()),'images')
