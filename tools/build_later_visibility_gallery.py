"""Create a local review page from the two actual engine capture reports."""
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
methods = ['gl_compatibility', 'forward_plus']
audits = {method: json.loads((OUT / 'render-iterations/v1123-later-preview' / method /
                             'later-visibility-render-audit.json').read_text()) for method in methods}
rows = []
for entry in audits[methods[0]]['captures']:
    name = entry['name']
    cells = []
    for method in methods:
        path = f'render-iterations/v1123-later-preview/{method}/{name}.png'
        cells.append(f'<a href="{path}"><img src="{path}" alt="{html.escape(name)} — {method}"></a>')
    rows.append(f'<section><h2>{html.escape(name)}</h2><div class="pair">{"".join(cells)}</div></section>')
page = '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>1.12.3 后续机关实景核验</title>'
page += '<style>body{margin:32px;background:#16201c;color:#efe5ce;font:16px system-ui}h1{font-size:28px}h2{font-size:16px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%;height:auto}section{margin:28px 0}a{color:inherit}</style>'
page += '<h1>1.12.3 后续机关实景核验</h1><p>左：OpenGL Compatibility；右：Forward+。点击图片查看原始 1280×800 画面。</p>'
page += '<p>真实第一人称视角，站在可通行的平台；包含压力阀、两面日光镜、种苗架、三个花床、风塔接头，以及五处记录板和全文。机关变化由实际 E 输入触发。</p>'
page += ''.join(rows) + '</html>'
(OUT / 'later-visibility-1.12.3.html').write_text(page)
names = ['later-02-pressure-correct', 'later-05-mirror-0-correct', 'later-05-mirror-1-correct',
         'later-08-seed-rack', 'later-12-bed-0-correct', 'later-12-bed-1-correct',
         'later-12-bed-2-correct', 'later-14-roots-correct']
contact = Image.new('RGB', (1280, len(names) * 428), '#16201c')
draw = ImageDraw.Draw(contact)
for row, name in enumerate(names):
    draw.text((8, row * 428 + 6), name, fill='#efe5ce')
    for col, method in enumerate(methods):
        source = OUT / 'render-iterations/v1123-later-preview' / method / (name + '.png')
        frame = Image.open(source).convert('RGB').resize((640, 400))
        contact.paste(frame, (col * 640, row * 428 + 28))
contact.save(OUT / 'later-visibility-state-review.jpg', quality=92)
print('LATER_VISIBILITY_GALLERY_OK', len(rows) * 2, 'frames')
