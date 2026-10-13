"""Verify story captures and unchanged world resources against the 1.7 baseline."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'builds/render-iterations/v171-story'
allowed={'scripts/garden_ui.gd','scripts/story_vignette.gd','assets/story_font.tres','export_presets.cfg'}
source={str(p.relative_to(ROOT/'game')):hashlib.sha256(p.read_bytes()).hexdigest()
        for p in sorted((ROOT/'game').rglob('*'))
        if p.is_file() and '.godot' not in p.parts and 'tests' not in p.relative_to(ROOT/'game').parts and p.suffix not in ['.uid','.import']}
summary={'images':0,'failures':[],'source_files':source,'allowed_changed_files':sorted(allowed),'renderers':{}}
sections=[]
labels={'story-desktop-0':'潮水留下的线','story-desktop-1':'最后一枚种子','story-desktop-2':'给春天留的位置','story-next-focus':'键盘焦点','story-small-0':'小窗口 · 第一页','story-small-1':'小窗口 · 第二页','story-small-2':'小窗口 · 第三页','story-small-scrolled':'小窗口 · 滚动正文后'}
for method in ['forward_plus','gl_compatibility']:
    folder=BASE/method
    report=json.loads((folder/'story-render-audit.json').read_text())
    assert report['failures']==[] and report['renderer']==method,report
    assert len(report['captures'])==8 and {c['name'] for c in report['captures']}==set(labels)
    assert len(report['layouts'])==7
    log=(folder/'story_review-render.log').read_text()
    assert 'ERROR:' not in log and 'STORY_RENDER_AUDIT: 8 frames; failures=[]' in log
    prior=json.loads((ROOT/'builds/v17-render-pixel-verification.json').read_text())[method]['source_files']
    assert set(source)==set(prior)
    for relative,digest in source.items():
        captured=ROOT/'.tools/render-background/v171-story'/method/relative
        assert hashlib.sha256(captured.read_bytes()).hexdigest()==digest,(method,relative,'changed after capture')
        if relative not in allowed:assert digest==prior[relative],('uncaptured world change',relative)
    for layout in report['layouts']:
        b=layout['buttons'];left=b['StoryPrevious'];right=b['StoryNext'];skip=b['StorySkip']
        assert left['x']<right['x'] and abs(left['y']-right['y'])<1
        assert skip['y']<right['y'] and skip['x']>left['x']
        if layout['name'].startswith('story-desktop'):
            assert layout['scroll_max']<=layout['scroll_page']+1
    frames={};cards=[]
    sheet=Image.new('RGB',(1280,568),'#202b24');draw=ImageDraw.Draw(sheet)
    for i,c in enumerate(report['captures']):
        im=Image.open(folder/(c['name']+'.png')).convert('RGB')
        expected=(640,480) if c['name'].startswith('story-small') else (1280,800)
        assert im.size==expected,(method,c['name'],im.size)
        rgb=np.asarray(im,dtype=np.int16)
        assert rgb.std()>8 and ((rgb.max(2)-rgb.min(2))>5).mean()>.05
        frames[c['name']]={'size':im.size,'std':float(rgb.std())}
        im.thumbnail((320,240));x=(i%4)*320;y=(i//4)*284
        sheet.paste(im,(x,y));draw.text((x+8,y+248),c['name'],fill='#e6ddc8')
        url='render-iterations/v171-story/'+method+'/'+c['name']+'.png'
        cards.append(f'<figure><a href="{url}"><img src="{url}" alt="{labels[c["name"]]}" loading="lazy"></a><figcaption>{labels[c["name"]]} · {expected[0]}×{expected[1]}</figcaption></figure>')
    sheet.save(folder/'contact-sheet.jpg',quality=92)
    summary['images']+=len(frames)
    summary['renderers'][method]={'adapter':report['adapter'],'frames':frames,'layouts':report['layouts']}
    sections.append('<section><h2>'+('高画质 · Forward+' if method=='forward_plus' else '兼容画质 · OpenGL')+'</h2><div class="grid">'+''.join(cards)+'</div></section>')
(ROOT/'builds/v171-story-verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 故事与手记</title><style>body{margin:0;background:#202b24;color:#e6ddc8;font:16px/1.7 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px 24px}h1{font-size:30px}h2{color:#c3a164;font-size:22px}p{max-width:900px;color:#b7b09c}a{color:#c3a164}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}figure{margin:0}img{width:100%;display:block}figcaption{padding:8px 0;color:#b7b09c}@media(max-width:720px){.grid{grid-template-columns:1fr}}</style><main><h1>故事与手记 · 1.7.1</h1><p>左右翻页，右上跳过。线索藏在水痕、叶影与旧花盆的叙事里。点击图片可查看原图。这16张为虚拟显示中的实际软件渲染，未验证原生GPU帧率。</p><p><a href="visual-board.html">查看沿用的三章模型与灯光画面（1.7.0）</a></p>'''+''.join(sections)+'</main></html>'
(ROOT/'builds/story-review.html').write_text(html)
print('STORY_PIXEL_CHECK_OK',summary['images'],'images; world resources unchanged')
