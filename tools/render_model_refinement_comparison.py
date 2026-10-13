"""Compare frozen native renders, including nine real repair operations."""
from pathlib import Path
import html,json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
tasks={'water_route':'修复水路','pressure':'稳定水压','pump':'双人启动','power':'恢复温室电源','mirrors':'引导日光','roof':'同步开顶','planting':'安排植物','irrigation':'分配灌溉','life':'唤醒花园'}
rows=[('reference-01-tidal-palazzo','泵站拱脚与分块檐口'),('21-greenhouse-glass','温室桁架与玻璃'),('render-05-nursery-canopy','育苗叶片与透光层次'),('reference-06-orangery','花园廊架与承重结构')]
for method in ['forward_plus','gl_compatibility']:
    old=json.loads((OUT/'render-iterations/v111-final'/method/'model-render-audit.json').read_text())
    new=json.loads((OUT/'render-iterations/v112-final'/method/'model-render-audit.json').read_text())
    assert not old['failures'] and not new['failures'] and len(new['captures'])==100
    old={r['name']:r for r in old['captures']};new={r['name']:r for r in new['captures']}
    for a,b in [(name,name) for name,_ in rows]:
        assert all(old[a][k]==new[b][k] for k in ['eye','target','width','height'])
    for task in tasks:
        before,after=[new['repair-'+task+'-'+state] for state in ['before','after']]
        assert all(before[k]==after[k] for k in ['eye','target','width','height'])
style='''body{margin:0;background:#14211e;color:#ece6d7;font:17px/1.65 system-ui}main{max-width:1280px;margin:auto;padding:40px 24px}h1{font-size:38px;line-height:1.25}h2{font-size:26px}p{color:#b7c4b9}a{color:#e5c28b}select{padding:10px;background:#26372f;color:#ede5d4;font:inherit;border:1px solid #789080}section{margin:38px 0}figure{margin:0}img{display:block;width:100%;height:auto}.pair{position:relative;aspect-ratio:8/5;background:#070c0e;overflow:hidden}.pair img{position:absolute;inset:0}.new{clip-path:inset(0 0 0 50%)}.line{position:absolute;top:0;bottom:0;left:50%;width:2px;background:#ead6a0}.tag{position:absolute;top:12px;padding:4px 12px;background:#14211ee0}.left{left:12px}.right{right:12px}input{width:100%;accent-color:#e5c28b}.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}figcaption{padding:8px 0;color:#b7c4b9}.selectors{display:flex;gap:24px;flex-wrap:wrap}@media(max-width:700px){.grid{grid-template-columns:1fr}h1{font-size:30px}}'''
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 1.12.0建模与整体渲染</title><style>{style}</style><main><h1>建模与整体渲染 / 1.12.0</h1><p>这轮补齐三章承重与石材细节，继续保留W-01正面操作、九项任务聚焦和原存档。温室新增工字钢桁架、连接板、螺栓和排水管；花园补上廊架膝撑、柱脚、纵梁与分块花床石沿。叶片加入卷曲和朝向变化，玻璃减轻污迹遮挡。</p><div class="selectors"><label>渲染模式 <select id="mode"><option value="forward_plus">高画质 / Forward+</option><option value="gl_compatibility">兼容画质 / OpenGL</option></select></label><label>修复任务 <select id="task">'''
for task,title in tasks.items():page+=f'<option value="{task}">{html.escape(title)}</option>'
page+='''</select></label></div><section><h2>温室屋架 · 实际三维结构</h2><img data-hero="model-01-roof-truss" alt="工字钢屋架、腹杆和连接板"><p>八榀桁架补齐承重关系，节点连接板与六角螺栓采用真实模型；既有升降与开顶路径继续使用。</p></section><section><h2>花园廊架 · 柱脚与双向膝撑</h2><img data-hero="model-02-orangery-bracing" alt="花园石拱上方的钢架与柱脚"></section><section><h2 id="repair-title">修复水路 · 同镜头变化</h2><div class="pair repair"><img class="old" alt="修复前实景"><img class="new" alt="修复后聚焦实景"><div class="line"></div><span class="tag left">修复前</span><span class="tag right">修复后 · 实际聚焦镜头</span></div><input aria-label="任务修复前后分界线" type="range" min="0" max="100" value="50"><p>拖动分界线检查变化；任务操作通过原解谜逻辑触发，修复前后相机和复色状态相同。游戏中的植物与水位在镜头停留时逐步变化。</p></section><section><h2>实际早期复色状态</h2><img data-hero="repair-water_route-play" alt="只完成第一项水路任务时的实际画面"><p>第一项任务仅恢复1/12颜色；水流和照明的变化仍可见，结果面板保持清晰。</p></section><section><h2>育苗区叶片与玻璃透光</h2><img data-hero="render-05-nursery-canopy" alt="陶盆、叶片与玻璃晨光"></section>'''
for name,title in rows:
    page+=f'''<section><h2>{title}</h2><div class="pair static" data-shot="{name}"><img class="old" alt="1.11.0实景"><img class="new" alt="1.12.0实景"><div class="line"></div><span class="tag left">1.11.0</span><span class="tag right">1.12.0</span></div><input aria-label="{title}版本分界线" type="range" min="0" max="100" value="50"></section>'''
page+='''<section><h2>继续朝开场画面靠近</h2><div class="grid"><figure><img src="guided-render-references/spring.png" alt="原始温室开场CG"><figcaption>原始开场CG</figcaption></figure><figure><img data-hero="render-05-nursery-canopy" alt="当前三维育苗区"><figcaption>当前Godot实景 · 取景与空间比例有差异</figcaption></figure></div><p>新结构与材质已接入可玩场景，W-01内向操作、任务聚焦与原存档继续保留。功能平台仍较大，构图、植物形态和摄影细节与原CG仍有明显差距。</p></section><p>849项功能检查，200张完整实景。后台Godot 4.5 / Docker / Xvfb / Mesa软件Vulkan与OpenGL渲染；不能据此承诺原生Metal驱动表现或GPU帧率。<a href="visual-board.html">完整实景画廊</a> · <a href="v112-test-summary.json">功能检查</a></p></main><script>'''
page+='const tasks='+json.dumps(tasks,ensure_ascii=False)+';\n'
page+='''const mode=document.querySelector('#mode'),task=document.querySelector('#task');
function refresh(){const base='render-iterations/v112-final/'+mode.value+'/';const repair=document.querySelector('.repair');repair.querySelector('.old').src=base+'repair-'+task.value+'-before.png';repair.querySelector('.new').src=base+'repair-'+task.value+'-after.png';document.querySelector('#repair-title').textContent=tasks[task.value]+' · 同镜头变化';document.querySelectorAll('.static').forEach(p=>{p.querySelector('.old').src='render-iterations/v111-final/'+mode.value+'/'+p.dataset.shot+'.png';p.querySelector('.new').src=base+p.dataset.shot+'.png'});document.querySelectorAll('[data-hero]').forEach(i=>i.src=base+i.dataset.hero+'.png')}
document.querySelectorAll('input').forEach(i=>i.oninput=()=>{const p=i.previousElementSibling;p.querySelector('.new').style.clipPath='inset(0 0 0 '+i.value+'%)';p.querySelector('.line').style.left=i.value+'%'});mode.onchange=refresh;task.onchange=refresh;refresh();
</script></html>'''
(OUT/'render-comparison-1.12.0.html').write_text(page)
print('REPAIR_COMPARISON_OK')
