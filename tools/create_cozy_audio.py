#!/usr/bin/env python3
"""Deterministic original sound design; no third-party samples or recordings."""
from pathlib import Path
import wave
import numpy as np
RATE=24000
DEST=Path(__file__).resolve().parents[1]/'assets/audio'
DEST.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(10410)
def save(name,data):
    assert np.isfinite(data).all()
    data=np.clip(data,-.7,.7)
    with wave.open(str(DEST/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((data*32767).astype('<i2').tobytes())
def tone(f,d=.45):
    t=np.arange(int(RATE*d))/RATE
    env=(1-np.exp(-t*180))*np.exp(-t*8)*(np.minimum((d-t)*40,1))
    return (np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*2.76*t)*np.exp(-t*18))*env*.28
def melody(notes,gap,duration):
    data=np.zeros(int(RATE*duration))
    for start,f in notes:
        sound=tone(f,.55);i=int(start*RATE);end=min(len(data),i+len(sound));data[i:end]+=sound[:end-i]
    return data
x=np.arange(int(.14*RATE))/RATE
save('bridge',(1-np.exp(-x*600))*np.exp(-x*42)*(np.sin(2*np.pi*390*x)+.32*np.sin(2*np.pi*850*x))*.28)
x=np.arange(int(.22*RATE))/RATE
noise=rng.normal(0,1,len(x));noise=np.convolve(noise,np.ones(9)/9,mode='same')
save('remove',((np.sin(2*np.pi*(620*x-470*x*x))*.15)+noise*.10)*np.sin(np.pi*x/.22)**2*np.exp(-x*9))
save('island',melody([(0,659.25),(.10,783.99)],.1,.7))
save('win',melody([(0,523.25),(.14,659.25),(.28,783.99),(.5,1046.50)],.14,1.15))
save('restore',melody([(0,392),(.18,523.25),(.36,659.25),(.54,783.99)],.18,1.2))
save('tap',tone(440,.075)*.35)
save('end',melody([(0,392),(.16,329.63)],.16,.75)*.6)
# Periodic spectral surf: every component completes whole cycles over 8 seconds.
# No discontinuity at the loop boundary and no sharp transient.
duration=8;t=np.arange(RATE*duration)/RATE
sea=np.zeros(len(t))
for cycle in range(80,1500,13):
    sea+=np.sin(2*np.pi*cycle*t/duration+rng.uniform(0,2*np.pi))/(cycle**.55)
sea=sea/max(abs(sea))*.14*(.65+.25*np.sin(2*np.pi*t/duration))
save('sea',sea)
harbor=sea.copy()
for start,f in [(1.3,1568),(1.48,1760),(5.1,1318.5)]:
    clip=tone(f,.24)*.10;i=int(start*RATE);harbor[i:i+len(clip)]+=clip
save('harbor',harbor)
print('9 original mono PCM sound assets generated at 24 kHz.')
