"""Produce an honest local gallery of actual background engine captures."""
import html
import json
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--label',default='v17-final')
parser.add_argument('--version',default='1.7')
args=parser.parse_args()
base=ROOT/'builds/render-iterations'/args.label
names={'forward_plus':'高画质 / Forward+','gl_compatibility':'兼容画质 / OpenGL'}
labels={
    'render-03-mountain-ridges':'远山 · 连续山脊与岩层', 'render-04-harbour-shell':'港口 · 开窗残楼、钢桁架与水下岩基',
    'render-01-coastal-reflections':'晨光 · 临水建筑与海面反射','render-02-greenhouse-morning':'晨光 · 温室钢架、藤蔓与透光叶缘',
    'reference-01-tidal-palazzo':'临水泵站宫楼 · 低视角','reference-02-open-arcades':'实心拱券与实际开口','reference-03-yaya-seedling':'芽芽与掀盖育苗箱','reference-04-greenhouse-interior':'温室内部、垂藤与高株盆栽','reference-05-greenhouse-gallery':'温室玻璃格架与高层廊桥','reference-06-orangery':'回生花园拱廊与钢架顶棚',
    'detail-01-jetty':'木栈桥、支柱与下水梯','detail-02-roof-damage':'屋顶真破口、瓦片与木椽','detail-03-potting-bench':'风化陶盆与种植工作台','detail-04-fern-close':'锯齿蕨叶与盐蚀陶盆近景',
    'cg-01-town':'参考图重建 · 滨海坡地街区','cg-02-quay':'参考图重建 · 连续石码头','cg-03-city-wall':'街区灰泥、窗洞与木框','cg-04-wet-paving':'湿铺石与雨水洼','cg-05-greenhouse-floor':'温室地面、蕨类与爬藤','cg-06-terracotta':'厚沿陶盆、土壤与幼苗',

    'shore-01-soil-bank':'土层、碎石与倾斜岩岸','shore-02-tidal-water':'潮湿岸缘与浅水泡沫',
    'shore-03-meadow':'高低草丛与枯绿变化','shore-04-ripples':'近水细浪与反光',
    'ai-01-plaster-close':'生成灰泥 · 实际住宅近景','ai-02-concrete-close':'生成混凝土 · 实际步行地面','ai-03-leaf-close':'生成叶脉 · 曲面叶片近景',
    '01-pump-overview':'旧城泵站全景','02-pump-machinery':'泵房设备','03-pipe-controls':'水路接续板',
    '02b-tank-fasteners':'储水罐紧固件与接缝','08b-side-windows':'住宅侧窗与墙体开口',
    '04-pressure-gauge':'水压仪表','05-yaya':'芽芽外壳与履带',
    '07-trees-grass-rocks':'树冠、枝条与岩岸','07b-grass-and-flowers':'海岸草丛与花卉','08-tiles-balcony':'瓦顶、窗框与阳台',
    '09-sea':'海面与远景','10-ground-bridge':'地面接缝与旋转桥','10b-restored-water':'恢复供水',
    '11-monochrome':'复色 0%','12-half-colour':'复色 50%','13-full-colour':'复色 100%',
    '20-greenhouse-overview':'日光温室全景','21-greenhouse-glass':'钢架与残留玻璃',
    '22-fuse-controls':'保险模块与供电柜','23-lift-mirrors':'升降台与镜架','24-roof-vent':'屋顶与通风扇',
    '25-restored-greenhouse':'恢复日光','30-regrowth-overview':'回生花园全景',
    '31-planter-flora':'种植床与叶片','32-irrigation':'灌溉设施','33-seed-dome-tree':'树木与种子台',
    '34-wind-tower-controls':'风塔与根系机关','34b-containment':'保护罩结局','35-restored-garden':'再生结局',
    'ui-title':'开始菜单','ui-pause':'探索菜单','ui-pause-focus':'键盘焦点与主按钮','ui-help':'帮助与键位','ui-settings':'声音、画质与帧率',
    'ui-record':'设备维护记录','ui-letter':'旧城来信','ui-ending':'结局档案',
}
if args.version in ['1.9.0','1.9.1','1.10.0','1.10.1','1.10.2','1.11.0','1.12.0']:labels['ai-02-concrete-close']='码头铺石 · 实际步行地面'
if args.version in ['1.9.1','1.10.0','1.10.1','1.10.2','1.11.0','1.12.0']:labels['cg-06-terracotta']='种植工作台下部与地面蕨类'
for i in range(4):labels['06-house-'+str(i)]='住宅 '+str(i+1)
for i in range(3):
    labels['ui-story-'+str(i)]='全屏序章 '+str(i+1)
    labels['ui-story-small-'+str(i)]='小窗口序章 '+str(i+1)
