"""Verify source PCM and the actual Godot master-bus recording."""
from pathlib import Path
import json,hashlib,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'builds/v182-audio-assets.json').read_text())
summary={'assets':{},'failures':[]}
for name,entry in manifest['assets'].items():
    path=ROOT/'game/audio'/(name+'.wav');assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],name
    with wave.open(str(path),'rb') as w:
        assert w.getnchannels()==2 and w.getsampwidth()==2 and w.getframerate()==32000,name
        frames=w.getnframes();pcm=np.frombuffer(w.readframes(frames),dtype='<i2').reshape(-1,2)/32768
    assert np.isfinite(pcm).all() and np.max(np.abs(pcm))<.95
    assert np.sqrt(np.mean(pcm**2))>.0005,name
    # Centered short UI clicks intentionally carry equal channels; score and beds have width.
    if name.startswith('chapter') or name.startswith('prologue'):assert float(np.abs(pcm[:,0]-pcm[:,1]).mean())>.00001,(name,'missing stereo width')
    assert abs(frames/32000-entry['seconds'])<.0001,name
    jump=float(np.max(np.abs(pcm[0]-pcm[-1])))
    if name.startswith('chapter') or name.startswith('prologue'):assert jump<.04,(name,'loop boundary discontinuity',jump)
    summary['assets'][name]={'sha256':entry['sha256'],'seconds':entry['seconds'],'peak':float(np.max(np.abs(pcm))),'rms':float(np.sqrt(np.mean(pcm**2))),'loop_boundary_jump':jump}
folder=ROOT/'builds/render-iterations/v182-audio/gl_compatibility'
mix=json.loads((folder/'audio-mix-audit.json').read_text());assert mix['failures']==[] and len(mix['segments'])==9
log=(folder/'audio_mix_review-render.log').read_text();assert 'ERROR:' not in log and 'AUDIO_MIX_REVIEW: 9 segments; failures=[]' in log
state_log=(ROOT/'builds/render-iterations/v182-audio-state/gl_compatibility/audio_animation_flow-render.log').read_text()
assert 'AUDIO_ANIMATION_TESTS: 32 checks; failures=[]' in state_log and 'ERROR:' not in state_log and 'leaked at exit' not in state_log
summary['actual_audio_state_checks']=32
source=json.loads((ROOT/'builds/v182-story-verification.json').read_text())['source_files']
for relative,digest in source.items():
    captured=ROOT/'.tools/render-background/v182-audio/gl_compatibility'/relative
    assert hashlib.sha256(captured.read_bytes()).hexdigest()==digest,('audio source changed',relative)
    state_captured=ROOT/'.tools/render-background/v182-audio-state/gl_compatibility'/relative
    assert hashlib.sha256(state_captured.read_bytes()).hexdigest()==digest,('audio state source changed',relative)
with wave.open(str(folder/'audio-mix-preview.wav'),'rb') as w:
    assert w.getnchannels()==2 and w.getframerate()==mix['mix_rate']
    assert w.getnframes()==sum(s['frames'] for s in mix['segments'])
    pcm=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2')/32768
    assert np.max(np.abs(pcm))<.99 and np.sqrt(np.mean(pcm**2))>.001
summary['mix']=mix;summary['mix_sha256']=hashlib.sha256((folder/'audio-mix-preview.wav').read_bytes()).hexdigest()
(ROOT/'builds/v182-audio-verification.json').write_text(json.dumps(summary,indent=2))
print('AUDIO_PCM_CHECK_OK',len(summary['assets']),'assets /',len(mix['segments']),'actual engine segments')
