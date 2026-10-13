"""Flatten imported scene declarations in real renderer snapshots for editing.

Godot 4.5 writes both explicit mesh children and their source PackedScene when
all descendants receive the exported root as owner. Re-instantiation replaces
an inherited mesh and leaves its old object orphaned. Keep the explicit saved
mesh/transform/material hierarchy and remove the redundant scene declaration.
"""
from pathlib import Path
import hashlib,json,re,argparse
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--version',default='1.10.0')
parser.add_argument('--label',default='v110-final')
args=parser.parse_args()
source=ROOT/'builds/render-iterations'/args.label/'forward_plus/models'
out=ROOT/'models'/args.version;out.mkdir(parents=True,exist_ok=True)
records=[]
for chapter in range(3):
    original=source/f'chapter-{chapter}.tscn';text=original.read_text()
    declarations=re.findall(r'\[node[^\n]+ instance=ExtResource\("[^\"]+"\)\]',text)
    assert declarations and all('type="Node3D"' in row for row in declarations)
    baked=re.sub(r'(\[node[^\n]+) instance=ExtResource\("[^\"]+"\)(\])',r'\1\2',text)
    # Other node fields, raw meshes, UVs, normals and instance buffers are unchanged.
    for line in text.splitlines():
        if not line.startswith('[node'):continue
        normalized=re.sub(r' instance=ExtResource\("[^\"]+"\)','',line)
        assert normalized in baked
    path=out/original.name;path.write_text(baked)
    records.append({'chapter':chapter,'raw_snapshot_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
                    'baked_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'flattened_scene_declarations':len(declarations),
                    'geometry_data':'unchanged; redundant inherited scene declarations removed'})
(out/'snapshot-provenance.json').write_text(json.dumps(records,indent=2)+'\n')
print('EDITABLE_MODELS_BAKED',len(records))
