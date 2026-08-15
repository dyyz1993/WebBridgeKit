#!/usr/bin/env python3
"""Generate the bundled push ringtone library (SuperApp/Resources/PushRingtones).

Each ringtone is synthesized deterministically from its name so the library is
reproducible without shipping third-party audio: names map to a pentatonic
arpeggio (plus a few hand-tuned specials like alarm/bell/descent), rendered as
44.1 kHz mono WAV and converted to IMA4 .caf via afconvert for
UNNotificationSound playback.

Usage: python3 tools/generate-push-ringtones.py
"""

import math
import os
import random
import subprocess
import tempfile
import zlib

SAMPLE_RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "SuperApp", "Resources", "PushRingtones")

# Canonical Bark-compatible ringtone names shared with the debug console picker.
NAMES = [
    "alarm", "anticipation", "bell", "birdsong", "bloom", "calypso", "chime",
    "choochoo", "descent", "electronic", "fanfare", "glass", "horn", "lapis",
    "minuet", "multiway", "newmail", "noire", "paper", "payment", "pop", "pow",
    "promotion", "rings", "sencha", "sherwood", "silo", "stargate", "synthesis",
    "telegraph", "tidings", "tumble", "update", "vibra", "whistle",
]

PENTATONIC = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.26, 783.99, 880.00, 1046.50]


def render(samples):
    """16-bit mono WAV bytes from float samples in [-1, 1]."""
    import io
    import struct

    buf = io.BytesIO()
    buf.write(b"RIFF")
    payload = 36 + len(samples) * 2
    buf.write(struct.pack("<I", payload))
    buf.write(b"WAVEfmt ")
    buf.write(struct.pack("<IHHIIHH", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16))
    buf.write(b"data")
    buf.write(struct.pack("<I", len(samples) * 2))
    for s in samples:
        clamped = max(-1.0, min(1.0, s))
        buf.write(struct.pack("<h", int(clamped * 32767)))
    return buf.getvalue()


def adsr(t, dur, attack=0.008, decay_ratio=0.9994):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / (dur * (1 - decay_ratio) * 12))


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def bell_tone(freq, t, dur):
    env = math.exp(-t / (dur * 0.35))
    return env * (sine(freq, t) + 0.5 * sine(freq * 2, t) + 0.25 * sine(freq * 3.01, t)) / 1.75


def append_note(out, freq, dur, waveform="bell", gain=0.8, gap=0.02):
    total = int((dur + gap) * SAMPLE_RATE)
    for i in range(total):
        t = i / SAMPLE_RATE
        if t < dur:
            if waveform == "bell":
                value = bell_tone(freq, t, dur)
            elif waveform == "pure":
                value = adsr(t, dur) * sine(freq, t)
            else:  # "chiptune" — odd harmonics, steppy envelope
                duty = 0.5
                phase = (freq * t) % 1.0
                square = 1.0 if phase < duty else -1.0
                value = adsr(t, dur, attack=0.002) * 0.6 * square + 0.4 * adsr(t, dur) * sine(freq, t)
            out.append(gain * value)
        else:
            out.append(0.0)


def silence(out, seconds):
    out.extend([0.0] * int(seconds * SAMPLE_RATE))


def generic_arpeggio(name):
    rng = random.Random(zlib.crc32(name.encode()))
    base = rng.randrange(0, 4)
    note_count = 3 + rng.randrange(0, 4)
    note_dur = 0.14 + rng.randrange(0, 3) * 0.05
    waveform = ("bell", "pure", "chiptune")[rng.randrange(0, 3)]
    out = []
    for n in range(note_count):
        step = base + (n if rng.random() < 0.75 else -n % 3)
        freq = PENTATONIC[step % len(PENTATONIC)] * (2 if step >= len(PENTATONIC) else 1)
        append_note(out, freq, note_dur, waveform=waveform, gain=0.75)
    return out


