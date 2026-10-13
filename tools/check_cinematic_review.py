"""Check actual intro renders, temporal change and unchanged 1.8 world sources."""
import hashlib,json,argparse
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--version',choices=['1.8.1','1.8.2'],default='1.8.1');version=parser.parse_args().version
prefix='v182' if version=='1.8.2' else 'v181'
LABEL=prefix+'-cg'
BASE=ROOT/'builds/render-iterations'/LABEL
allowed={'scripts/garden_ui.gd','scripts/story_vignette.gd','export_presets.cfg','shaders/story_film.gdshader','assets/cinematic_title_font.tres','assets/cinematics/tide.png','assets/cinematics/yaya.png','assets/cinematics/spring.png'}
if version=='1.8.2':
    allowed.update({'scripts/soundscape.gd','scripts/robot_companion.gd','scripts/garden.gd'})
    allowed.update(str(p.relative_to(ROOT/'game')) for p in (ROOT/'game/audio').glob('*.wav') if p.stem in ['prologue_score','prologue_air0','prologue_air1','prologue_air2','ui_hover','ui_confirm','ui_page','ui_exit','ui_arrival'] or p.stem.startswith('chapter'))
source={str(p.relative_to(ROOT/'game')):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'game').rglob('*')) if p.is_file() and '.godot' not in p.parts and 'tests' not in p.relative_to(ROOT/'game').parts and p.suffix not in ['.uid','.import']}
summary={'images':0,'failures':[],'source_files':source,'allowed_changed_files':sorted(allowed),'renderers':{}}
labels={'story-desktop-0':'潮水留下的线','story-desktop-1':'最后一枚种子','story-desktop-2':'给春天留的位置','story-next-focus':'键盘焦点','story-small-0':'小窗口 · 第一页','story-small-1':'小窗口 · 第二页','story-small-2':'小窗口 · 第三页','story-small-scrolled':'小窗口 · 滚动正文后','story-motion-02':'镜头推进 · 2秒','story-motion-12':'镜头推进 · 12秒','story-motion-30':'镜头推进 · 30秒','story-dissolve-000':'叠化 · 开始','story-dissolve-063':'叠化 · 中间','story-dissolve-125':'叠化 · 完成'}
if version=='1.8.2':labels.update({'robot-animation-idle':'芽芽 · 待机','robot-animation-rolling':'芽芽 · 履带滚动'})
expected_count=len(labels)
sections=[]
for method in ['forward_plus','gl_compatibility']:
    folder=BASE/method
    report=json.loads((folder/'story-render-audit.json').read_text())
    assert report['failures']==[] and report['renderer']==method,report
    assert len(report['captures'])==expected_count and {c['name'] for c in report['captures']}==set(labels)
    assert len(report['layouts'])==7
    if version=='1.8.2':assert report['robot_links']==52 and report['robot_belt_distance']>0
    log=(folder/'story_review-render.log').read_text();assert 'ERROR:' not in log and f'STORY_RENDER_AUDIT: {expected_count} frames; failures=[]' in log
    prior=json.loads((ROOT/'builds/v18-render-pixel-verification.json').read_text())[method]['source_files']
    assert set(prior)<=set(source),'baseline source removed'
    assert set(source)-set(prior)<=allowed,'unexpected new source'
    for relative,digest in source.items():
        captured=ROOT/'.tools/render-background'/LABEL/method/relative
        assert hashlib.sha256(captured.read_bytes()).hexdigest()==digest,(method,relative,'changed after capture')
        if relative not in allowed:assert digest==prior[relative],('uncaptured world change',relative)
    for layout in report['layouts']:
        b=layout['buttons'];left=b['StoryPrevious'];right=b['StoryNext'];skip=b['StorySkip']
        assert left['x']<right['x'] and abs(left['y']-right['y'])<1
        assert skip['y']<right['y'] and skip['x']>left['x']
        if layout['name'].startswith('story-desktop'):assert layout['scroll_max']<=layout['scroll_page']+1
    frames={};cards=[];pixels={}
    for c in report['captures']:
        name=c['name'];im=Image.open(folder/(name+'.png')).convert('RGB');expected=(640,480) if name.startswith('story-small') else (1280,800)
        assert im.size==expected,(method,name,im.size)
        rgb=np.asarray(im,dtype=np.float32);assert rgb.std()>8 and ((rgb.max(2)-rgb.min(2))>5).mean()>.05
        pixels[name]=rgb
        frames[name]={'size':im.size,'std':float(rgb.std()),'sha256':hashlib.sha256((folder/(name+'.png')).read_bytes()).hexdigest()}
        url='render-iterations/'+LABEL+'/'+method+'/'+name+'.png'
        cards.append(f'<figure><a href="{url}"><img src="{url}" alt="{labels[name]}" loading="lazy"></a><figcaption>{labels[name]} · {expected[0]}×{expected[1]}</figcaption></figure>')
    def change(a,b):return float(np.abs(pixels[a]-pixels[b])[:,640:].mean())
    motion=[change('story-motion-02','story-motion-12'),change('story-motion-12','story-motion-30')]
    assert all(0.4<x<35 for x in motion),('camera did not move gently',method,motion)
    transition=[change('story-dissolve-000','story-dissolve-063'),change('story-dissolve-063','story-dissolve-125')]
    assert all(x>5 for x in transition),('transition did not render',method,transition)
    a=pixels['story-dissolve-000'];b=pixels['story-dissolve-063'];c=pixels['story-dissolve-125']
    mid_error=float(np.abs(b-(a+c)*.5)[:,640:].mean());assert mid_error<8,(method,'dissolve flashed',mid_error)
    summary['images']+=len(frames);summary['renderers'][method]={'adapter':report['adapter'],'frames':frames,'layouts':report['layouts'],'camera_mean_pixel_changes':motion,'dissolve_mean_pixel_changes':transition,'dissolve_midpoint_error':mid_error}
    sections.append('<section><h2>'+('高画质 · Forward+' if method=='forward_plus' else '兼容画质 · OpenGL')+'</h2><div class="grid">'+''.join(cards)+'</div></section>')
