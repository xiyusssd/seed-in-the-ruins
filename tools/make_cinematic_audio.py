"""Original melodic score and foley: synthesis only, no sampled recordings.

75 BPM, a 16-bar loop, damped felt-piano partials, warm string-like pads,
sparse celesta and stereo early reflections. Base/warm layers share bar timing.
"""
from pathlib import Path
import json,hashlib,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'game/audio'
RATE=32000;BEAT=.8;BAR=3.2;DURATION=16*BAR
rng=np.random.default_rng(182)
T=np.arange(round(DURATION*RATE))/RATE

def hz(midi):return 440*2**((midi-69)/12)
def note(midi,duration,kind='piano',velocity=.12):
    t=np.arange(round(duration*RATE))/RATE;f=hz(midi);attack=1-np.exp(-t*(75 if kind=='piano' else 140))
    y=np.zeros(len(t))
    for harmonic,weight in enumerate([1,.34,.13,.07,.025],1):
        decay=(1.15+harmonic*.29) if kind=='piano' else (1.8+harmonic*.42)
        # Very mild stiffness creates a felt instrument rather than a clean sine beep.
        y+=weight*np.sin(2*np.pi*f*harmonic*(1+.00013*harmonic**2)*t)*np.exp(-t*decay)
    return y*attack*velocity*np.minimum(1,(duration-t)/.05)
def add(score,event,start,pan=.0):
    index=round(start*RATE);weights=np.sqrt([(1-pan)/2,(1+pan)/2])
    for offset in [index,index-len(score)]:
        lo=max(0,offset);hi=min(len(score),offset+len(event))
        if hi>lo:score[lo:hi]+=event[lo-offset:hi-offset,None]*weights

def room(score):
    dry=score.copy()
    for delay,level in [(.071,.13),(.113,.11),(.193,.09),(.317,.07),(.491,.05),(.719,.035),(.977,.024)]:
        score+=np.roll(dry,round(delay*RATE),axis=0)[:,::-1]*level
    return score

def pad(chords):
    score=np.zeros((len(T),2));local=np.arange(round(BAR*RATE))/RATE
    for bar in range(16):
        tones=chords[bar%len(chords)];env=np.sin(np.pi*np.clip(local/BAR,0,1))**1.3
        for j,midi in enumerate(tones):
            f=hz(midi);tone=np.zeros(len(local))
            for harm,amp in [(1,1),(2,.17),(3,.055)]:
                tone+=amp*(np.sin(2*np.pi*(f*harm-.18)*local)+np.sin(2*np.pi*(f*harm+.18)*local))*.5
            add(score,tone*env*.028,bar*BAR,(j-1)*.28)
    return score

