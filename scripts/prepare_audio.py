"""Local synthesis of the source's quiet filtered wind and short contact sounds."""
import array
import subprocess
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio'
rate = 44100
random.seed(62025)

def save(name, samples):
    with wave.open(str(ROOT / name), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(b''.join(struct.pack('<h', max(-32768, min(32767, round(value * 32767)))) for value in samples))

def biquad(samples, frequency, highpass=False):
    omega = math.tau*frequency/rate
    cosine, alpha = math.cos(omega), math.sin(omega)/math.sqrt(2)
    b0 = (1+cosine)/2 if highpass else (1-cosine)/2
    b1 = -(1+cosine) if highpass else 1-cosine
    a0, a1, a2 = 1+alpha, -2*cosine, 1-alpha
    x1 = x2 = y1 = y2 = 0.0
    result = []
    for x in samples:
        y = (b0*x+b1*x1+b0*x2-a1*y1-a2*y2)/a0
        result.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return result

# Same 90 Hz high-pass and 620 Hz low-pass as the original Web Audio wind bed.
wind = biquad(biquad([random.uniform(-1,1) for _ in range(rate*6)],90,True),620)
# Crossfade the loop seam; no click on each six-second repeat.
fade = rate//4
for i in range(fade):
    t = i/fade
    wind[i] = wind[-fade+i]*(1-t)+wind[i]*t
save('wind.wav',wind)
for kind in ['grass','stone','soil','wood']:
    for variant in range(6):
        samples, low = [], 0.0
        duration = .19 if kind == 'grass' else .12
        count = math.ceil(rate*duration)
        pitch = (155 if kind == 'wood' else 95 if kind == 'stone' else 65)+variant*7
        for i in range(count):
            t, noise = i/rate, random.uniform(-1,1)
            low = low*.65+noise*.35
            thud = math.sin(t*math.tau*pitch)*math.exp(-t*55)
            grit = (noise if kind == 'stone' else low)*math.exp(-t*(26 if kind == 'grass' else 65))
            samples.append((thud*.35+grit*.5)*min(1,t*1200)*(1-i/count))
        save('step_'+kind+'_'+str(variant)+'.wav',samples)

for variant in range(4):
    samples, phase = [], 0.0
    pitch = 1500+variant*250
    for i in range(round(rate*.22)):
        t = i/rate
        frequency = pitch*1.4**(t/.08) if t < .08 else pitch*1.4*(.9/1.4)**(min(1,(t-.08)/.1))
        phase += math.tau*frequency/rate
        level = .023*t/.02 if t < .02 else .023*(.0001/.023)**(min(1,(t-.02)/.18))
        samples.append(math.sin(phase)*level)
    save('bird_'+str(variant)+'.wav',samples)
print('Prepared original wind, four contact surfaces and bird chirps.')

# Use the same 0.8-second seam crossfade as the browser recording player.
# Keep original MP3s alongside these derived, compact native looping streams.
for name in ['stream','fire','rain']:
    decoded = subprocess.run(['ffmpeg','-v','error','-i',str(ROOT/(name+'.mp3')),'-f','f32le','-ar',str(rate),'-ac','2','pipe:1'],check=True,capture_output=True).stdout
    samples = array.array('f'); samples.frombytes(decoded)
    frames = len(samples)//2; fade = min(int(rate*.8),frames//4); length = frames-fade
    loop = samples[fade*2:length*2]
    for i in range(fade):
        blend = i/fade
        for channel in range(2): loop.append(samples[(length+i)*2+channel]*(1-blend)+samples[i*2+channel]*blend)
    subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(rate),'-ac','2','-i','pipe:0','-c:a','libmp3lame','-q:a','2',str(ROOT/(name+'-loop.mp3'))],input=loop.tobytes(),check=True)
print('Prepared source-matched recording loop seams.')
