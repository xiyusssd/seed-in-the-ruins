"""Original environmental sound design. No third-party recordings or samples.

Circular filtered noise, irregular overlapping water crests and damped mechanical
modes create long beds; mono assets leave directional rendering to Godot.
"""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/audio'
RATE = 32000
assets = {}

def noise(seconds, seed, low=50, high=4500):
    rng = np.random.default_rng(seed)
    count = round(seconds * RATE)
    f = np.fft.rfftfreq(count, 1/RATE)
    spectrum = np.fft.rfft(rng.normal(size=count))
    spectrum *= (1-np.exp(-(f/max(1, low))**2)) / np.sqrt(1+(f/high)**6)
    y = np.fft.irfft(spectrum, n=count)
    return y / max(np.std(y), 1e-8)

def add_loop(score, event, start):
    indices = (np.arange(len(event)) + round(start*RATE)) % len(score)
    np.add.at(score, indices, event)

def write(name, score, loop=False):
    score = np.asarray(score, dtype=float)
    score -= score.mean()
    score *= min(1, .78/max(np.max(np.abs(score)), 1e-8))
    if not loop:
        count = min(len(score)//2, round(.008*RATE))
        score[:count] *= np.linspace(0, 1, count)
        score[-count:] *= np.linspace(1, 0, count)
    pcm = np.round(np.clip(score, -.99, .99)*32767).astype('<i2')
    path = OUT / (name+'.wav')
    with wave.open(str(path), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(pcm.tobytes())
    assets[name] = {'seconds': len(score)/RATE, 'mono': True, 'loop': loop,
                    'peak': float(np.max(np.abs(score))),
                    'rms': float(np.sqrt(np.mean(score**2))),
                    'boundary_delta': float(abs(score[-1]-score[0])),
                    'boundary_relative_to_adjacent_samples': float(abs(score[-1]-score[0]) / max(np.sqrt(np.mean(np.diff(score)**2)), 1e-8)),
                    'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

# Noncommensurate loop lengths and deterministic offsets avoid synchronized beds.
seconds = 37
t = np.arange(seconds*RATE)/RATE
wind = noise(seconds, 11301, 35, 1350)
gust = .58+.22*np.sin(2*np.pi*t/seconds)+.12*np.sin(6*np.pi*t/seconds+1.7)
write('coastal_wind', wind*gust*.070, True)

seconds = 43
t = np.arange(seconds*RATE)/RATE
surf = noise(seconds, 11302, 35, 2200)*.010
rng = np.random.default_rng(11303)
for i, start in enumerate([.3, 6.1, 12.7, 20.3, 28.6, 35.8, 41.8]):
    duration = rng.uniform(3.8, 6.1)
    local = np.arange(round(duration*RATE))/RATE
    envelope = np.sin(np.pi*local/duration)**1.7
    crest = noise(duration, 11304+i, 70, 3800) * envelope *.070
    # Retreating shingle is thinner and longer than the incoming wave.
    retreat = noise(duration, 11324+i, 900, 6800)*envelope*(local/duration)*.020
    add_loop(surf, crest+retreat, start)
write('coastal_surf', surf, True)

seconds = 29
t = np.arange(seconds*RATE)/RATE
water = noise(seconds, 11340, 160, 5900)*(.038+.013*np.sin(2*np.pi*t/seconds))
for i in range(43):
    duration = rng.uniform(.045, .13)
    local = np.arange(round(duration*RATE))/RATE
    frequency = rng.uniform(520, 1800)
    bubble = np.sin(2*np.pi*(frequency*local-1500*local**2))*np.exp(-local*55)*.014
    bubble *= np.minimum(1, local/.002)
    add_loop(water, bubble, rng.uniform(0, seconds))
write('channel_flow', water, True)

seconds = 31
t = np.arange(seconds*RATE)/RATE
drips = noise(seconds, 11341, 200, 1800)*.003
for i in range(27):
    duration = rng.uniform(.12, .24)
    local = np.arange(round(duration*RATE))/RATE
    f = rng.uniform(850, 2100)
    drop = np.sin(2*np.pi*(f*local-700*local**2))*np.exp(-local*36)*.047
    drop += noise(duration, 11350+i, 500, 7500)*np.exp(-local*75)*.032
    drop *= np.minimum(1, local/.002)
    add_loop(drips, drop, rng.uniform(0, seconds))
write('greenhouse_drips', drips, True)

seconds = 41
t = np.arange(seconds*RATE)/RATE
leaves = noise(seconds, 11390, 750, 6600)*.005
for i in range(29):
    duration = rng.uniform(.3, 1.6)
    local = np.arange(round(duration*RATE))/RATE
    envelope = np.sin(np.pi*local/duration)**2
    flutter = .6+.4*np.sin(2*np.pi*rng.uniform(5, 11)*local+rng.uniform(0, 6))**2
    add_loop(leaves, noise(duration, 11400+i, 950, 7800)*envelope*flutter*.028, rng.uniform(0, seconds))
write('canopy_rustle', leaves, True)

seconds = 23
t = np.arange(seconds*RATE)/RATE
phase = 2*np.pi*92*t + .012*np.sin(2*np.pi*t/seconds)
pump = np.zeros_like(t)
for harmonic, level in [(1,.015),(2,.009),(3,.005),(7,.0015)]:
    pump += np.sin(phase*harmonic)*level
pump += noise(seconds, 11440, 100, 2200)*.012*(.75+.25*np.sin(2*np.pi*46*t)**2)
for i in range(23*4):
    local = np.arange(round(.055*RATE))/RATE
    tap = noise(.055, 11500+i, 300, 4000)*np.exp(-local*85)*.005
    tap *= np.minimum(1, local/.001)
    add_loop(pump, tap, i*.25)
write('pump_mechanism', pump, True)

# Alternating original takes avoid repeated impacts. Different surfaces use
# different resonances and friction bands rather than pitch alone.
for surface in ['stone', 'metal']:
    for take in range(4):
        seconds = .32 if surface == 'stone' else .44
        t = np.arange(round(seconds*RATE))/RATE
        seed = 11700 + take + ['stone','metal','wood'].index(surface)*20
        contact = noise(seconds, seed, 120, 5300)*np.exp(-t*(35+take*3))*.075
        contact *= 1-np.exp(-t*800)
        if surface == 'stone':
            contact += noise(seconds, seed+100, 1400, 7200)*np.sin(np.pi*t/seconds)**2*np.exp(-t*12)*.025
            modes = [(95+take*6,.06,30),(220+take*11,.014,45)]
        elif surface == 'metal':
            modes = [(145+take*7,.055,16),(430+take*11,.023,20),(1180+take*23,.007,30)]
        else:
            modes = [(115+take*9,.08,25),(305+take*17,.020,28)]
        for f, level, damping in modes:
            contact += np.sin(2*np.pi*f*t)*np.exp(-t*damping)*(1-np.exp(-t*700))*level
        write(f'foot_{surface}_{take}', contact)

report = {'provenance': 'Original procedural synthesis; no field recordings', 'sample_rate': RATE, 'assets': assets}
for name, info in assets.items():
    assert info['peak'] < .8 and info['rms'] > .001, name
    if info['loop']: assert info['boundary_relative_to_adjacent_samples'] < 6, name
(ROOT/'builds/v113-audio-assets.json').write_text(json.dumps(report, indent=2)+'\n')
print('REALISM_AUDIO_CREATED', len(assets), 'mono assets')