for i,text in enumerate(['移动与观察','调查来信','水路操作','水压调整','伙伴协作'],1):
    labels['tutorial-%02d-'%i+['movement','letter','route','pressure','partner'][i-1]]='新手教学 · '+text
for task,title in {'water_route':'修复水路','pressure':'稳定水压','pump':'双人启动','power':'恢复温室电源','mirrors':'引导日光','roof':'同步开顶','planting':'安排植物','irrigation':'分配灌溉','life':'唤醒花园'}.items():
    for state,word in [('before','修复前'),('after','聚焦修复后')]:labels['repair-'+task+'-'+state]=title+' · '+word
labels['repair-water_route-play']='任务聚焦 · 实际1/12复色状态'
labels['model-01-roof-truss']='温室承重 · 工字钢、斜撑与节点连接板'
labels['model-02-orangery-bracing']='花园廊架 · 膝撑、柱脚与连续纵梁'
labels['render-05-nursery-canopy']='温室育苗 · 新增陶盆、叶片与晨光'
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>废墟里的种子 · 1.7渲染检查</title><style>body{margin:0;background:#202b24;color:#e6ddc8;font:17px/1.7 system-ui}main{max-width:1280px;margin:auto;padding:32px 24px}a{color:#c3a164}h1{font-size:34px}p{color:#c2b79d}nav{display:flex;gap:20px}section{margin-top:40px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,450px),1fr));gap:24px}figure{margin:0;border:1px solid #74654d;padding:12px}img{width:100%;height:auto}figcaption{font-size:16px;margin-bottom:8px}</style><main><h1>废墟里的种子 / 1.7</h1><p>以下为当前工程的Godot 4.5真实渲染截图。后台Docker/Xvfb虚拟显示，Mesa软件Vulkan/OpenGL；没有在macOS桌面打开游戏窗口。镜头与修复状态为受控视觉检查，解谜流程另有自动化测试。此检查不代表原生Metal驱动兼容性或GPU帧率。</p><nav>'''
page=page.replace('1.7',args.version)
reports=[]
for method,title in names.items():
    folder=base/method
    if not (folder/'model-render-audit.json').exists():continue
    report=json.loads((folder/'model-render-audit.json').read_text());reports.append(report)
    page+=f'<a href="#{method}">{title}</a>'
page+='</nav>'
for method,title in names.items():
    folder=base/method
    if not (folder/'model-render-audit.json').exists():continue
    report=json.loads((folder/'model-render-audit.json').read_text())
    page+=f'<section id="{method}"><h2>{title}</h2><p>{len(report["captures"])} 个截图；{len(report["renderables"])} 条初始/修复状态模型检查记录。<a href="render-iterations/{args.label}/{method}/model-render-audit.json">完整模型与材质清单</a></p><div class="grid">'
    shots=[]
    for entry in report['captures']:
        key=entry['name'];shots.append(folder/(key+'.png'))
        page+=f'<figure><figcaption>{html.escape(labels.get(key,key))}</figcaption><img loading="lazy" src="render-iterations/{args.label}/{method}/{key}.png" alt="{html.escape(labels.get(key,key))}"></figure>'
    page+='</div></section>'
    columns=4;tile=(320,200);rows=(len(shots)+columns-1)//columns
    sheet=Image.new('RGB',(columns*tile[0],rows*(tile[1]+26)), '#202b24');draw=ImageDraw.Draw(sheet)
    for i,path in enumerate(shots):
        picture=Image.open(path).convert('RGB');picture.thumbnail(tile)
        x=(i%columns)*tile[0];y=(i//columns)*(tile[1]+26)
        sheet.paste(picture,(x,y));draw.text((x+6,y+tile[1]+4),path.stem,fill='#e6ddc8')
    sheet.save(folder/'contact-sheet.jpg',quality=90)
(ROOT/'builds/visual-board.html').write_text(page+'</main></html>')
print('REVIEW_BOARD_OK',sum(len(r['captures']) for r in reports),'frames')
