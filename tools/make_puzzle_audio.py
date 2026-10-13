"""Synthesize the original 1.0 chapter score and mechanical foley. No external recordings."""
from pathlib import Path
from array import array
import math,random,wave
out=Path(__file__).resolve().parents[1]/'game/audio';rate=22050
rng=random.Random(10101)
def write(name,duration,fn,stereo=True):
 samples=array('h')
 for i in range(int(rate*duration)):
  t=i/rate
  values=fn(t)
  if not isinstance(values,tuple):values=(values,values*.93)
  fade=min(1,t/.03,(duration-t)/.03)
  for v in values:samples.append(round(max(-.93,min(.93,v*fade))*32767))
 with wave.open(str(out/f'{name}.wav'),'w') as f:
  f.setparams((2,2,rate,0,'NONE','not compressed'));f.writeframes(samples.tobytes())
for chapter,chord in enumerate([[110,146.83,164.81,220],[130.81,164.81,196,261.63],[146.83,174.61,220,293.66]]):
 for layer in ['base','warm']:
  def score(t,c=chapter,f=chord,l=layer):
   drone=sum(.028*math.sin(math.tau*x*t) for x in f[:3])
   step=int(t/2)%8;age=t%2
   note=f[[0,1,2,1,3,2,1,0][step]]*(2 if l=='warm' else 1)
   env=math.exp(-age*(1.5 if c==0 else 2.4))*(1-math.exp(-age*30))
   bell=(math.sin(math.tau*note*t)+.22*math.sin(math.tau*note*2.01*t))*.095*env
   low=.035*math.sin(math.tau*(55+c*10)*t)
   pulse=.015*math.sin(math.tau*82*t)*math.exp(-(t%.8)*12) if c==0 else .012*math.sin(math.tau*196*t)*math.exp(-(t%4)*4)
   value=(drone*.5+low+bell*.38) if l=='base' else (bell+drone+pulse)
   fade=min(1,t/.6,(16-t)/.6)
   return value*fade,value*fade*.85+.007*math.sin(math.tau*(note+.2)*t)*env*fade
  write(f'chapter{chapter}_{layer}',16,score)
for name,duration,freq in [('valve',.8,130),('mirror',1.1,260),('roof',2.5,80),('robot_tread',.5,90),('robot_arm',.65,320),('module',.6,480)]:
 write(name,duration,lambda t,d=duration,f=freq:(.1*math.sin(math.tau*f*t)+.04*math.sin(math.tau*f*2.7*t)+rng.uniform(-.03,.03))*math.exp(-t*4/d))
write('pump_loop',8,lambda t:.075*math.sin(math.tau*66*t)+.02*math.sin(math.tau*132*t)*(1+.3*math.sin(math.tau*4*t)))
write('greenhouse_air',8,lambda t:rng.uniform(-.02,.02)+.006*math.sin(math.tau*422*t)*(.5+.5*math.sin(math.tau*t/8)))
write('leaves_loop',8,lambda t:rng.uniform(-.045,.045)*(.3+.3*math.sin(math.tau*t/8)**2))
print('PUZZLE_AUDIO_CREATED: 6 chapter layers / 9 mechanical and environmental sounds')
