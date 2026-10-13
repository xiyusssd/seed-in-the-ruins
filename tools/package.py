"""Build the local submission bundle; never upload or publish."""
import hashlib
import html
import json
import sys
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'builds'
shots=[('prologue-1','序章 · 旧城的光','原创全景插画与项目背景'),
       ('prologue-2','序章 · 最后一枚种子','芽芽与种子的来历'),
       ('prologue-3','序章 · 送给被遗忘的世界','项目的起点与旅程的意义'),
       ('scene-coastal-houses','沿海住宅','受控路线内视角 · 窗洞、瓦顶、阳台与排水管'),
       ('scene-open-sea','旧城之外的大海','受控全彩视角 · 长波、细波与海岸泡沫'),
       ('fps-blackwhite','失去颜色的废墟','第一人称开场 · 0条线索 · 世界色彩0%'),
       ('fps-midcolour','颜色正在回来','同视角渲染验证 · 6条线索 · 世界色彩50%'),
       ('fps-fullcolour','找回完整色彩','同视角渲染验证 · 12条线索 · 世界色彩100%'),
       ('chapter-water','第一章 · 水还记得路','旧水泵旁开始第一段旅程'),
       ('chapter-sun','第二章 · 给叶子一片天空','为一株植物找回阳光'),
       ('chapter-life','第三章 · 春天有许多种模样','给不同的生命留出位置'),
       ('scene-pump-station','旧泵站','受控全彩第一人称视角 · 储水罐、管道和滤池'),
       ('scene-greenhouse','废弃温室','受控全彩第一人称视角 · 钢架、残留玻璃和育苗槽'),
       ('scene-regrowth','回生花园','受控全彩第一人称视角 · 土壤、根系与树冠地标'),
       ('garden-title','进入旧世界','第一人称场景与线索故事入口'),
       ('garden-sun','日光庭','亲自乘升降台抵达高处'),
       ('garden-life','万物之庭','第一人称探索互补生命的庭院'),
       ('yaya-companion','维护机器人 · 芽芽','实际引擎角色截图 · 单镜头、双履带与机械臂'),
       ('puzzle-workbench','水路接续板','受控机关近景 · 管道出口方向与漏水反馈'),
       ('puzzle-pump-restored','水泵醒了','真实解谜流程完成 · 芽芽守住踏板'),
       ('puzzle-greenhouse-restored','把日光送回来','真实解谜流程完成 · 双镜与同步开顶'),
       ('puzzle-garden-restored','春天有了力量','真实解谜流程完成 · 种植、灌溉与储能运输'),
       ('ui-menu','居中菜单','Esc打开 · 继续、物品、记录、帮助与设置'),
       ('ui-controls','帮助与操作说明','开始菜单与暂停菜单均可访问 · 键位集中查阅'),
       ('ui-companion','伙伴指令','机械面板与清晰的操作层级'),
       ('ui-field-notes','旧城修复手册','废土维护终端与黑白可读的线索'),
       ('ui-hint','逐级提示','按需展开的手册页面'),
       ('ui-settings','声音与画面','独立音量与画质组件'),
       ('garden-card','未送达的春天','最后的选择与种子纪念卡')]

board='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 1.6第一轮历史预览</title><style>body{margin:0;background:#282d26;color:#e6ddc8;font:18px/1.7 system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:40px 24px}small{color:#bc9153;letter-spacing:.12em}h1{font-size:42px}figure{margin:40px 0;border-top:1px solid #776a50;padding-top:24px}img{width:100%;height:auto}figcaption{display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap}p{color:#b7b09c}a{color:#bc9153}video{width:100%}</style><main><small>RECOVERY LOG / VISUAL ARCHIVE</small><h1>废墟里的种子</h1><p>当前软件：1.6.1。下方画面为材质加强前的1.6第一轮预览；1.6.1按用户要求后台执行，未启动图形预览。<br>以下截图来自1.6 Godot 4.5原生Metal/Forward+渲染。0/50/100%图与场景近景为受控视觉展示；三张章节修复完成图为保留的1.5历史流程画面，不代表1.6.1。电影模式没有用于性能测量。</p>'''
for key,title,note in shots:
    board+=f'<figure><figcaption><h2>{html.escape(title)}</h2><p>{html.escape(note)}</p></figcaption><img src="{key}.png" alt="{html.escape(note)}"></figure>'
