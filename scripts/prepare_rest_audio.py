"""Bake cosy-v1/audio.ts chime and copy the original private-cat recordings."""
import math
import shutil
import struct
import wave
from pathlib import Path

root = Path(__file__).resolve().parents[1] / 'assets/audio'
source = Path('/Users/sabar/Documents/cosy-v1/public/village/audio/animals')
for name in ('cat', 'purr'):
    shutil.copyfile(source / (name + '.mp3'), root / (name + '.mp3'))
rate = 44100
samples = []
for index in range(rate):
    time = index / rate
    sample = 0.0
    for frequency, delay in ((880, 0), (1174.66, .13)):
        age = time - delay
        if 0 <= age < .8:
            gain = .045 * age / .01
            if age >= .01:
                gain = .045 * (.0001 / .045) ** ((min(age, .75) - .01) / .74)
            sample += math.sin(math.tau * frequency * age) * gain
    samples.append(round(sample * 32767))
with wave.open(str(root / 'focus-chime.wav'), 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(rate)
    out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print('Prepared original session chime and cat recordings.')
