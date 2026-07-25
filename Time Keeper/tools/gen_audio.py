#!/usr/bin/env python3
"""Generate the placeholder audio in assets/audio/.

Short synthesised 22.05kHz mono WAVs, one per name in plan section 11.
Same swap-by-filename rule as the art: drop a new file over the old name.
Run from the project root:  python3 tools/gen_audio.py
"""

import array
import math
import os
import random
import wave

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "audio")
RATE = 22050


def write(name, samples):
    path = os.path.join(OUT, name + ".wav")
    data = array.array("h")
    for s in samples:
        data.append(max(-32000, min(32000, int(s * 32000))))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("  %s.wav  %.2fs" % (name, len(samples) / float(RATE)))


def env(i, n, attack=0.01, release=0.6):
    """Simple attack/decay envelope, 0..1."""
    a = max(1, int(n * attack))
    if i < a:
        return i / float(a)
    return max(0.0, (1.0 - (i - a) / float(n - a))) ** (1.0 / release)


def tone(freq, dur, vol=0.5, wave_shape="sine", sweep=0.0, attack=0.01,
         release=0.6):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + sweep * i / float(n))
        phase += 2.0 * math.pi * f / RATE
        if wave_shape == "square":
            v = 1.0 if math.sin(phase) >= 0 else -1.0
        elif wave_shape == "saw":
            v = ((phase / (2.0 * math.pi)) % 1.0) * 2.0 - 1.0
        else:
            v = math.sin(phase)
        out.append(v * vol * env(i, n, attack, release))
    return out


def noise(dur, vol=0.4, attack=0.005, release=0.5, lowpass=0.3):
    n = int(RATE * dur)
    out = []
    last = 0.0
    rng = random.Random(7)
    for i in range(n):
        last += (rng.uniform(-1.0, 1.0) - last) * lowpass
        out.append(last * vol * env(i, n, attack, release))
    return out


def mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def seq(*layers):
    out = []
    for layer in layers:
        out.extend(layer)
    return out


SOUNDS = {
    # The urgency ladder: one tick per station, distinct pitch so four at once
    # still reads as four separate problems.
    "tick": lambda: tone(880, 0.06, 0.35, "square", release=0.25),
    "flip": lambda: mix(noise(0.30, 0.30, lowpass=0.12),
                        tone(320, 0.30, 0.20, sweep=-0.4)),
    "wind": lambda: seq(*[tone(220 + i * 40, 0.05, 0.22, "saw", release=0.3)
                          for i in range(4)]),
    "snap": lambda: mix(noise(0.35, 0.55, lowpass=0.6),
                        tone(1400, 0.12, 0.35, "square", sweep=-0.7)),
    "keypad_beep": lambda: tone(1320, 0.05, 0.30, "square", release=0.3),
    "keypad_shuffle": lambda: seq(*[tone(400 + (i % 5) * 130, 0.07, 0.18,
                                         "square", release=0.35)
                                    for i in range(12)]),
    "safe_open": lambda: mix(tone(180, 0.9, 0.35, sweep=1.2, release=0.8),
                             noise(0.9, 0.20, lowpass=0.08)),
    "launch": lambda: mix(noise(1.6, 0.45, attack=0.15, lowpass=0.05),
                          tone(120, 1.6, 0.30, sweep=2.5, attack=0.15,
                               release=0.9)),
    "klaxon": lambda: seq(tone(494, 0.22, 0.35, "square", release=0.9),
                          tone(370, 0.22, 0.35, "square", release=0.9),
                          tone(494, 0.22, 0.35, "square", release=0.9),
                          tone(370, 0.34, 0.35, "square", release=0.7)),
    "dividend": lambda: seq(tone(1046, 0.09, 0.28, release=0.4),
                            tone(1568, 0.16, 0.24, release=0.4)),
    "mistake": lambda: mix(tone(160, 0.55, 0.45, "square", sweep=-0.35),
                           tone(113, 0.55, 0.30, "square", sweep=-0.35)),
    "fired": lambda: seq(tone(392, 0.28, 0.35, "square", release=0.5),
                         tone(311, 0.28, 0.35, "square", release=0.5),
                         tone(233, 0.70, 0.35, "square", release=0.8)),
    "unlock": lambda: seq(tone(523, 0.10, 0.30, "square", release=0.4),
                          tone(784, 0.10, 0.30, "square", release=0.4),
                          tone(1046, 0.22, 0.30, "square", release=0.5)),
    "click": lambda: tone(660, 0.04, 0.25, "square", release=0.25),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    print("writing placeholder audio to", OUT)
    for name in sorted(SOUNDS):
        write(name, SOUNDS[name]())


if __name__ == "__main__":
    main()
