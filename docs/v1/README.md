# 《废墟里的种子》 Seed in the Ruins

**A Gift for the Abandoned World — 留给废弃旧世界的一颗种子。**

这是根据「送礼思路建议」讨论实际实现的第一版 Godot 3D 叙事探索 Demo。玩家穿过 EDEN-04，恢复水路、重新分配有限能源、重建互补的植物群落，收集城市记忆，最后选择重启 EDEN 或释放再生计划。

## 直接试玩

macOS：双击本目录的 `启动游戏.command`。也可以直接打开 `builds/SeedInTheRuins.app`。

Windows：解压 `builds/SeedInTheRuins-Windows.zip`，运行 `SeedInTheRuins.exe`。Windows 包已交叉导出，尚未在 Windows 真机验证。

macOS 包为本机 ad-hoc 签名，没有 Apple 公证。外部电脑下载后可能需要通过系统的“隐私与安全性 → 仍要打开”允许启动。工程也可由 Godot 4.5 导入 `game/project.godot` 并按 F6/F5 运行。

| 操作 | 按键 |
| --- | --- |
| 移动 / 快走 | WASD / Shift |
| 观察 | 鼠标 |
| 读取物件与控制台 | 对准物件，靠近至 4 米内，按 E |
| 记忆册 / 地图 | Tab / M |
| 暂停或关闭当前面板 | Esc |

入口在地图南边。先去中央种子舱；水循环区在西边、能源区在东边、生物温室在北边。三处修复加至少六段记忆后，南边的再生核心开放。没有死亡与时间惩罚；两种结局都可体验。

## 已有内容

- 可移动的第一人称 3D 庭院、碰撞、交互提示、中文终端、地图与暂停菜单。
- 水路顺序谜题、供电预算谜题、三物种功能互补谜题；错误反馈与替代解法。
- 十二段可收集的档案、离线记忆重构、根—芽—叶三阶段种子反馈。
- 水面、植物、广告和音频随行为变化；两个结局与再生生长动画。
- 自动存档、重新开始、继续探索、保存纪念卡 PNG、现场体验模式。
- 可选 FastAPI 本地 AI 层，三秒客户端超时；API 不可用时仍能完整通关。

场景采用代码生成的低多边形基础美术。当前是完整玩法原型，不是最终精修美术版本。没有接入 Tripo / World Labs，也没有把离线预设文本标成实时 AI 输出。暂无配音、复杂 NPC 或联网世界生成。

## 交付材料

- `docs/GDD.md`：可执行策划与实现对照。
- `docs/参赛介绍.md`：可粘贴的中英文作品介绍。
- `docs/DEMO_SCRIPT.md`：五分钟现场讲解和谜题演示路线。
- `docs/TECHNICAL_DESIGN.md`：软件、代码、存档、AI 与导出方法。
- `docs/VERIFICATION.md`：实际测试与未验证项。
- `builds/walkthrough.mp4`：未剪辑的自动化游戏内游览录屏，约83秒；真实运行游戏逻辑，非人工试玩证据。
- `builds/visual-board.html`：包含真实游戏截图的视觉素材板。
- `builds/SeedInTheRuins-Submission.zip`：桌面包、录屏、素材板、文档和源代码。

比赛官网要求 Demo、游览录屏和视觉素材板，详情及截止时间见 `docs/参赛核对.md`。本地打包不代表已报名、已提交或已通过资格审核。

## 可选 AI 服务

无需 AI 服务也能玩。需要使用时，在本目录运行：

```sh
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt
cd backend
.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8787
```

未配置密钥时 API 返回 `source=fallback`。配置时在后端进程环境中设置 `LLM_API_BASE`（含 `/v1`）、`LLM_API_KEY`、`LLM_MODEL`；客户端不包含凭据。联网提供商未用真实密钥验证，协议处理与失败回退已通过模拟测试。

## 开发与验证

固定 Godot 4.5 stable，使用 Compatibility 渲染器。实际开发的引擎位于 `.tools/Godot.app`，不进入源代码包。

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path game res://tests/flow.tscn -- --test
(cd backend && .venv/bin/python -m unittest -v test_service)
.tools/Godot.app/Contents/MacOS/Godot --headless --path game --export-release macOS ../builds/SeedInTheRuins-macOS.zip
.tools/Godot.app/Contents/MacOS/Godot --headless --path game --export-release 'Windows Desktop' ../builds/windows/SeedInTheRuins.exe
```

先在 Godot 的导出模板管理器安装同版本模板。正常存档在 Godot `user://journey.json`；测试使用独立的 `verification.json`，不改玩家进度。纪念卡默认保存到系统文档目录的 `SeedInTheRuins` 文件夹。
