#!/usr/bin/env python3
"""Audio delivery checks: usable PCM, quiet mix headroom and seamless ambience."""
from pathlib import Path
import struct,wave,math
root=Path(__file__).resolve().parents[1]/'assets/audio'
checks=0
for name in ['bridge','remove','island','win','restore','tap','end','sea','harbor']:
    with wave.open(str(root/(name+'.wav')),'rb') as w:
        assert (w.getnchannels(),w.getsampwidth(),w.getframerate())==(1,2,24000),name
        data=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
        duration=len(data)/24000
        peak=max(abs(x) for x in data)/32768
        rms=math.sqrt(sum((x/32768)**2 for x in data)/len(data))
        assert .05<=duration<=8,name
        assert .02<peak<.7,name
        assert .005<rms<.15,name
        assert abs(sum(data)/len(data)/32768)<.005,name
        if name in ['sea','harbor']:
            assert abs(data[-1]-data[0])/32768<.002,name+' loop click'
        else:
            assert abs(data[0])<20 and abs(data[-1])<20,name+' endpoint click'
        checks+=6
assert (root/'LICENSE.txt').is_file()
print(f'AUDIO ASSETS: {checks+1} checks, 0 failures; original PCM, headroom and loop boundaries verified.')
