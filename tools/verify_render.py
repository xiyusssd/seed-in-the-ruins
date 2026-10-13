"""Check captured saturation progression and fully decode the current walkthrough."""
from pathlib import Path
import json, subprocess
import imageio_ffmpeg
root=Path(__file__).resolve().parents[1]
out=root/'builds'
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
report={}
for key in ['fps-blackwhite','fps-midcolour','fps-fullcolour']:
    rgb=subprocess.check_output([ffmpeg,'-v','error','-i',str(out/f'{key}.png'),'-f','rawvideo','-pix_fmt','rgb24','-'])
    pixels=len(rgb)//3
    spreads=[max(rgb[i:i+3])-min(rgb[i:i+3]) for i in range(0,len(rgb),3)]
    report[key]={'pixels':pixels,'max_channel_spread':max(spreads),'colour_pixel_fraction':sum(v>5 for v in spreads)/pixels}
assert report['fps-blackwhite']['max_channel_spread']<=1
assert report['fps-fullcolour']['colour_pixel_fraction']>report['fps-midcolour']['colour_pixel_fraction']>0.1
(out/'render-pixel-verification.json').write_text(json.dumps(report,indent=2))
subprocess.run([ffmpeg,'-v','error','-i',str(out/'garden-walkthrough.mp4'),'-f','null','-'],check=True)
(out/'fps-video-verification.log').write_text('VIDEO_AUDIO_FULL_DECODE_OK\n')
print(json.dumps(report,indent=2))
