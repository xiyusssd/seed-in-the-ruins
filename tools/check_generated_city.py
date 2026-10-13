"""Verify original generated city maps and their bindings in actual scene captures."""
import hashlib,json,argparse
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='1.9.0')
parser.add_argument('--label',default='v19-final')
parser.add_argument('--prefix',default='v19')
parser.add_argument('--count',type=int,default=64)
parser.add_argument('--folder',choices=['generated_city','generated_garden'],default='generated_city')
args=parser.parse_args()
families=['city_plaster','quay_stone'] if args.folder=='generated_city' else ['terracotta']
chapters=range(3) if args.folder=='generated_city' else [1]
FOLDER=ROOT/'game/assets'/args.folder
manifest=json.loads((FOLDER/'SOURCES.json').read_text())
result={'version':args.version,'assets':{},'renderers':{},'failures':[]}
for entry in manifest['assets']:
 p=FOLDER/entry['file'];digest=hashlib.sha256(p.read_bytes()).hexdigest()
 assert digest==entry['sha256']==hashlib.sha256(Path(entry['source']).read_bytes()).hexdigest(),entry['file']
 assert entry['prompt'] and entry['source']
 with Image.open(p) as im:
  assert im.size==tuple(entry['size']) and im.width==im.height>=1024
  a=np.asarray(im.convert('RGB'),dtype=float)
 mean=a.mean((0,1));config=p.with_name(p.name+'.import').read_text()
 assert 'compress/mode=2' in config and 'mipmaps/generate=true' in config
 if '_normal.' in p.name:
  assert 'compress/normal_map=1' in config and 100<mean[0]<145 and 100<mean[1]<145 and mean[2]>230
 if '_roughness.' in p.name:
  assert abs(a[:,:,0]-a[:,:,1]).mean()<4 and .45<mean[0]/255<.95
 result['assets'][entry['file']]={'sha256':digest,'size':entry['size'],'mean_rgb':mean.tolist(),'edge_mean_difference':{'x':float(abs(a[:,0]-a[:,-1]).mean()),'y':float(abs(a[0]-a[-1]).mean())},'note':'Original AI-generated maps; normals and roughness are estimates, not measured physical data.'}
assert len(result['assets'])==len(families)*3
for family in families:
 assert len({tuple(result['assets'][family+'_'+channel+'.png']['size']) for channel in ['albedo','normal','roughness']})==1
for method in ['forward_plus','gl_compatibility']:
 folder=ROOT/'builds/render-iterations'/args.label/method
 report=json.loads((folder/'model-render-audit.json').read_text())
 assert report['failures']==[] and len(report['captures'])==args.count
 log=(folder/'render.log').read_text();assert 'ERROR:' not in log and 'SCRIPT ERROR' not in log
 counts={}
 for chapter in chapters:
  materials=[m for n in report['renderables'] if n['chapter']==chapter for m in n['materials']]
  counts[chapter]={family:sum(args.folder+'/'+family+'_albedo' in m for m in materials) for family in families}
  assert all(counts[chapter].values()),(method,chapter,counts[chapter])
 result['renderers'][method]={'frames':args.count,'material_bindings_by_chapter':counts}
(ROOT/'builds'/(args.prefix+('-city-' if args.folder=='generated_city' else '-garden-')+'material-verification.json')).write_text(json.dumps(result,indent=2)+'\n')
print('GENERATED_CITY_CHECK_OK',len(result['assets']),'maps;',args.count*2,'actual frames')
