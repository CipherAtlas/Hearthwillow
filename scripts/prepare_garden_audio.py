"""Bake the original gardenEffect synthesis from cosy-v1/audio.ts for native playback."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 44100
root = Path(__file__).resolve().parents[1] / 'assets/audio'
random.seed(62025)
for kind in ['water', 'pour', 'pluck', 'plant', 'crumbs', 'splash']:
    duration = 1.15 if kind in ['water', 'pour'] else .6 if kind == 'splash' else .25
    samples = []
    filtered = 0.0
    for i in range(math.ceil(rate * duration)):
        t, u = i / rate, i / rate / duration
        filtered = filtered * .78 + random.uniform(-1, 1) * .22
        envelope = min(1, t * 60) * (1-u) ** (.7 if kind in ['water', 'pour'] else 2)
        if kind == 'pluck':
            sample = math.sin(t * (850-u*340) * math.tau) * .65 + filtered * .25
        elif kind in ['plant', 'crumbs']:
            sample = filtered * (1.1 if kind == 'plant' else .8)
        else:
            drip = max(0, math.sin(t * (91 if kind == 'pour' else 63))) ** 12
            sample = filtered*.7 + math.sin(t*(1250-(t*7 % 1)*700)*math.tau)*drip*.3
        samples.append(round(sample * envelope * .45 * 32767))
    with wave.open(str(root / ('garden-'+kind+'.wav')), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(struct.pack('<'+'h'*len(samples), *samples))
print('Prepared six source garden sounds.')
