#!/usr/bin/env python3
"""Reproducible development-only extraction; application never needs Python/network.
Requires ffmpeg, numpy, scipy. Uses CC0 Freesound 330410 HQ MP3 preview.
Pitch reference is the lower octave reed; preserves the recorded paired reeds.
"""
from pathlib import Path
import subprocess, wave, json, hashlib
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly
from fractions import Fraction

root = Path(__file__).resolve().parent.parent
source = root/'AudioSource/harmonium-330410-hq.mp3'
assert source.stat().st_size == 11496288, 'Incomplete download; resume before extraction'
wav = root/'AudioSource/source-decoded.wav'
subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ar','44100','-ac','1',str(wav)],check=True)
with wave.open(str(wav)) as w:
    rate = w.getframerate()
    audio = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float)/32768
hop=441
rms=np.sqrt(np.mean(audio[:len(audio)//hop*hop].reshape(-1,hop)**2,axis=1))
mask=rms>.028
for i in range(1,len(mask)-12):
    if mask[i-1] and not mask[i] and any(mask[i:i+12]):
        mask[i:i+np.argmax(mask[i:i+12])]=True
changes=np.diff(np.r_[False,mask,False].astype(int))
segments=[(s*.01,e*.01) for s,e in zip(np.where(changes==1)[0],np.where(changes==-1)[0]) if e-s>50 and s*.01<375]
assert len(segments)==39, len(segments)
resource=root/'Sources/SurBox/Resources'
(resource/'Samples').mkdir(parents=True,exist_ok=True)
records=[]; evidence=[]
for index,(start,end) in enumerate(segments):
    midi=36+index
    fundamental=440*2**((midi-69)/12)
    x=audio[int((start+.6)*rate):int((start+1.6)*rate)]
    spectrum=abs(np.fft.rfft(x*np.hanning(len(x)),262144)); freqs=np.fft.rfftfreq(262144,1/rate)
    # Low notes have strong octave reeds. Highest seven lose the lower rank;
    # selecting the lower reference band also works where its amplitude is low.
    band=np.where((freqs>fundamental*.978)&(freqs<fundamental*1.022))[0]
    j=band[np.argmax(spectrum[band])]
    a,b,c=np.log(np.maximum(spectrum[j-1:j+2],1e-12))
    frac=.5*(a-c)/(a-2*b+c)
    observed=(j+frac)*rate/262144
    ratio=Fraction(observed/fundamental).limit_denominator(2000)
    raw=audio[max(0,int((start-.015)*rate)):int(min(start+4.5,end-.2)*rate)]
    raw=sosfilt(butter(2,35,fs=rate,btype='highpass',output='sos'),raw)
    raw=resample_poly(raw,ratio.numerator,ratio.denominator)
    # Gentle common loudness target, retain recorded within-note fluctuations.
    raw*=min(3.0,.20/max(.001,float(np.sqrt(np.mean(raw[int(.7*rate):int(2.7*rate)]**2)))))
    peak=max(abs(raw)); raw*=min(1,.85/peak)
    fade=220; raw[:fade]*=np.linspace(0,1,fade); raw[-fade:]*=np.linspace(1,0,fade)
    pcm=np.round(raw*32767).astype('<i2')
    name=f'note-{midi}.wav'
    with wave.open(str(resource/'Samples'/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(pcm.tobytes())
    # Renderer applies 60 ms overlap crossfade and skips the overlapped head.
    records.append(dict(midi=midi,file=name,loopStart=int(rate*.85),loopEnd=len(raw)-int(rate*.15)))
    evidence.append(dict(midi=midi,start_seconds=start,end_seconds=end,reference_hz=fundamental,measured_hz=observed,cents=1200*np.log2(observed/fundamental),frames=len(raw)))
(resource/'samples.json').write_text(json.dumps(records,indent=2)+'\n')
(root/'AudioSource/extraction.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),note_count=len(records),pitch_reference='Lower reed fundamental; upper octave rank retained',notes=evidence),indent=2)+'\n')
wav.unlink()
print(f'Prepared {len(records)} authentic samples, MIDI 36–74. Source SHA256: {hashlib.sha256(source.read_bytes()).hexdigest()}')
