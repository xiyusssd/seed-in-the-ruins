"""Compare frozen 1.10.0/1.10.1 camera captures and the original opening art."""
from pathlib import Path
import html,json

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
rows=[('reference-01-tidal-palazzo','临水泵站'),('cg-04-wet-paving','湿石码头'),
      ('detail-03-potting-bench','陶盆、蕨叶与爬藤'),('20-greenhouse-overview','日光温室'),
      ('30-regrowth-overview','回生花园')]
for method in ['forward_plus','gl_compatibility']:
    for version in ['v110-final','v1101-final']:
        report=json.loads((OUT/'render-iterations'/version/method/'model-render-audit.json').read_text())
        assert not report['failures']
    old={r['name']:r for r in json.loads((OUT/'render-iterations/v110-final'/method/'model-render-audit.json').read_text())['captures']}
    new={r['name']:r for r in json.loads((OUT/'render-iterations/v1101-final'/method/'model-render-audit.json').read_text())['captures']}
    for name,_ in rows:
        assert all(old[name][k]==new[name][k] for k in ['eye','target','width','height']),name
style='''body{margin:0;background:#172227;color:#e0e6dc;font:17px/1.65 system-ui}main{max-width:1280px;margin:auto;padding:40px 24px}h1{font-size:38px;line-height:1.2}h2{font-size:26px}p{color:#afbebc}a{color:#e5c28b}select{padding:10px;background:#24353c;color:#e0e6dc;font:inherit;border:1px solid #79938d}section{margin:40px 0}figure{margin:0}img{display:block;width:100%;height:auto}.pair{position:relative;aspect-ratio:8/5;background:#070c0e;overflow:hidden}.pair img{position:absolute;inset:0}.new{clip-path:inset(0 0 0 50%)}.line{position:absolute;top:0;bottom:0;left:50%;width:2px;background:#ead6a0}.tag{position:absolute;top:12px;padding:4px 12px;background:#172227db}.left{left:12px}.right{right:12px}input{width:100%;accent-color:#e5c28b}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}figcaption{padding:8px 0;color:#afbebc}@media(max-width:700px){.grid{grid-template-columns:1fr}h1{font-size:30px}}'''
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 1.10.1晨光渲染</title><style>{style}</style><main><h1>建模后的晨光与湿地 / 1.10.1</h1><p>保留三章建筑与可走路线，继续调整阴云天空、侧后方晨光、远景薄雾、湿石材雨膜和叶片透光。海面通过原生立方体反射捕捉真实建筑，反射仍是近似，尚未达到开场CG的摄影细节。</p><p>下方滑块保持相同相机、画幅和全彩状态。水纹和风随时间运动。正常游戏从黑白开始。</p><label>渲染模式 <select id="mode"><option value="forward_plus">高画质 / Forward+</option><option value="gl_compatibility">兼容画质 / OpenGL</option></select></label>'''
for name,title in rows:
    page+=f'''<section><h2>{html.escape(title)}</h2><div class="pair" data-shot="{name}"><img class="old" alt="1.10.0"><img class="new" alt="1.10.1"><div class="line"></div><span class="tag left">1.10.0 · 建模后</span><span class="tag right">1.10.1 · 渲染后</span></div><input aria-label="{title}对照分界线" type="range" min="0" max="100" value="50"></section>'''
page+='''<section><h2>新增实景镜头</h2><div class="grid"><figure><img data-hero="render-01-coastal-reflections" alt="低视角海面与临水建筑"><figcaption>海面与临水建筑</figcaption></figure><figure><img data-hero="render-02-greenhouse-morning" alt="温室晨光"><figcaption>温室钢架、藤蔓与透光叶缘</figcaption></figure></div></section><section><h2>开场图与当前三维场景</h2><div class="grid">'''
for art,shot,title in [('tide','render-01-coastal-reflections','旧城海岸'),('spring','render-02-greenhouse-morning','温室晨光'),('yaya','reference-03-yaya-seedling','芽芽与育苗箱')]:
    page+=f'<figure><img src="guided-render-references/{art}.png" loading="lazy" alt="原始开场图"><figcaption>{title} · 原始CG</figcaption></figure><figure><img data-hero="{shot}" loading="lazy" alt="实际三维场景"><figcaption>{title} · Godot实景，取景和空间比例有差异</figcaption></figure>'
page+='''</div></section><p>全部实景来自当前Godot 4.5工程，后台Docker/Xvfb与Mesa软件Vulkan/OpenGL渲染；不能据此承诺原生Metal驱动表现或GPU帧率。152张完整检查图、三维网格和玩法记录分别可见<a href="visual-board.html">完整画廊</a>、models/1.10.1及v1101验证文件。</p></main><script>
const mode=document.querySelector('#mode');
function refresh(){document.querySelectorAll('.pair').forEach(p=>{p.querySelector('.old').src='render-iterations/v110-final/'+mode.value+'/'+p.dataset.shot+'.png';p.querySelector('.new').src='render-iterations/v1101-final/'+mode.value+'/'+p.dataset.shot+'.png'});document.querySelectorAll('[data-hero]').forEach(i=>i.src='render-iterations/v1101-final/'+mode.value+'/'+i.dataset.hero+'.png')}
document.querySelectorAll('input').forEach(i=>i.oninput=()=>{const p=i.previousElementSibling;p.querySelector('.new').style.clipPath='inset(0 0 0 '+i.value+'%)';p.querySelector('.line').style.left=i.value+'%'});mode.onchange=refresh;refresh();
</script></html>'''
(OUT/'render-comparison-1.10.1.html').write_text(page)
print('MORNING_COMPARISON_OK')