board+='<h2>1.1历史自动游览</h2><p>自动化第一人称镜头通过实际准星交互完成九个谜题、机器人协作与十二条线索；不是人工首次试玩，也不证明30–45分钟游玩时长。下方视频是1.1历史版本，不代表1.6画面；上方0/50/100%图为本次1.6受控复色渲染验证。</p><video controls preload="metadata" src="garden-walkthrough.mp4"></video><p>场景与声音为项目生成；字体遵循SIL OFL。工具及许可见附带文档。</p></main></html>'
(OUT/'visual-board.html').write_text(board)
if '--board-only' in sys.argv:
    sys.exit(0)
# Windows standalone package.
with zipfile.ZipFile(OUT/'SeedInTheRuins-Windows.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.write(OUT/'windows/SeedInTheRuins.exe','SeedInTheRuins.exe')
    z.write(ROOT/'README.md','README.md')
    z.write(ROOT/'docs/安装与操作.md','安装与操作.md')
    for name in ['GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','ASSET_LICENSES.md']:
        z.write(ROOT/'docs'/name,'licenses/'+name)
    z.write(ROOT/'game/assets/OFL.txt','licenses/OFL.txt')
    z.write(ROOT/'game/assets/OFL-NotoSerifSC.txt','licenses/OFL-NotoSerifSC.txt')
    z.write(ROOT/'game/assets/OFL-ZCOOL.txt','licenses/OFL-ZCOOL.txt')
    z.write(ROOT/'game/assets/OFL-ShareTechMono.txt','licenses/OFL-ShareTechMono.txt')

files={}
for name in ['SeedInTheRuins-macOS.zip','SeedInTheRuins-macOS.dmg','SeedInTheRuins-Windows.zip','garden-walkthrough.mp4','visual-board.html','render-comparison.html']:
    files[OUT/name]=name
for key,_,_ in shots:
    files[OUT/f'{key}.png']=f'{key}.png'
for folder in ['docs','game','backend','tools']:
    for path in (ROOT/folder).rglob('*'):
        if not path.is_file() or any(x in path.parts for x in ['.godot','.venv','__pycache__']):
            continue
        if path.suffix in ['.pyc','.import'] or path.name == '.env':
            continue
        files[path]='source/'+str(path.relative_to(ROOT))
files[ROOT/'README.md']='README.md'
for path in (OUT/'render-iterations').rglob('*'):
    if path.is_file(): files[path]=str(path.relative_to(OUT))
for name in ['performance-forward_plus.json','performance-gl_compatibility.json','wasteland-audio-verification.json']:
    files[OUT/name]='verification/'+name
for name in ['audio-1.0-verification.json']:
    files[OUT/name]='verification/history-v11/'+name
for path in (OUT/'v11').glob('performance-*.json'):
    files[path]='verification/history-v11/'+path.name
for name in ['performance-forward_plus.json','performance-gl_compatibility.json','performance-high.log']:
    files[OUT/'v14'/name]='verification/history-v14/'+name
for path in sorted((OUT/'cards-v2').glob('*.png'), key=lambda p:p.stat().st_mtime, reverse=True)[:1]:
    files[path]='sample-card/'+path.name
for name in ['fps-tests.log','software-mac-runtime.log','software-zip-roundtrip.log','software-installer.log','software-export-macos.log','software-export-windows.log','puzzle-tests.log','wasteland-tests.log','playability-tests.log','v15-runtime.log','menu-tests.log','polish-tests.log','fps-capture.log','fps-capture-compatible.log','puzzle-native-tests.log','render-pixel-verification.json','render-pixel-compatible.json']:
    files[OUT/name]='verification/'+name
for name in ['fps-mac-runtime.log','fps-movie.log','fps-video-verification.log','fps-audio-verification.log','performance-compatible.log','v1-high-runtime.log','puzzle-audio-generation.log']:
    files[OUT/name]='verification/history-v11/'+name
manifest={name:hashlib.sha256(path.read_bytes()).hexdigest() for path,name in files.items()}
(OUT/'SHA256.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
files[OUT/'SHA256.json']='SHA256.json'
with zipfile.ZipFile(OUT/'SeedInTheRuins-Submission.zip','w',zipfile.ZIP_DEFLATED) as z:
    for path,name in files.items():
        z.write(path,'SeedInTheRuins/'+name)
print(f'Packaged {len(files)} files; {(OUT/"SeedInTheRuins-Submission.zip").stat().st_size/1024/1024:.1f} MiB')
