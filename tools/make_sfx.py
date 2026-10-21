"""Synthesizes the game's sound effects into assets/sfx (no third-party audio, no licensing).

Run: python3 tools/make_sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"


def note(freq, dur, vol=0.5, attack=0.004, decay=8.0, harmonics=((1, 1.0), (2, 0.3), (3, 0.12))):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = sum(a * math.sin(2 * math.pi * freq * h * t) for h, a in harmonics)
        out.append(vol * env * s / sum(a for _, a in harmonics))
    return out


def mix(*tracks):
    """tracks: (start_seconds, samples)"""
    length = max(int(start * RATE) + len(s) for start, s in tracks)
    buf = [0.0] * length
    for start, s in tracks:
        o = int(start * RATE)
        for i, v in enumerate(s):
            buf[o + i] += v
    return buf


def noise(dur, vol=0.3, decay=30.0, seed=1):
    rng = random.Random(seed)
    return [vol * rng.uniform(-1, 1) * math.exp(-decay * i / RATE) for i in range(int(RATE * dur))]


def save(name, samples):
    peak = max(1e-9, max(abs(v) for v in samples))
    scale = min(1.0, 0.9 / peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v * scale * 32767)) for v in samples))


def sweep(f0, f1, dur, vol=0.4, decay=6.0, square=False):
    """Pitch glide from f0 to f1 (Hz); square=True for a retro buzz."""
    n = int(RATE * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = f0 + (f1 - f0) * (i / n)
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        if square:
            s = 0.6 * (1 if s > 0 else -1)
        out.append(vol * min(1.0, t / 0.003) * math.exp(-decay * t) * s)
    return out


OUT.mkdir(parents=True, exist_ok=True)

# Ball on paddle: soft electric "boop".
save("paddle", mix((0, note(330, 0.12, vol=0.5, decay=30, harmonics=((1, 1), (2, 0.5), (4, 0.2)))), (0, noise(0.02, vol=0.15, decay=150))))
# Ball on wall: tiny tick.
save("wall", note(880, 0.04, vol=0.18, decay=70))
# Brick hit but not broken: glassy ping.
save("hit", note(1046.5, 0.09, vol=0.3, decay=35, harmonics=((1, 1), (2.76, 0.4))))
# Brick broken: bright crack, pitch set per brick strength (1..5).
for level in range(1, 6):
    f = 600 * 2 ** ((level - 1) * 3 / 12)
    save(f"break{level}", mix((0, note(f, 0.16, vol=0.4, decay=22, harmonics=((1, 1), (1.5, 0.5), (3, 0.2)))), (0, noise(0.06, vol=0.22, decay=60, seed=level))))
# Steel: metallic clank.
save("steel", mix((0, note(220, 0.25, vol=0.4, decay=16, harmonics=((1, 1), (2.41, 0.7), (3.93, 0.5), (5.4, 0.3)))), (0, noise(0.02, vol=0.2, decay=200))))
# Explosion: noise burst with a low thump.
save("explode", mix((0, noise(0.6, vol=0.6, decay=7, seed=9)), (0, sweep(140, 40, 0.4, vol=0.6, decay=8))))
# Power-up caught: rising arpeggio.
save("powerup", mix(*[(i * 0.05, note(f, 0.25, vol=0.3, decay=10)) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5])]))
# Bad power-up: falling buzz.
save("bad", sweep(500, 160, 0.35, vol=0.35, decay=6, square=True))
# Laser shot.
save("laser", sweep(1800, 600, 0.09, vol=0.18, decay=25, square=True))
# Boss hit: heavy low hit.
save("bosshit", mix((0, sweep(260, 120, 0.18, vol=0.6, decay=18)), (0, noise(0.05, vol=0.3, decay=80, seed=3))))
# Boss shoots: zap.
save("bossshoot", sweep(900, 300, 0.14, vol=0.22, decay=15))
# Paddle stunned: electric crackle.
save("stun", mix((0, noise(0.3, vol=0.4, decay=10, seed=5)), (0, sweep(120, 90, 0.3, vol=0.4, decay=8, square=True))))
# Boss destroyed: long explosion with a victory chord on top.
save("bossdown", mix((0, noise(1.4, vol=0.6, decay=2.5, seed=11)), (0, sweep(120, 30, 1.0, vol=0.6, decay=3)),
                     *[(0.5 + i * 0.07, note(f, 1.0, vol=0.25, decay=3)) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5])]))
# Ball lost: falling tone.
save("lost", sweep(440, 110, 0.5, vol=0.45, decay=4))
# Level cleared: fanfare.
save("clear", mix(*[(i * 0.09, note(f, 0.5, vol=0.3, decay=5)) for i, f in enumerate([392.0, 523.25, 659.25, 783.99, 1046.5])]))
# Game over: descending minor.
save("gameover", mix(*[(i * 0.18, note(f, 0.6, vol=0.35, decay=4)) for i, f in enumerate([392.0, 311.13, 261.63, 196.0])]))
print("written:", sorted(p.name for p in OUT.glob("*.wav")))
