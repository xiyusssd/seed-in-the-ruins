"""Reduce verified CC0 scans while retaining their materials and UV seams.

Run with NumPy, SciPy and fast-simplification. Originals stay in .tools/asset-catalog.
"""
import hashlib
import json
from pathlib import Path
import sys
import subprocess

import numpy as np
from scipy.spatial import cKDTree
import fast_simplification

ROOT = Path(__file__).resolve().parents[1]
REPORT = []
manifest=json.loads((ROOT/'game/assets/scenery/SOURCES.json').read_text())
for name, limits in [('tree_small_02', [20000, 180000, 14000]), ('coast_rocks_02', [35000])]:
    source = ROOT / '.tools/asset-catalog' / (name + '.gltf')
    source.parent.mkdir(parents=True,exist_ok=True)
    for suffix in ['gltf','bin']:
        destination=source if suffix=='gltf' else source.parent/(name+'-original.bin')
        if not destination.exists():
            entry=next(f for f in manifest['files'] if f['asset']==name and f['file'].endswith('.'+suffix))
            subprocess.run(['curl','--retry','3','--retry-all-errors','-fLsS',entry['url'],'-o',str(destination)],check=True)
            assert hashlib.sha256(destination.read_bytes()).hexdigest()==entry['download_sha256']
    data = json.loads(source.read_text())
    original = (source.parent / (name + '-original.bin')).read_bytes()
    output = bytearray()
    views, accessors = [], []

    def read(index):
        a = data['accessors'][index]
        view = data['bufferViews'][a['bufferView']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[a['componentType']]
        width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
        offset = view.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(original, dtype=dtype, count=a['count'] * width, offset=offset).reshape(-1, width).copy()

    def write(array, kind, component=5126):
        array = np.ascontiguousarray(array, dtype='<f4' if component == 5126 else '<u4')
        while len(output) % 4:
            output.append(0)
        start = len(output)
        output.extend(array.tobytes())
        views.append({'buffer': 0, 'byteOffset': start, 'byteLength': array.nbytes})
        accessor = {'bufferView': len(views)-1, 'componentType': component, 'count': len(array), 'type': kind}
        if kind == 'VEC3':
            accessor.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
        accessors.append(accessor)
        return len(accessors)-1

    for mesh in data['meshes']:
        for index, primitive in enumerate(mesh['primitives']):
            points = read(primitive['attributes']['POSITION'])
            triangles = read(primitive['indices']).reshape(-1, 3).astype(np.int32)
            simplified, faces = fast_simplification.simplify(points, triangles, target_count=limits[index], agg=5.0, preserve_border=(name != 'tree_small_02' or index != 1))
            nearest = cKDTree(points).query(simplified, workers=1)[1]
            attrs = {}
            for semantic, accessor in primitive['attributes'].items():
                array = simplified if semantic == 'POSITION' else read(accessor)[nearest]
                if semantic == 'NORMAL':
                    array /= np.maximum(np.linalg.norm(array, axis=1, keepdims=True), 1e-8)
                attrs[semantic] = write(array, data['accessors'][accessor]['type'])
            primitive['attributes'] = attrs
            primitive['indices'] = write(faces.reshape(-1, 1), 'SCALAR', 5125)
            REPORT.append({'asset': name, 'surface': index, 'before_triangles': len(triangles), 'after_triangles': len(faces)})
    data['accessors'] = accessors
    data['bufferViews'] = views
    data['buffers'] = [{'uri': name+'.bin', 'byteLength': len(output)}]
    # Leaves are actual leaf geometry, not cutout cards; an opaque pipeline avoids
    # sorting artifacts from the source export's unnecessary BLEND flag.
    for mat in data.get('materials', []):
        if mat.get('alphaMode') == 'BLEND':
            mat['alphaMode'] = 'OPAQUE'
    target = ROOT / 'game/assets/scenery' / name
    (target / (name+'.bin')).write_bytes(output)
    (target / (name+'.gltf')).write_text(json.dumps(data, separators=(',', ':')))
    print(name, 'runtime mesh bytes', len(output), flush=True)
(ROOT/'game/assets/scenery/OPTIMIZATION.json').write_text(json.dumps(REPORT, indent=2))
for entry in manifest['files']:
    entry['runtime_sha256']=hashlib.sha256((ROOT/'game/assets/scenery'/entry['file']).read_bytes()).hexdigest()
    entry['processed']=entry['runtime_sha256']!=entry['download_sha256']
(ROOT/'game/assets/scenery/SOURCES.json').write_text(json.dumps(manifest,indent=2))
