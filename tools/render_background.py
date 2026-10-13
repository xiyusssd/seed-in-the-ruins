"""Render the actual Godot scenes inside Docker/Xvfb without macOS windows.

The render uses Mesa software Vulkan (Forward+) or OpenGL (Compatibility).
It validates imagery, not native GPU speed or Metal-specific driver behavior.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import shlex

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--method', choices=['forward_plus', 'gl_compatibility'], default='forward_plus')
parser.add_argument('--label', default='v17-final')
parser.add_argument('--scene', default='res://tests/render_review.tscn')
parser.add_argument('--source-project', type=Path, default=ROOT/'game')
parser.add_argument('--baseline-w01', action='store_true')
parser.add_argument('--timeout', type=int, default=3600)
args = parser.parse_args()
project = ROOT / '.tools' / 'render-background' / args.label / args.method
output = ROOT / 'builds' / 'render-iterations' / args.label / args.method
project.mkdir(parents=True, exist_ok=True)
output.mkdir(parents=True, exist_ok=True)
# Use an isolated import cache and save directory; never share .godot across OSes.
shutil.copytree(args.source_project, project, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('.godot'))
command = ['docker', 'run', '--rm', '--name', 'seed-render-'+args.label+'-'+args.method,
           '--cpus', '4', '--memory', '7g',
           '-e', 'LP_NUM_THREADS=4', '-v', str(project)+':/project', '-v', str(output)+':/review',
           'seed-render-review:4.5', '/bin/sh', '-c',
           '/opt/godot --headless --editor --import --quit --path /project > /review/import.log 2>&1 && '
           'xvfb-run -a -s "-screen 0 1280x800x24" /opt/godot --path /project '
           '--display-driver x11 --audio-driver Dummy --rendering-method '+args.method+
           ' '+shlex.quote(args.scene)+' -- --offscreen-capture'+(' --w01-baseline' if args.baseline_w01 else '')]
log_name = 'render.log' if args.scene=='res://tests/render_review.tscn' else Path(args.scene).stem+'-render.log'
with (output/log_name).open('w') as log:
    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=args.timeout)
print('BACKGROUND_RENDER_OK', output)