(ROOT/('builds/'+prefix+'-story-verification.json')).write_text(json.dumps(summary,ensure_ascii=False,indent=2))
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 1.8.1 电影序章</title><style>body{margin:0;background:#071116;color:#ede5d6;font:16px/1.7 system-ui,sans-serif}main{max-width:1440px;margin:auto;padding:36px 24px}h1{font-size:30px}h2{color:#b99865;font-size:22px}p{max-width:1000px;color:#b7b09c}a{color:#c3a164}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}figure{margin:0}img{width:100%;display:block}figcaption{padding:8px 0;color:#b7b09c}@media(max-width:720px){.grid{grid-template-columns:1fr}}</style><main><h1>电影风格序章 · 1.8.1</h1><p>三幅生成画面铺满屏幕，Godot实时执行缓慢推进与1.25秒叠化。上一页在左下，下一页在右下，跳过在右上；静止画面可暂停镜头。文字保留水痕、叶影与旧花盆中的含蓄线索。</p><p>以下28张来自引擎虚拟显示的实际软件渲染。2/12/30秒镜头与叠化采样用于核对动画，未验证原生GPU帧率。它是电影风格静帧与镜头动画，尚非完整角色三维表演。</p><p><a href="visual-board.html">沿用的三章模型与光照（1.8.0）</a></p>'''+''.join(sections)+'</main></html>'
if version=='1.8.2':
    html=html.replace('1.8.1','1.8.2').replace('以下28张','以下32张').replace('三幅生成画面铺满屏幕','三幅生成画面铺满屏幕，加入独立BGM、三组环境声、翻页音效、浮尘、雾气与镜头呼吸光').replace('三章模型与光照（1.8.0）','三章模型与光照（1.8.0，芽芽履带改造另见本页新截图）')
    html=html.replace('<section>', '<p><audio controls preload="none" src="render-iterations/v182-audio/gl_compatibility/audio-mix-preview.wav"></audio><br>引擎实际混音采样：三页序章、标题、三章与翻页声；末尾为静音检查。</p><section>',1)
(ROOT/'builds/story-review.html').write_text(html)
print('CINEMATIC_PIXEL_CHECK_OK',summary['images'],'images; sources outside reviewed scope unchanged')
