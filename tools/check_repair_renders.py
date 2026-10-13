"""Check that task results change actual pixels beyond their result banner."""
from pathlib import Path
import json,argparse
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
tasks=['water_route','pressure','pump','power','mirrors','roof','planting','irrigation','life']
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='1.11.0')
parser.add_argument('--label',default='v111-final')
parser.add_argument('--prefix',default='v111')
parser.add_argument('--count',type=int,default=98)
args=parser.parse_args()
result={'version':args.version,'renderers':{},'failures':[]}
for method in ['forward_plus','gl_compatibility']:
    folder=ROOT/'builds/render-iterations'/args.label/method
    report=json.loads((folder/'model-render-audit.json').read_text())
    assert not report['failures'] and len(report['captures'])==args.count
    entries={e['name']:e for e in report['captures']};values={}
    for task in tasks:
        keys=['repair-'+task+'-'+s for s in ['before','after']]
        assert all(entries[keys[0]][k]==entries[keys[1]][k] for k in ['eye','target','width','height'])
        # The banner occupies y >= 670; inspect scenery rather than text/UI.
        before,after=[np.asarray(Image.open(folder/(k+'.png')).convert('RGB'),dtype=np.float32)[:650] for k in keys]
        difference=abs(after-before)
        mad=float(difference.mean());changed=float((difference.max(2)>12).mean())
        assert mad>.4 and changed>.003,(method,task,mad,changed)
        values[task]={'scenery_mean_absolute_rgb_change':mad,'scenery_fraction_changed_by_more_than_12':changed,'same_camera':True,'banner_excluded':True}
    result['renderers'][method]=values
(ROOT/'builds'/(args.prefix+'-repair-render-verification.json')).write_text(json.dumps(result,indent=2)+'\n')
print('REPAIR_SCENERY_PIXELS_OK',18,'same-camera result pairs')
