"""Validate the generated production textures and their actual render inventory."""
import hashlib
import json
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--version', default='1.8.3')
parser.add_argument('--label', default='v183-final')
parser.add_argument('--prefix', default='v183')
parser.add_argument('--count', type=int, default=54)
args = parser.parse_args()
GAME = ROOT / 'game'
FOLDER = GAME / 'assets/generated_materials'
manifest = json.loads((FOLDER / 'SOURCES.json').read_text())
result = {'version': args.version, 'assets': {}, 'renderers': {}, 'failures': []}
for entry in manifest['assets']:
    path = FOLDER / entry['file']
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == entry['sha256'], entry['file']
    # The game files are exact copies, without downstream image edits.
    assert hashlib.sha256(Path(entry['source']).read_bytes()).hexdigest() == digest
    with Image.open(path) as image:
        assert image.size == tuple(entry['size']) and image.width == image.height >= 1024
        pixels = np.asarray(image.convert('RGB'), dtype=np.float32)
    config = (FOLDER / (entry['file'] + '.import')).read_text()
    assert 'mipmaps/generate=true' in config and 'compress/mode=2' in config
    mean = pixels.mean((0, 1))
    if '_normal.' in entry['file']:
        assert 'compress/normal_map=1' in config
        assert 110 < mean[0] < 145 and 110 < mean[1] < 145 and mean[2] > 235
    elif '_roughness.' in entry['file']:
        assert float((pixels.max(2) - pixels.min(2)).mean()) < 4
        assert .6 < mean[0] / 255 < .95
    result['assets'][entry['file']] = {
        'sha256': digest, 'size': entry['size'], 'mean_rgb': mean.tolist(),
        'repeat_edge_mean_difference': {
            'x': float(abs(pixels[:, 0] - pixels[:, -1]).mean()),
            'y': float(abs(pixels[0] - pixels[-1]).mean()),
        },
        'note': 'AI estimates, not measured material data; seam appearance reviewed in engine.',
    }
for family in ['plaster', 'concrete']:
    assert len({tuple(result['assets'][family + '_' + channel + '.png']['size'])
                for channel in ['albedo', 'normal', 'roughness']}) == 1

# Preserve all third-party provenance and the previous sound/CG implementation.
old = json.loads((ROOT / 'builds/v182-story-verification.json').read_text())
allowed = {'scripts/garden_shapes.gd', 'scripts/coastal_scenery.gd',
           'shaders/botanical_leaf.gdshader', 'shaders/coastal_foliage.gdshader',
           'export_presets.cfg'}
if args.version in ['1.8.4','1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0']:
    allowed.add('shaders/ruins_water.gdshader')
if args.version in ['1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0']:
    allowed.add('scripts/garden.gd')
if args.version in ['1.10.0','1.10.1','1.10.2','1.11.0']:
    allowed.add('scripts/chapter_scenery.gd')
if args.version=='1.11.0':
    allowed.update({'scripts/garden_ui.gd','scripts/pump_tutorial.gd','scripts/ruins_lighting.gd'})
if args.version=='1.12.0':
    allowed.update({'shaders/ruins_water.gdshader','shaders/ruins_glass.gdshader','scripts/garden.gd','scripts/chapter_scenery.gd','scripts/garden_ui.gd','scripts/pump_tutorial.gd','scripts/ruins_lighting.gd','scripts/puzzle_world.gd','scripts/worksite_details.gd'})
changed = []
for relative, digest in old['source_files'].items():
    current = hashlib.sha256((GAME / relative).read_bytes()).hexdigest()
    if current != digest:
        assert relative in allowed, relative
        changed.append(relative)
result['changed_from_1.8.2'] = changed
result['inherited_audio_and_cinematics'] = 'All previous source hashes match except explicitly allowed scenery, material and version files.'

for method in ['forward_plus', 'gl_compatibility']:
    folder = ROOT / 'builds/render-iterations' / args.label / method
    report = json.loads((folder / 'model-render-audit.json').read_text())
    assert not report['failures'] and len(report['captures']) == args.count
    text = (folder / 'render.log').read_text()
    assert 'ERROR:' not in text and 'SCRIPT ERROR' not in text
    counts = {}
    for chapter in range(3):
        chapter_materials = [material for node in report['renderables'] if node['chapter'] == chapter
                             for material in node['materials']]
        counts[chapter] = {family: sum('generated_materials/' + family + '_albedo' in m
                                     for m in chapter_materials) for family in ['plaster', 'concrete']}
        assert all(counts[chapter].values()), (method, chapter, counts[chapter])
    result['renderers'][method] = {'frames': args.count, 'material_bindings_by_chapter': counts}

(ROOT / 'builds' / (args.prefix+'-material-verification.json')).write_text(json.dumps(result, indent=2))
print('GENERATED_MATERIAL_CHECK_OK', len(result['assets']), 'assets;', args.count*2, 'actual frames')
