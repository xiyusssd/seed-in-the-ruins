"""Archive a rendered pass and its source snapshot for comparison, not a standalone game build."""
from pathlib import Path
import json,shutil,sys,zipfile
root=Path(__file__).resolve().parents[1]
name,title=sys.argv[1:3]
out=root/'builds/render-iterations'/name
out.mkdir(parents=True,exist_ok=True)
for key in ['scene-pump-station','scene-greenhouse','scene-regrowth','fps-blackwhite','fps-midcolour','fps-fullcolour','chapter-water','chapter-sun','chapter-life','yaya-companion','puzzle-workbench','ui-companion','ui-field-notes','ui-hint','ui-settings','ui-menu','ui-controls','prologue-1','prologue-2','prologue-3','garden-title','scene-coastal-houses','scene-open-sea','garden-sun','garden-life','garden-card','puzzle-pump-restored','puzzle-greenhouse-restored','puzzle-garden-restored']:
 if 'compatible' in name and key.startswith('puzzle-') and key.endswith('-restored'): continue
 shutil.copyfile(root/'builds'/f'{key}.png',out/f'{key}.png')
shutil.copyfile(root/'builds'/('fps-capture-compatible.log' if 'compatible' in name else 'fps-capture.log'),out/'render.log')
with zipfile.ZipFile(out/'source-snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for folder in ['scripts','shaders','characters']:
  for path in (root/'game'/folder).rglob('*'):
   if path.is_file():z.write(path,str(path.relative_to(root/'game')))
 for asset in (root/'game/assets').glob('*.tres'):
  z.write(asset,'assets/'+asset.name)
 for filename in ['project.godot','export_presets.cfg']:
  z.write(root/'game'/filename,filename)
(out/'iteration.json').write_text(json.dumps({'iteration':name,'title':title,'capture':'Controlled first-person scenes and saturation states; 1.4 greenhouse viewpoint shifted inward to avoid a foreground post. Restored-puzzle frames come from actual interactions.','source':'Scripts, shaders and project configuration snapshot; use with the complete project assets.'},ensure_ascii=False,indent=2))
print('SAVED',name,title)
