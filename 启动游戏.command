#!/bin/zsh
set -eu
cd "${0:A:h}"
if [[ -d builds/SeedInTheRuins-1.14.0.app ]]; then
  open -n builds/SeedInTheRuins-1.14.0.app
elif [[ -d builds/SeedInTheRuins-1.13.1.app ]]; then
  open -n builds/SeedInTheRuins-1.13.1.app
elif [[ -d builds/SeedInTheRuins-1.13.0.app ]]; then
  open -n builds/SeedInTheRuins-1.13.0.app
elif [[ -d builds/SeedInTheRuins-1.12.3.app ]]; then
  open -n builds/SeedInTheRuins-1.12.3.app
elif [[ -d builds/SeedInTheRuins-1.12.2.app ]]; then
  open -n builds/SeedInTheRuins-1.12.2.app
elif [[ -d builds/SeedInTheRuins-1.12.1.app ]]; then
  open -n builds/SeedInTheRuins-1.12.1.app
elif [[ -d builds/SeedInTheRuins-1.10.1.app ]]; then
  open -n builds/SeedInTheRuins-1.10.1.app
elif [[ -d builds/SeedInTheRuins-1.10.0.app ]]; then
  open -n builds/SeedInTheRuins-1.10.0.app
elif [[ -d builds/SeedInTheRuins-1.9.1.app ]]; then
  open -n builds/SeedInTheRuins-1.9.1.app
elif [[ -d builds/SeedInTheRuins-1.9.0.app ]]; then
  open -n builds/SeedInTheRuins-1.9.0.app
elif [[ -d builds/SeedInTheRuins-1.8.4.app ]]; then
  open -n builds/SeedInTheRuins-1.8.4.app
elif [[ -d builds/SeedInTheRuins-1.8.3.app ]]; then
  open -n builds/SeedInTheRuins-1.8.3.app
elif [[ -d builds/SeedInTheRuins-1.8.2.app ]]; then
  open -n builds/SeedInTheRuins-1.8.2.app
elif [[ -d builds/SeedInTheRuins-1.8.1.app ]]; then
  open -n builds/SeedInTheRuins-1.8.1.app
elif [[ -d builds/SeedInTheRuins-1.8.0.app ]]; then
  open -n builds/SeedInTheRuins-1.8.0.app
elif [[ -d builds/SeedInTheRuins-1.7.1.app ]]; then
  open -n builds/SeedInTheRuins-1.7.1.app
elif [[ -d builds/SeedInTheRuins-1.7.0.app ]]; then
  open -n builds/SeedInTheRuins-1.7.0.app
elif [[ -d builds/SeedInTheRuins-1.6.1.app ]]; then
  open -n builds/SeedInTheRuins-1.6.1.app
elif [[ -d builds/SeedInTheRuins.app ]]; then
  open -n builds/SeedInTheRuins.app
elif [[ -x .tools/Godot.app/Contents/MacOS/Godot ]]; then
  .tools/Godot.app/Contents/MacOS/Godot --path game
else
  echo '请安装 Godot 4.5 并导入 game/project.godot。'
  read -r
fi
