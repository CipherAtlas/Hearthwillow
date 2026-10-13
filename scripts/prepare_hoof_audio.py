"""Bake only the source horseAudio.ts hoof buffers; keep other recordings intact."""
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets/audio"
RATE = 44100

for surface in ["stone", "wood", "soil", "grass"]:
    for variation in range(4):
        seed, filtered, samples = 1931 + variation * 617, 0.0, []
        hard = surface in ["stone", "wood"]
        pitch = (440 if surface == "wood" else 710) + variation * 37
        for i in range(math.ceil(RATE * .19)):
            t = i / RATE
            seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF
            noise = seed / 2147483648 - 1
            filtered = filtered * .82 + noise * .18
            body = math.sin(math.tau * (155 if hard else 105) * t) * math.exp(-t * 44)
            click = (math.sin(math.tau * pitch * t) * .38 + noise * .32) * math.exp(-t * (105 if hard else 210))
            scuff = filtered * math.exp(-t * 26) * (.1 if hard else .6)
            sample = min(1, t * 1400) * (body * .58 + click * (.65 if hard else .3) + scuff)
            samples.append(struct.pack("<h", max(-32768, min(32767, round(sample * 32767)))))
        with wave.open(str(ROOT / f"hoof_{surface}_{variation}.wav"), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(b"".join(samples))
print("Prepared sixteen source horse hoof cues.")
