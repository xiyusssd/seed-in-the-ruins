"""Create a local gallery from actual engine captures and mixer output."""
import hashlib
import html
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'builds'
TITLES = ['泵站拱券与砌筑接缝', '滨海旧城与晨光', '石材反光与水洼',
          '温室钢架与玻璃', '柱廊与近景植物', '排水细节与玻璃雨痕',
          '复色后的花园', '花床石沿与地面接触', '尚未复色的世界']
KEYS = {'route': '水路', 'pressure': '水压', 'power': '电源',
        'mirrors': '日光', 'beds': '种植', 'roots': '风塔'}


def main():
    report = {'version': '1.13.0', 'native_device': 'Apple M5; Metal 3.2 / OpenGL 4.1',
              'renderers': {}, 'matched_camera_pairs': [], 'failures': []}
    for name in ['realism-native-before', 'realism-native', 'realism-compatible',
                 'stele-native-before', 'stele-native', 'stele-compatible']:
        audit_name = 'realism-render-audit.json' if name.startswith('realism') else 'maintenance-render-audit.json'
        audit = json.loads((OUT / name / audit_name).read_text())
        assert not audit['failures'], name
        entries = []
        for capture in audit['captures']:
            path = OUT / name / (capture['name'] + '.png')
            picture = np.asarray(Image.open(path).convert('RGB'))
            assert picture.shape == (800, 1280, 3) and picture.std() > 12, path
            entry = dict(capture)
            entry.update({'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                          'mean_rgb': picture.mean(axis=(0, 1)).round(3).tolist(),
                          'fraction_saturated_white': float(np.all(picture > 250, axis=2).mean())})
            entries.append(entry)
        report['renderers'][name] = {'captures': entries, 'failures': []}
    previous = report['renderers']['realism-native-before']['captures']
    current = report['renderers']['realism-native']['captures']
    assert len(previous) == len(current) == 9
    comparisons = []
    for index, (old, new) in enumerate(zip(previous, current)):
        assert old['name'] == new['name'] and old['eye'] == new['eye'] and old['target'] == new['target']
        path = new['name'] + '.png'
        a = np.asarray(Image.open(OUT / 'realism-native-before' / path).convert('RGB'), dtype=float)
        b = np.asarray(Image.open(OUT / 'realism-native' / path).convert('RGB'), dtype=float)
        report['matched_camera_pairs'].append({'name': new['name'], 'mean_absolute_pixel_change': float(abs(a-b).mean())})
        comparisons.append(f'''<article><h3>{html.escape(TITLES[index])}</h3>
<div class="comparison" style="--split:50%"><img src="realism-native-before/{path}" alt="1.12.3实景"><img class="new" src="realism-native/{path}" alt="1.13.0实景"><span class="old-tag">1.12.3</span><span class="new-tag">1.13.0 · Metal</span></div>
<input type="range" aria-label="拖动比较{TITLES[index]}" min="0" max="100" value="50" oninput="this.previousElementSibling.style.setProperty('--split',this.value+'%')">
<a href="realism-native/{path}" target="_blank">查看新版原图</a></article>''')
    cards = []
    for key, title in KEYS.items():
        cards.append(f'''<article><h3>{title}残碑</h3><a class="stele-link" href="stele-native/{key}-world.png" target="_blank"><img class="stele" src="stele-native/{key}-world.png" data-key="{key}" alt="{title}磨损刻痕"></a><a class="document" href="stele-native/{key}-document.png" data-key="{key}" target="_blank">查看 E 展开的全文</a></article>''')
    compatible = ''.join(f'<a href="realism-compatible/{row["name"]}.png" target="_blank"><img loading="lazy" src="realism-compatible/{row["name"]}.png" alt="{TITLES[i]}"><span>{TITLES[i]}</span></a>' for i,row in enumerate(current))
    audio = json.loads((OUT / 'realism-audio/realism-audio-audit.json').read_text())
    assert audio['checks'] == 30 and not audio['failures']
    names = ['第一章环境', '石面脚步', '第二章环境', '金属脚步', '第三章环境',
             '花园脚步', '左侧声源', '右侧声源', '距离范围外', '父总线静音']
    offset = 0.0
    buttons = []
    for label, segment in zip(names, audio['segments']):
        buttons.append(f'<button onclick="const p=document.querySelector(\'audio\');p.currentTime={offset:.3f};p.play()">{label}</button>')
        offset += segment['seconds']
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>废墟里的种子 · 1.13.0 实景与声音</title><style>
:root{color-scheme:dark;font-family:system-ui,sans-serif;background:#1d211f;color:#e7e1d5}body{margin:0 auto;max-width:1440px;padding:36px 28px 70px}h1{font-size:clamp(25px,3vw,42px);font-weight:500}h2{font-size:24px;margin-top:60px;font-weight:500}h3{font-size:17px;font-weight:500}p{line-height:1.7;max-width:900px;color:#bcbeb2}a{color:#c7bb8d;text-underline-offset:4px}article{min-width:0}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:30px}img{display:block;width:100%;height:auto}.comparison{position:relative;aspect-ratio:8/5;overflow:hidden}.comparison img{position:absolute;inset:0}.comparison .new{clip-path:inset(0 0 0 var(--split))}.comparison span{position:absolute;top:12px;padding:5px 9px;background:#1b211fe0;font-size:12px}.old-tag{left:12px}.new-tag{right:12px}input[type=range]{width:100%;accent-color:#b8aa77;margin:12px 0}button{background:#343e36;color:#e8e0cd;border:1px solid #67705c;padding:9px 13px;cursor:pointer;font-size:14px}button[aria-pressed=true]{background:#756e4b}.modes,.segments{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}audio{width:min(800px,100%)}.compatible{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.compatible span{display:block;font-size:14px;margin:6px 0}small{color:#979e90}@media(max-width:700px){body{padding:24px 16px}.grid,.compatible{grid-template-columns:1fr}}
</style><h1>废墟里的种子 · 1.13.0</h1><p>风化残碑、随光线受光的磨损刻痕，以及建筑和空间声音。图片来自本机 Godot 4.5 实时场景；未用插画替代游戏画面。</p>
<h2>解谜提示留在残碑上</h2><p>六处提示撤下纸面和金属记录架。断角、裂缝、潮痕与缺损笔画融入石材；靠近按 E 仍可拓记全文。水压碑移到西侧，五行规则避开仪表管和楼梯遮挡。</p>
<div class="modes"><button aria-pressed="true" onclick="switchSteles('native',this)">Metal 高画质</button><button aria-pressed="false" onclick="switchSteles('compatible',this)">OpenGL 兼容画质</button><a href="stele-native-before/route-world.png" target="_blank">查看旧版纸面提示</a></div><div class="grid">''' + '\n'.join(cards) + '''</div>
<h2>原生高画质前后对照</h2><p>同一台 Apple M5、相同镜头位置和朝向。拖动滑块查看 1.12.3 与 1.13.0 的实际渲染。石材反光、玻璃雨滴、局部反射、日光和雾量已调整；新增错缝石块、排水连接、格栅与落叶。</p><div class="grid">''' + '\n'.join(comparisons) + '''</div>
<h2>引擎实际混音试听</h2><p>三章环境与脚步、左右方向、超出距离和静音片段。新增声音为项目原创合成，实际 3D 声源经过距离衰减、遮挡低通和区域混响。点击片段按钮可跳转试听。</p><audio controls preload="metadata" src="realism-audio/realism-audio-preview.wav"></audio><div class="segments">''' + ''.join(buttons) + '''</div>
<h2>兼容画质实景</h2><p>OpenGL 4.1 / Compatibility 的独立实渲结果。</p><div class="compatible">''' + compatible + '''</div>
<p><a href="realism-release-verification.json">发布核验</a> · <a href="v1130-test-summary.json">功能回归</a> · <a href="v113-visual-verification.json">图像及镜头校验</a> · <a href="realism-audio/realism-audio-audit.json">音频混音检查</a></p><small>材质凹槽采用深度梯度法线。遮挡与混响采用游戏中的近似空间声学。</small>
<script>function switchSteles(mode,button){document.querySelectorAll('.modes button').forEach(b=>b.setAttribute('aria-pressed',b===button?'true':'false'));document.querySelectorAll('.stele').forEach(im=>{im.src='stele-'+mode+'/'+im.dataset.key+'-world.png';im.parentElement.href=im.src});document.querySelectorAll('.document').forEach(a=>a.href='stele-'+mode+'/'+a.dataset.key+'-document.png')}</script></html>'''
    (OUT / 'realism-review-1.13.0.html').write_text(page)
    (OUT / 'v113-visual-verification.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print('REALISM_REVIEW_OK', sum(len(r['captures']) for r in report['renderers'].values()), 'verified images; 9 matched camera pairs')


if __name__ == '__main__':
    main()
