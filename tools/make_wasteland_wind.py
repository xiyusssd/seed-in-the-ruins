"""Original periodic coloured-noise wind, without recordings or external samples."""
from array import array
from pathlib import Path
import json,math,random,wave
RATE=22050;DURATION=20;COUNT=RATE*DURATION
rng=random.Random(12002)
noise=array('f',(rng.uniform(-1,1) for _ in range(COUNT)))
# Warm the filters over one complete noise period so the next period joins smoothly.
def filtered(offset):
 low=mid=air=0.0;result=array('f')
 for cycle in range(2):
  for i in range(COUNT):
   raw=noise[(i+offset)%COUNT]
   low=.997*low+.003*raw;mid=.965*mid+.035*raw;air=.7*air+.3*raw
   if cycle==1:
    phase=math.tau*i/COUNT
    envelope=.70+.17*math.sin(phase*3)+.09*math.sin(phase*7+.4)
    result.append((low*.6+mid*.9+air*.15)*envelope)
 return result
left=filtered(0);right=filtered(1097)
scale=.27/max(max(abs(v) for v in left),max(abs(v) for v in right))
channels=array('h')
for l,r in zip(left,right):channels.extend([round(l*scale*32767),round(r*scale*32767)])
root=Path(__file__).resolve().parents[1];path=root/'game/audio/wasteland_wind.wav'
with wave.open(str(path),'wb') as f:
 f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(channels.tobytes())
peak=max(abs(v) for v in channels)
assert 0<peak<30000
report={'asset':'wasteland_wind.wav','origin':'Original periodic coloured noise with warmed low-pass filters; no external samples','duration_s':DURATION,'rate':RATE,'channels':2,'peak_pcm16':peak,'stereo_difference':any(channels[i]!=channels[i+1] for i in range(0,len(channels),2))}
assert report['stereo_difference']
(root/'builds/wasteland-audio-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
