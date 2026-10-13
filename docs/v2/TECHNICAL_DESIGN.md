# 第二版工程与复现

Godot 4.5 stable，GDScript，Compatibility渲染器。第二版主场景为garden.tscn，原版main.tscn仅用于历史对照。

| 模块 | 职责 |
| --- | --- |
| garden.gd | 三庭场景、路径图、移动动画、机关、摄像机、碰撞拾取、声音和自动游览 |
| garden_shapes.gd | 原创拱门三角网格、石台、柱、桥、台阶、穹顶、植物、小园丁 |
| garden_ui.gd | 轻界面、十二短记忆、方向提示、旅程与结局卡 |
| journey.gd | 独立第二版存档、进度、植物与记忆去重、数据校验 |
| tests/garden_flow.gd | 实际空间路径、机关、点击回归、镜头射线、结局和存档验证 |

## 空间与路径

每一庭使用明确的3D锚点图。长桥水平转90度后改变连通边，升降台只有在对应高度时允许接近，三个植物功能齐全后才开放顶层阶梯。路径通过广度优先搜索计算，角色逐段在真实坐标间移动。

角色使用受控路径移动而非自由物理行走；这避免落水与平台跳跃。桥梁和台阶的空间位置是实在的，不使用投影重合传送。所有操作先将角色移动到安全操作点，尤其旋转第三庭的桥时，先返回枢纽，避免孤立翼端。

场景网格带有静态碰撞，用于相机射线遮挡。鼠标点击时重新检测当前位置，避免快速移动后读取旧的悬停对象。右键拖动或Q/E环绕透视镜头，滚轮改变相机距离。默认游玩镜头贴近并平滑跟随园丁，V切换到庭院总览；两个模式均为透视投影。远处遗迹、雾和水面波纹提供视差与距离线索。机关悬停文字为受深度遮挡的Label3D；HUD显示当前下一步，侧边菜单打开时隐藏HUD。

## 图形与声音

浅色石材、铜色轮柄、柔和穹顶与水面采用项目原创几何及简单材质。一个方向光、环境光和实时阴影，不使用实时GI。水闸、分离屋顶、升降台、植物和旧城容器均有实际模型状态变化。声音沿用本项目Python原创合成资产。

## 状态与保存

主存档为user://spatial-garden-v2.json，版本号2；字段包含庭院、角色路径节点、桥朝向、台高度、水闸、屋顶、植物、记忆与结局。读取时校验版本、范围、枚举与重复ID；节点不属于当前庭院时回到入口。

验证参数采用独立的garden-verification.json。测试场景进一步使用garden-suite.json，避免与正在运行的试玩或录屏写入冲突。第一版的journey.json不迁移、不覆盖。

## AI与引用

第二版不在游玩UI调用AI。第一版FastAPI源代码仍在仓库，供后续另行设计。全部短记忆为预设叙事，界面不声称实时生成。

《纪念碑谷》作为建筑解谜设计参考，引用来源见GDD和参赛介绍；没有复制素材、音效、角色和具体关卡。模型和关卡由本项目程序生成。

## 验证、导出与录像

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path game res://tests/garden_flow.tscn -- --garden-test
.tools/Godot.app/Contents/MacOS/Godot --path game --write-movie ../builds/garden-walkthrough.avi --fixed-fps 24 --disable-vsync -- --garden-film
.tools/Godot.app/Contents/MacOS/Godot --headless --path game --export-release macOS ../builds/SeedInTheRuins-macOS.zip
.tools/Godot.app/Contents/MacOS/Godot --headless --path game --export-release 'Windows Desktop' ../builds/windows/SeedInTheRuins.exe
```

录屏运行实际关卡与移动、机关逻辑，使用自动化操作，未剪辑。电影模式固定帧率不代表实际运行性能；镜头可旋转的性能仍需不同硬件测量。转码需要imageio-ffmpeg；tools/convert_movie.py生成MP4。

## 下一步

优先首次玩家测试、视线遮挡调整、动作与水流细节。接入新的美术时保留对应锚点与机关尺寸，避免动画看似接通却实际图边不一致。
