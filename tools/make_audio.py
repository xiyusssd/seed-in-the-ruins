"""Original procedural ambience, no sampled or third-party audio."""
import math, random, struct, wave
from pathlib import Path
OUT = Path(__file__).resolve().parents[1] / 'game' / 'audio'
OUT.mkdir(exist_ok=True)
RATE = 22050
random.seed(404)
for name, duration in [('wind',8),('advert',8),('life',8),('water',8),('step',.12),('interact',.2),('error',.25),('grow',2.5)]:
    values=[]
    smooth=0
    for i in range(int(RATE*duration)):
        t=i/RATE
        smooth=.97*smooth+.03*random.uniform(-1,1)
        if name=='wind': value=smooth*2 + .035*math.sin(t*2*math.pi*70)
        elif name=='water': value=smooth*.9 + random.uniform(-.12,.12)*(1+math.sin(t*8))
        elif name=='advert': value=.12*math.sin(2*math.pi*110*t)+.07*math.sin(2*math.pi*220*t)*max(0, math.sin(t*3))
        elif name=='life': value=sum(.06*math.sin(2*math.pi*f*t) for f in [174.61,220,261.63])*(.6+.4*math.sin(t*.5))
        elif name=='step': value=random.uniform(-1,1)*math.exp(-t*40)*.4
        elif name=='error': value=.25*math.sin(t*2*math.pi*140)*math.exp(-t*8)
        elif name=='interact': value=.3*math.sin(t*2*math.pi*660)*math.exp(-t*18)
        else: value=sum(.13*math.sin(t*2*math.pi*f) for f in [261.63,329.63,392,523.25])*math.sin(math.pi*t/duration)**2
        # Soft boundaries eliminate loop clicks.
        value*=min(1,t/.03,(duration-t)/.03)
        values.append(int(max(-1,min(1,value))*32767))
    with wave.open(str(OUT/f'{name}.wav'),'w') as audio:
        audio.setparams((1,2,RATE,0,'NONE','not compressed'))
        audio.writeframes(struct.pack('<'+'h'*len(values),*values))
print('Created 8 original sound assets')