SPECIALS = {
    "alarm": lambda: _alarm(),
    "bell": lambda: _bell(),
    "birdsong": lambda: _birdsong(),
    "choochoo": lambda: _choochoo(),
    "descent": lambda: _descent(),
    "horn": lambda: _horn(),
    "telegraph": lambda: _telegraph(),
    "vibra": lambda: _vibra(),
    "whistle": lambda: _whistle(),
}


def _alarm():
    out = []
    for _ in range(4):
        append_note(out, 880, 0.09, waveform="pure", gain=0.85, gap=0.0)
        silence(out, 0.06)
    return out


def _bell():
    out = []
    append_note(out, 659.26, 1.8, waveform="bell", gain=0.85, gap=0.0)
    return out


def _birdsong():
    out = []
    rng = random.Random(7)
    for _ in range(5):
        freq = 1800 + rng.randrange(0, 700)
        chirp = []
        for i in range(int(0.06 * SAMPLE_RATE)):
            t = i / SAMPLE_RATE
            chirp.append(0.6 * adsr(t, 0.06, attack=0.004) * sine(freq + 300 * math.sin(2 * math.pi * 30 * t), t))
        out.extend(chirp)
        silence(out, 0.07)
    return out


def _choochoo():
    out = []
    for _ in range(3):
        for i in range(int(0.16 * SAMPLE_RATE)):
            t = i / SAMPLE_RATE
            out.append(0.7 * adsr(t, 0.16, attack=0.004) * sine(174, t) * (0.6 + 0.4 * math.sin(2 * math.pi * 22 * t)))
        silence(out, 0.1)
    return out


def _descent():
    out = []
    dur = 1.2
    for i in range(int(dur * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        progress = t / dur
        freq = PENTATONIC[-1] * math.pow(0.5, progress)  # one octave down
        out.append(0.7 * adsr(t, dur, attack=0.01) * bell_tone(freq, 0.2, 0.4))
    return out


def _horn():
    out = []
    dur = 0.8
    for i in range(int(dur * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        value = adsr(t, dur, attack=0.03) * (sine(311, t) + 0.8 * sine(415, t) + 0.3 * sine(622, t)) / 2.1
        out.append(0.8 * value)
    return out


def _telegraph():
    out = []
    for symbol in (0.07, 0.07, 0.07, 0.21):  # ... —   (S)
        append_note(out, 1180, symbol, waveform="pure", gain=0.75, gap=0.0)
        silence(out, 0.09)
    return out


def _vibra():
    out = []
    for _ in range(3):
        burst = []
        for i in range(int(0.28 * SAMPLE_RATE)):
            t = i / SAMPLE_RATE
            burst.append(0.7 * math.sin(2 * math.pi * 170 * t) * (0.55 + 0.45 * math.sin(2 * math.pi * 28 * t)))
        out.extend(burst)
        silence(out, 0.12)
    return out


def _whistle():
    out = []
    dur = 0.7
    for i in range(int(dur * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        wobble = 1 + 0.012 * math.sin(2 * math.pi * 6 * t)
        out.append(0.7 * adsr(t, dur, attack=0.05) * sine(1568 * wobble, t) * (0.5 + 0.5 * math.sin(math.pi * t / dur)))
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name in NAMES:
            samples = SPECIALS[name]() if name in SPECIALS else generic_arpeggio(name)
            wav_path = os.path.join(tmp, name + ".wav")
            caf_path = os.path.join(OUT_DIR, name + ".caf")
            with open(wav_path, "wb") as f:
                f.write(render(samples))
            subprocess.run(
                ["afconvert", "-f", "caff", "-d", "ima4", wav_path, caf_path],
                check=True,
            )
            duration = len(samples) / SAMPLE_RATE
            print(f"{name}.caf  {duration:.2f}s  {os.path.getsize(caf_path)} bytes")
    print(f"\nGenerated {len(NAMES)} ringtones in {os.path.abspath(OUT_DIR)}")


if __name__ == "__main__":
    main()
