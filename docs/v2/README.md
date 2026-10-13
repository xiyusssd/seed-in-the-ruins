# 废墟里的种子 · 空中庭院

**Seed in the Ruins / The Floating Gardens**

这是第二版：将第一人称设施原型重做为三个立体建筑关卡。灵感来自《纪念碑谷》的建筑构图、机关变化和克制叙事；采用原创关卡、园丁角色和生态主题。三维建筑、旋转桥、升降台与屋顶都有真实空间位置；使用透视镜头，可自由转动观察视角，连接只在实际桥梁对齐时成立。没有使用《纪念碑谷》的模型、角色、音乐或关卡。

## 试玩

macOS：在Finder双击 `启动游戏.command`，或打开 `builds/SeedInTheRuins.app`。

Windows：解压 `builds/SeedInTheRuins-Windows.zip` 后运行exe。此包已交叉导出，仍需要Windows实机验证。

| 操作 | 方法 |
| --- | --- |
| 行走 | 点击地面的圆环 |
| 改变建筑 | 点击铜色轮柄；角色会先走到安全操作位置 |
| 环绕观察 | 右键拖动，或按Q / E |
| 靠近 / 远离 | 鼠标滚轮 |
| 园丁跟随 / 庭院总览 | V 或右上角按钮 |
| 方向提示 / 记忆册 / 暂停 | H / Tab / Esc |

- **水之庭**：转桥连接断路，沿阶梯进入水源亭，打开水闸。
- **日光庭**：乘升降台到高处，转桥进入温室，打开屋顶，把光留给植物。
- **万物之庭**：转动中央桥，访问三座植物庭；收集花卉、豆科与深根树种，登上最后的种子塔。

两种结局分别保留旧城市的容器，或释放植物生长空间。通关后仍可留在庭院，阅读剩余记忆、再次选择结局，或保存纪念卡。

## 本版交付

- 默认透视跟随视角、可切换总览、三维物体旁的机关提示。
- 当前目标随机关进度更新；侧边菜单、操作帮助和城市记忆。
- 原创三维拱廊、石塔、阶梯、彩色穹顶、桥梁、水面和小园丁。
- 三座可完整游玩的空间关卡；机关动画与路径可达性同步。
- 十二处可选择阅读的短记忆，不设置阅读数量门槛。
- 自动存档、音频开关、两个结局、纪念卡PNG。
- 当前版本的macOS/Windows桌面包、自动化实际游戏录屏、视觉素材板、参赛介绍和源码。

主线完全离线。第二版侧重建筑与行动表达，未在UI中接入实时AI；第一版后端作为历史源代码保留，不把预设记忆称为AI生成。

## 材料

- `docs/GDD.md`：新关卡设计与实际规则。
- `docs/参赛介绍.md`：新版中英文作品简介。
- `docs/VERIFICATION.md`：当前验证证据与局限。
- `docs/DEMO_SCRIPT.md`：现场演示路线。
- `builds/garden-walkthrough.mp4`：引擎直接录制、未剪辑的自动化游戏游览。
- `builds/visual-board.html`：新关卡真实截图。
- `builds/SeedInTheRuins-Submission.zip`：所有当前参赛材料。

第一版的策划说明在 `docs/v1/`，第一版提交包在 `builds/v1/`。`game/main.tscn`仍可打开旧版，默认启动`game/garden.tscn`。

## 开发与验证

Godot 4.5 stable，GDScript，Compatibility渲染器。项目入口：`game/project.godot`。新代码：`garden.gd`（场景、路径、机关）、`garden_shapes.gd`（原创几何）、`garden_ui.gd`（界面）、`journey.gd`（独立v2存档）。

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path game res://tests/garden_flow.tscn -- --garden-test
.tools/Godot.app/Contents/MacOS/Godot --path game --write-movie ../builds/garden-walkthrough.avi --fixed-fps 24 --disable-vsync -- --garden-film
```

正常存档为Godot `user://spatial-garden-v2.json`，不替换旧版journey.json。验证与录屏使用garden-verification.json。纪念卡保存到系统文档目录的SeedInTheRuins文件夹。

macOS包为ad-hoc签名，未Apple公证；其他电脑可能需要通过系统“隐私与安全性”允许启动。当前仍是独立游戏Demo，需要继续做首次玩家测试、美术细节与平台适配。没有上传比赛平台。
