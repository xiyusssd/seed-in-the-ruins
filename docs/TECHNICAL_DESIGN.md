# 1.0 技术设计

Godot 4.5；离线桌面游戏入口game/garden.tscn，主控garden.gd。保留原有三章路径图、连续第一人称控制、实际阶梯与桥梁。

## 状态与交互

Puzzles自动加载负责九个谜题的操作、档位、库存交换、完成判定、重置及三级提示。updated通知场景、UI与Journey同步；solved通知音效与机器人庆祝。只有实际合法解法授予成果来信，章节UI根据三项成果开放。Journey保存v4独立文件，含Puzzles.snapshot、玩家姿态、颜色和结局。Settings负责独立画质/音量设置与渲染器重启。

玩家准星射线查询实体交互体，并验证2.65米距离；外观模型与交互体避免相互遮挡。旧观景walk路线动画仅用于自动化验证/录像，不由普通交互触发。桥梁轮柄要求玩家在中央操作区域，升降台要求实际站在对应层的平台。

PuzzleWorld创建可读维护记录、可转动接头、压力仪表、模块架/槽、镜架/分段光束、实际种植植物、分水器、根系与风塔。装饰不参与玩家碰撞，仍有原建筑与平台碰撞。

## 芽芽

独立可编辑characters/yaya.tscn与robot_companion.gd。机器人无玩家阻挡碰撞，沿当前开放图路径运动；等待任务静止，协作实际到位后持续保持。储能任务先到landing取件，再到summit接入，阶段与位置入存档。跟随远离或卡住恢复仅在玩家视野外执行，远距离运输不会被跟随距离限制撤销。

## 图像与声音

Forward+高画质与Compatibility兼容画质分别运行；前者使用SSAO、ACES、轻辉光和局部反射探针，后者保留基础灯光、阴影与原创shader。天空处理不同线性色彩管线；全局CanvasLayer20复色覆盖世界和UI。没有启用实时GI、SSR或体积雾。基准为各章33秒正常时钟渲染，前3秒热身、后30秒采样，60帧上限，非电影模式；报告实际帧时间百分位与设备。

Soundscape负责三章各两层原创立体声循环音乐、按解谜与复色混合，以及空间化环境和机械声。Music/Effects/Ambience三个总线，独立音量；短声冷却与14个并发上限，菜单暂停。资源由make_puzzle_audio.py生成，旧线索、成长、脚步声保留。

## 验证与软件

fps_flow保留55项相机、连续桥/阶梯行走、存档和复色回归检查；puzzle_flow使用puzzle_playthrough执行实际距离/射线/E与C面板交互、伙伴行走、九谜题与两结局，另检查库存可逆、坏库存归一、提示、重置和v4恢复。录像沿正常时长的脚本路线并执行同样交互，不写入已解谜状态。截图与性能使用受控状态，与通关证据分开。

桌面交叉导出后验证Mac原生启动、签名和DMG；Windows仅交叉导出，实机状态如实记录。比赛ZIP包含源码、依赖许可、视频、截图和验证日志，以SHA256索引。不上传或发布。

## 1.1视觉层

保留谜题状态、存档及交互距离；新增garden_shapes.rounded_box/rounded_detail用于平滑圆角与不参与碰撞的检修细节，网格按尺寸和半径缓存。robot_companion构建镜头、履带和关节；puzzle_world细化机柜和法兰；worn_enamel为兼容两种渲染器的原创搪瓷磨损材质。garden_ui使用三个字体变体与共享Theme，区分纸页故事面板和机械操作面板，复色仍覆盖整个画面。

捕获与性能模式主动聚焦原生窗口，性能日志额外记录Engine.get_frames_drawn和采样比例，以区别逻辑帧与实际绘制。参考[Godot Window](https://docs.godotengine.org/en/4.5/classes/class_window.html)与[Godot Engine帧计数](https://docs.godotengine.org/en/4.5/classes/class_engine.html)。
