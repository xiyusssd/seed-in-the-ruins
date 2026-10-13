# 工程与复现

## 运行栈

Godot 4.5 stable（876b29033），Compatibility/OpenGL 渲染。开发主机为Apple M5、macOS。Python 3.14用于工具与后端。字体、音频已随工程和桌面包提供；无外部模型或运行时下载。

| 文件 | 职责 |
| --- | --- |
| game/scripts/world.gd | 固定种子的场景生成、设施、交互射线、环境变化、音频、自动游览 |
| game/scripts/player.gd | CharacterBody3D移动、重力碰撞、鼠标视角、脚步 |
| game/scripts/interface.gd | 菜单、谜题、档案、记忆册、地图、结局、纪念卡、可选AI请求 |
| game/scripts/state.gd | 谜题判定、主线解锁、成长、收集、存档校验 |
| game/data/memories.json | 十二份剧情与对应离线重构文本 |
| game/tests/flow.gd | 整条主线、失败路径、替代解法、碰撞、结局和保存验证 |
| backend/main.py | 本地FastAPI服务、OpenAI兼容接口、输入校验与回退 |
| tools/make_audio.py | 确定性合成八种原创音效 |
| tools/package.py | 构造提交材料包与SHA256清单 |

## 状态与存档

修复状态、记忆ID、种子发现、谜题配置、结局、位置和游玩时长存到user://journey.json。每8秒、收集记忆、完成谜题、选择结局和主动退出时保存。非法版本、非JSON、未知记忆ID、超出地图的位置都有校验。视角方向目前不持久化，继续旅程默认面向北。

核心解锁条件为种子已发现、三项修复全部完成、记忆至少六份。条件在状态层计算；AI服务无法改变它。

在--test、--capture、--walkthrough、--smoke-test参数下使用verification.json；自动演示不会改正常存档。

## 音频与美术

场景采用BoxMesh/CylinderMesh/SphereMesh、简单材质、确定性城市轮廓。植物、水面与广告通过状态切换。渲染一个方向光，有限透明网格，无实时GI。

八种声音由Python合成。风与广告是分开的循环；关闭广告后风仍然存在，水路修复后加入水声。程序在退出前停止音频、等待混音释放资源。

地图板、任务文本和交互提示为原生Godot控件。Noto Sans SC字体以450字重变体使用，许可附在assets/OFL.txt。

## AI可选层

客户端固定请求127.0.0.1:8787，记忆IDs与结局状态由JSON发送。所有密钥仅由本地服务读取环境变量。服务无凭据时返回fallback；提供商错误、超时、超长返回同样回退。客户端3秒超时，提供商socket超时2秒；请求不阻塞游戏主线。

后端只应绑定localhost。接口接受固定枚举与ID列表，不接受玩家自由文本或任意网络地址。输出是补充性虚构叙事；如果选择联网提供商，仍需人工核对输出是否符合世界观。

已验证模拟成功响应、无凭据和网络失败；尚未进行真实提供商调用。AI输入不含账号或密钥，但联网时会将选定剧情档案发给配置的提供商。

## 导出与录屏

安装Godot 4.5对应导出模板。export_presets.cfg定义macOS与Windows x86_64；project.godot开启Apple Silicon所需的ETC2/ASTC导入选项。

游戏内未剪辑游览可以重建：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path game --write-movie ../builds/walkthrough.avi --fixed-fps 24 --disable-vsync -- --walkthrough
```

游览依次经过种子、水、能源、温室、核心和再生结局；它调用真实谜题方法并使用实际游戏状态。自动镜头不采用玩家碰撞移动，因此它不代替人工导航测试。AVI以H.264/AAC转码为MP4，保留全程和原始声音。

## 后续精修接口

先替换节点几何而保留碰撞与kind/id元数据。区域修复状态通过refresh_world集中响应。新增档案须同步12份ID范围与验证；当前约束明确固定，不增加通用内容管理框架。