PROGRESSIONS=[[[50,57,65],[46,53,62],[53,60,69],[48,55,64],[50,57,65],[46,53,62],[55,62,69],[45,52,64]],[[53,60,69],[48,55,64],[50,57,65],[46,53,62],[53,60,69],[55,62,70],[48,55,67],[48,55,64]],[[55,62,70],[53,60,69],[46,53,65],[48,55,67],[55,62,70],[50,57,65],[46,53,65],[48,55,67]]]
MELODIES=[[74,72,69,65,67,69,72,69,74,77,76,72,70,69,67,69],[77,76,72,69,70,72,74,72,77,79,77,76,74,72,69,72],[79,77,74,70,72,74,77,74,79,81,79,77,76,74,72,74]]
assets={}
def write(name,score):
    score=np.asarray(score,dtype=float)
    if score.ndim==1:score=np.stack([score,score*.93],axis=1)
    score-=score.mean(axis=0)
    peak=np.max(np.abs(score));score*=min(1,.82/max(peak,1e-9))
    pcm=np.round(np.clip(score,-.99,.99)*32767).astype('<i2')
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as w:w.setparams((2,2,RATE,0,'NONE','not compressed'));w.writeframes(pcm.tobytes())
    assets[name]={'seconds':len(score)/RATE,'sample_rate':RATE,'peak':float(np.max(np.abs(score))),'rms':float(np.sqrt(np.mean(score**2))),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def layer(chapter,warm=False):
    chords=PROGRESSIONS[chapter];score=pad(chords)*(.55 if warm else 1)
    for bar in range(16):
        chord=chords[bar%8]
        if not warm:
            add(score,note(chord[0]-12,3.6,velocity=.13),bar*BAR,-.1)
            for beat,interval in [(0,1),(1.5,2),(3,1)]:add(score,note(chord[interval]+12,3.8,velocity=.10),bar*BAR+beat*BEAT,(interval-1.5)*.45)
        else:
            add(score,note(MELODIES[chapter][bar],4.0,velocity=.17),bar*BAR+BEAT*.5,.16)
            if bar%4==3:add(score,note(MELODIES[chapter][bar]+12,3.0,'bell',.042),bar*BAR+BEAT*2.5,-.35)
    return room(score)
for chapter in range(3):
    for warm in [False,True]:write('chapter%d_%s'%(chapter,'warm' if warm else 'base'),layer(chapter,warm))
write('prologue_score',layer(0,False)+layer(0,True)*.78)
# Filtered continuous wind and gently cresting tide, neither harsh white noise nor a drone.
def air(duration,seed):
    gen=np.random.default_rng(seed);count=round(duration*RATE);freq=np.fft.rfftfreq(count,1/RATE)
    noise=np.fft.rfft(gen.normal(0,1,count));spectrum=noise/np.sqrt(1+(freq/520)**4)
    spectrum*=1-np.exp(-freq/25)
    y=np.fft.irfft(spectrum,n=count);return y/(np.std(y)+1e-9)
for page in range(3):
    duration=24;time=np.arange(round(duration*RATE))/RATE;bed=air(duration,183+page);score=np.zeros((len(time),2))
    if page==0:
        swell=.4+.6*(.5+.5*np.sin(2*np.pi*time/8))**2
        for side in range(2):score[:,side]=np.roll(bed,side*211)*.038*swell+.012*np.sin(2*np.pi*61*time)*swell
    elif page==1:
        for side in range(2):score[:,side]=np.roll(bed,side*317)*.018*(.6+.4*np.sin(2*np.pi*time/12)**2)
        for start,midi in [(4,78),(13,81),(20,76)]:add(score,note(midi,3,'bell',.025),start,.55)
    else:
        for side in range(2):score[:,side]=np.roll(bed,side*193)*.022*(.45+.55*np.sin(2*np.pi*time/12)**2)
        for start in [3,9,16,21]:
            t=np.arange(round(.28*RATE))/RATE;chirp=np.sin(2*np.pi*(2100*t+600*t*t))*.009*np.sin(np.pi*t/.28)**2
            add(score,chirp,start,-.5 if start%2 else .5)
    # FFT-filtered noise is already circular; keep its adjacent boundary samples.
    write('prologue_air%d'%page,score)
for name,duration in [('ui_hover',.09),('ui_confirm',.22),('ui_page',.65),('ui_exit',.85),('ui_arrival',2.8)]:
    time=np.arange(round(duration*RATE))/RATE;score=np.zeros((len(time),2))
    if name=='ui_hover':event=note(81,duration,'bell',.06);add(score,event,0)
    elif name=='ui_confirm':event=air(duration,188)*np.exp(-time*28)*.13+note(69,duration,'piano',.10);add(score,event,0)
    elif name=='ui_page':
        envelope=np.sin(np.pi*time/duration)**2*np.exp(-time*2);event=air(duration,189)*envelope*.16+note(62,duration,'piano',.025);add(score,event,0,-.12)
    elif name=='ui_exit':add(score,air(duration,190)*np.sin(np.pi*time/duration)**2*.075,0,.15)
    else:
        for delay,midi in [(0,62),(.12,69),(.30,77)]:add(score,note(midi,duration-delay,'piano',.12),delay,(delay-.1)*2)
    score*=np.minimum(1,time/.008)[:,None]*np.minimum(1,(duration-time)/.025)[:,None];write(name,score)
(ROOT/'builds/v182-audio-assets.json').write_text(json.dumps({'synthesis':'Original NumPy physical-inspired partials, filtered noise and stereo reflections; no external recordings','bpm':75,'bar_seconds':BAR,'assets':assets},indent=2))
print('CINEMATIC_AUDIO_CREATED',len(assets),'stereo tracks')
