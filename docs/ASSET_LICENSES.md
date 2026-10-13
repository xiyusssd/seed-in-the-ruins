# 素材许可与来源

| 素材 | 作者 / 来源 | 许可与用途 |
| --- | --- | --- |
| 场景网格、种子、植物、终端与界面 | 本项目GDScript程序生成 | 原创项目素材，用于游戏与录屏 |
| 十二段档案、重构与结局文字 | 基于用户创意，Codex辅助编写 | 项目原创叙事，不引用第三方小说 |
| 八种音频 | tools/make_audio.py，确定性噪声与正弦合成 | 原创，无外部采样 |
| Noto Sans SC | Google / Adobe Noto，[官方字体仓库](https://github.com/google/fonts/tree/main/ofl/notosanssc) | SIL Open Font License 1.1，完整许可位于game/assets/OFL.txt |
| Noto Serif SC | Google / Adobe Noto，[官方字体仓库](https://github.com/google/fonts/tree/main/ofl/notoserifsc) | SIL Open Font License 1.1，完整许可位于game/assets/OFL-NotoSerifSC.txt；1.1历史故事与标题字体 |
| ZCOOL QingKe HuangYou | 郑庆科 / 站酷，[官方字体仓库](https://github.com/google/fonts/tree/main/ofl/zcoolqingkehuangyou) | SIL OFL，完整许可位于game/assets/OFL-ZCOOL.txt；1.3中文标题与按钮 |
| Share Tech Mono | Carrois Type Design，[官方字体仓库](https://github.com/google/fonts/tree/main/ofl/sharetechmono) | SIL OFL，完整许可位于game/assets/OFL-ShareTechMono.txt；1.3终端读数，中文回退Noto Sans SC |
| Godot Engine 4.5 | [Godot官方版本](https://godotengine.org/download/archive/4.5-stable/) | MIT，运行时包含引擎与第三方组件；完整许可附docs/GODOT_LICENSE.txt |

1.5及更早版本未使用下载的3D模型或照片纹理。1.6.1起增加下表所列CC0素材；没有使用商业音乐、Tripo或World Labs生成资产。

演示截图和视频来自本工程1.1历史真实渲染，不代表1.2新建筑、字体或风场。录屏是自动化游览，不作为首次玩家的体验或成绩证据。

第二版的所有拱门、穹顶、旋转桥、植物和园丁均由garden_shapes.gd生成。参考《纪念碑谷》的建筑解谜方法，但未使用其素材或具体关卡。参考官方设计介绍：https://monumentvalleygame.squarespace.com/blog/2014/5/9/how-we-made-monument-valley-what-do-you-want-to-know-1 。

第三版ruins.wav、return.wav、clue.wav和更新的脚步/机关声音由tools/make_ruins_audio.py生成；无下载采样、商业音乐或第三方音频。世界恢复颜色使用项目原创全屏shader。

## 桌面软件图标

`game/assets/app-icon.svg` 为本项目原创拱门与幼苗矢量图标；PNG 为其导出版本。未使用第三方图标或品牌工具生成。

## 0.3.2 章节环境

`chapter_scenery.gd` 生成的泵站、储罐、管道、温室、种植床、根系、树冠和标牌均为本项目原创程序几何。未从参考游戏导入模型、纹理、声音或角色。

## 第4–7代渲染

ruins_sky.gdshader、ruins_water.gdshader、箱体倒角几何与飘尘动画均为本项目原创程序内容，未使用第三方纹理或参考游戏资产。

0.8.0新增的弯曲叶片网格、拱门法线与温室玻璃雨痕 shader 均为本项目原创程序资产。

1.0新增角色芽芽为原创Godot节点模型与关节动画；三章六层BGM、九份机械/环境音由tools/make_puzzle_audio.py原创合成，未使用外部采样。管道、模块、镜架光束、种植床和风塔均为原创程序模型。

1.1新增的圆角外壳、镜头环、履带片、关节、螺栓和管道法兰，以及磨损搪瓷shader，均为本项目原创程序几何与材质。字体可变字重使用Godot FontVariation资源，许可随软件包附带。

1.2新增工业门框、破损棚顶、废弃厂房、断墙钢筋、尘雾与破布均为项目原创程序模型；wasteland_surface、wind_dust、wind_cloth为原创shader。wasteland_wind.wav由tools/make_wasteland_wind.py生成20秒周期滤波噪声，没有外部采样。当前字体使用Noto Sans SC可变字重；Noto Serif SC资源留作1.1历史资产。

1.4新增检修架、夹具、水位管、湿润痕迹、中继接光圈与种植床灌溉反馈，均为项目原创程序模型；微表面法线与玻璃风化修改为原创shader。继续使用1.3四份OFL字体许可。

## 1.6.1 实景材质与自然环境

外部素材来自 [Poly Haven](https://polyhaven.com)，按 [CC0](https://polyhaven.com/license) 使用。游戏内不访问素材API；制作阶段素材检索使用了Poly Haven API（Powered by Poly Haven）。下载文件的URL、原始校验值记录在 `game/assets/scenery/SOURCES.json`。改编网格的减面统计位于 `OPTIMIZATION.json`。

| 素材 | 官方来源 | 本项目用途 |
| --- | --- | --- |
| Plastered Wall 04 | [原始素材](https://polyhaven.com/a/plastered_wall_04)，Rob Tuytel | 住宅墙面：1K颜色、OpenGL法线、粗糙度贴图 |
| Concrete Wall 007 | [原始素材](https://polyhaven.com/a/concrete_wall_007)，Dario Barresi / Rico Cilliers / Charlotte Baglioni | 废墟与混凝土的1K物理表面贴图 |
| Tree Small 02 | [原始素材](https://polyhaven.com/a/tree_small_02) | 树干、枝叶与对应1K贴图；网格减面，叶片增加原创风动shader |
| Coast Rocks 02 | [原始素材](https://polyhaven.com/a/coast_rocks_02) | 岩岸扫描模型与1K贴图；网格减面，叠在路线外的基础地形上 |
| Kloofendal 48d Partly Cloudy Pure Sky | [原始素材](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky) | 1K HDRI自然天空、环境光与反射 |

海岸住宅、窗洞、阳台、瓦片、机关、角色、插画序章和海浪shader仍为项目原创。Noto Serif SC曾用于1.6插画序章；1.7起序章也统一使用工业标题与Noto Sans SC正文。

## 1.7 废土界面与材质检查

新增三组同样来自Poly Haven、遵循CC0的1K颜色、OpenGL法线与粗糙度贴图。文件来源与校验值附在同一份 `SOURCES.json`，运行时离线加载。

| 素材 | 官方来源 | 本项目用途 |
| --- | --- | --- |
| Wood Planks Dirt | [原始素材](https://polyhaven.com/a/wood_planks_dirt) | 住宅门板与木窗框 |
| Brown Mud 02 | [原始素材](https://polyhaven.com/a/brown_mud_02) | 温室与回生花园种植土 |
| Rusty Metal Sheet | [原始素材](https://polyhaven.com/a/rusty_metal_sheet) | 废弃管道、棚顶、栏杆与设备 |

铆钉金属菜单边框、磨损按钮、档案纸样式和叶脉shader由项目程序绘制。字体继续遵循随包附带的四份OFL许可。后台图像检查通过Docker/Xvfb内的Godot 4.5真实渲染器完成，不启动或激活macOS游戏窗口；软件Vulkan/OpenGL画面与原生Metal驱动的表现可能存在差别，软件渲染耗时不作为原生游戏帧率。

## 1.8.1 开场画面

`game/assets/cinematics/tide.png`、`yaya.png`、`spring.png` 由 Codex 内置 image_gen 生成，作为本项目的电影风格背景使用；并非 Poly Haven 下载素材，未将其标记为 CC0。芽芽画面以本项目原生角色截图作设计参考。提示词、用途与生成方式见 `docs/1.8.1开场画面生成记录.md`。Godot 实时运行缓慢推进与叠化，画面不包含完整三维角色表演。

## 1.8.2 配乐、音效与动画

`tools/make_cinematic_audio.py` 原创合成六层章节配乐、序章配乐、三组序章环境声以及五种界面音效，共15份立体声WAV。使用阻尼泛音、滤波噪声与立体声反射模拟钢琴/柔和铺底及海潮、风、枝叶、翻页声；没有下载的音乐、录音采样或商业音轨。合成方式和资产指纹在 `builds/v182-audio-assets.json`。当前六层章节配乐替代1.0的16秒版本，长度51.2秒。

雾气、微尘、镜头呼吸光、渐显文字和芽芽履带/手臂动画是项目原创Godot代码。三幅生成CG背景仍沿用1.8.1，详见其生成记录；未将背景画面描述成完整三维角色影片。


### 1.8.3：AI生成场景材质

`game/assets/generated_materials/` 的七张PNG由内置 `image_gen.imagegen` 生成，保留原始生成文件，不属于Poly Haven CC0扫描素材。两组建筑/地面颜色、估计法线与估计粗糙度，以及一张叶片颜色纹理。完整提示词、参考图片路径与SHA-256见该目录的 `SOURCES.json` 和 `docs/1.8.3生成材质.md`。这些是生成的材质估计，未经物理测量，也不生成三维网格。原有CC0素材和来源清单保留。


### 1.9.0：生成图引导的三维重建

`game/assets/generated_city/` 的六张PNG由Codex内置 `image_gen.imagegen` 生成：盐蚀灰泥和旧码头石板的颜色、估计法线、估计粗糙度。保持原始输出，完整提示词、参考路径、源路径与SHA-256见该目录的 `SOURCES.json`。不将AI生成图标记为CC0扫描素材。坡地房屋、四面窗洞、台阶、连续码头、植物、厚沿陶盆及水洼shader均为项目原创程序模型/代码；继续沿用原有CG、配乐、字体、CC0扫描与对应许可。详见 `docs/1.9生成图引导的三维重建.md`。


### 1.9.1：风化陶盆材质与近景细化

`game/assets/generated_garden/` 的三张1254×1254陶盆PNG由Codex内置 `image_gen.imagegen` 生成，分别为颜色、估计OpenGL法线、估计粗糙度。原始图保留，项目文件为逐字节副本；完整提示词、引用图、源路径及SHA-256见 `SOURCES.json`。使用原生圆柱UV与三维空心陶盆模型，不标记为CC0扫描资产。锯齿蕨叶、藤蔓侧枝、种植工作台、码头木栈桥、屋顶破口、街巷与岸坡均为项目原创程序几何，木材、泥土与锈铁继续使用已有CC0材质。说明见 `docs/1.9.1近景植被与岸坡.md`。

### 1.10.0：开场场景与建筑重建

`reference_reconstruction.gd` 中的泵站宫楼、临水拱廊、钟楼与钟、山体、细分玻璃、承重拱券与钢架、阔叶植物、垂藤、白花、柏树及育苗箱均为项目原创程序几何。沿用此前已登记的CG、16张原始生成材质及CC0木材/泥土/锈铁/HDRI，没有新增外部模型或将参考图贴作场景背景。实际三维场景快照为Godot原生 `.tscn`，材质仍引用本项目的资源与各自原有许可。

## 1.10.1 晨光渲染

`coastal_morning.gdshader` 对既有 CC0 HDR 天空执行运行时光照分级；原始 HDR、生成材质和开场 CG 文件均未改写。湿石材使用原有铺石 PBR 三张贴图和原生雨膜高光；反射捕捉实时场景网格，叶脉高光、潮湿叶缘、海面微波及积水边缘由着色器计算。

## 1.13.0 残碑与空间声音

残碑网格、裂纹、风化材质、砌筑与排水细节均为原创程序资产，石材沿用项目既有混凝土纹理。碑文深度图由原文和附带 OFL 许可的 Noto Serif SC 字库绘制，再程序处理切削差异与侵蚀；字库、文本和生成校验值见 game/assets/inscriptions/manifest.json。14 份环境与脚步 WAV 由 tools/make_realism_audio.py 原创合成，没有下载录音或使用外部采样。来源与校验值见 builds/v113-audio-assets.json。
