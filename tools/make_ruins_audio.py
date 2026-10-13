"""Original stereo ruin ambience: wind, sub drone, distant resonant metal, sparse echoes."""
import math, random, wave
from array import array
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'game/audio'
RATE=22050
rng=random.Random(4043)
for name,duration in [('ruins',32),('return',32),('clue',3.6),('step',.28),('interact',1.1),('error',.7)]:
    samples=array('h'); wind=0; air=0
    for i in range(int(RATE*duration)):
        t=i/RATE
        wind=.997*wind+.003*rng.uniform(-1,1)
        air=.88*air+.12*rng.uniform(-1,1)
        fade=min(1,t/.7,(duration-t)/.7) if duration>4 else min(1,t/.012)
        left=right=0
        if name=='ruins':
            drone=.105*math.sin(2*math.pi*55*t)+.055*math.sin(2*math.pi*82.5*t)+.03*math.sin(2*math.pi*116.875*t)
            drone*=.65+.22*math.sin(2*math.pi*t/32)
            phase=t%8
            metal=sum(math.sin(2*math.pi*f*phase)*a for f,a in [(173.5,.028),(279.125,.014),(421.75,.007)])*math.exp(-phase*1.25)*(1-math.exp(-phase*16))
            left=drone+wind*2.0+air*.045+metal
            right=drone+wind*1.7+air*.035+metal*.6+.007*math.sin(2*math.pi*54.96875*t)
        elif name=='return':
            tone=sum(a*math.sin(2*math.pi*f*t) for f,a in [(146.875,.05),(174.5,.036),(220,.03),(293.75,.018)])
            left=tone*(.65+.22*math.sin(2*math.pi*t/16))+wind*.45
            right=tone*(.65+.22*math.cos(2*math.pi*t/16))+wind*.5
        elif name=='clue':
            for delay,amp in [(0,1),(.34,.4),(.71,.21),(1.17,.11)]:
                dt=t-delay
                if dt>=0:
                    bell=sum(a*math.sin(2*math.pi*f*dt) for f,a in [(293.66,.22),(440,.09),(698.46,.025)])*math.exp(-dt*2.5)*(1-math.exp(-dt*90))*amp
                    left+=bell;right+=bell*(.8 if delay==0 else 1)
        elif name=='step':
            left=(air*.5+math.sin(t*2*math.pi*105)*.18)*math.exp(-t*23);right=left*.94
        elif name=='interact':
            left=sum(a*math.sin(2*math.pi*f*t) for f,a in [(180,.12),(377,.045),(591,.02)])*math.exp(-t*5);right=left*.9
        else:
            left=.08*math.sin(t*2*math.pi*90)*math.exp(-t*5);right=left
        for value in [left*fade,right*fade]: samples.append(round(max(-.95,min(.95,value))*32767))
    with wave.open(str(OUT/f'{name}.wav'),'w') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(samples.tobytes())
print('Created original stereo ruins / returning colour music and clue / stone / mechanism sounds')
