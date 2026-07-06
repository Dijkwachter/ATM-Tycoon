#!/usr/bin/env python3
"""Genereert de lo-fi ambient-soundtrack van ATM Empire (Ontwerper dd
2026-07-06, vernieuwd audiosysteem).

Drie loops met exact hetzelfde tempo (75 BPM), dezelfde toonsoort
(A-mineur) en hetzelfde arrangement (4 maten, 12,8 s), zodat ze via
volumefading naadloos over elkaar heen kunnen zonder te conflicteren:

- loop_main_v2.wav     rustige EP-akkoorden, zachte bas en vinylknisper
- loop_perc_v2.wav     shakers en zachte rim-klikjes
- loop_synth_pads.wav  warme, rustgevende pad-melodielijn

Plus twee subtiele alerts die qua toonmateriaal in de loops passen:

- sting_cassette_leeg_v2.wav  zacht lo-fi bliepje (G4 -> C5)
- sting_alert.wav             subtiel mechanisch dubbelklikje

Let op: just_audio cachet assets op het toestel op bestandsnaam en
hergebruikt dat cachebestand ook na een app-update. Vervang een track
dus altijd onder een nieuwe naam (versie-suffix ophogen) en pas de
paden in lib/audio/game_audio.dart mee aan.

Draaien vanaf de projectroot:  python3 tool/generate_audio.py
"""

import struct
import numpy as np

RATE = 32000
BPM = 75
BEAT = int(RATE * 60 / BPM)  # 25.600 samples per tel
BARS = 4
LOOP = BEAT * 4 * BARS  # 409.600 samples = 12,8 s

rng = np.random.default_rng(2026_07_06)

# Nootfrequenties (A4 = 440 Hz).
F = {
    "E2": 82.41, "F2": 87.31, "A2": 110.0, "C3": 130.81, "E3": 164.81,
    "F3": 174.61, "G3": 196.0, "A3": 220.0, "B3": 246.94, "C4": 261.63,
    "D4": 293.66, "E4": 329.63, "G4": 392.0, "A4": 440.0, "C5": 523.25,
}

# Het arrangement: een maat per akkoord, Am7 - Fmaj7 - Cmaj7 - Em7.
CHORDS = [
    ("A2", ["A3", "C4", "E4", "G4"]),
    ("F2", ["F3", "A3", "C4", "E4"]),
    ("C3", ["G3", "B3", "C4", "E4"]),
    ("E2", ["E3", "G3", "B3", "D4"]),
]


def add_wrapped(buf, start, signal):
    """Mixt een signaal in de loopbuffer met wraparound, zodat staarten
    over de loopgrens heen aan het begin doorklinken (naadloze loop)."""
    n = len(buf)
    start %= n
    end = start + len(signal)
    if end <= n:
        buf[start:end] += signal
    else:
        head = n - start
        buf[start:] += signal[:head]
        buf[: end - n] += signal[head:]


def lowpass(signal, alpha):
    """Eenvoudig one-pole lowpass-filter voor een dof, warm karakter."""
    out = np.empty_like(signal)
    acc = 0.0
    for i, x in enumerate(signal):
        acc += alpha * (x - acc)
        out[i] = acc
    return out


def ep_note(freq, dur, vel):
    """Warme electric-piano-toon: donkere boventonen, zachte attack,
    lange staart en een klein beetje tremolo."""
    t = np.arange(int(dur * RATE)) / RATE
    tone = (
        1.00 * np.sin(2 * np.pi * freq * t)
        + 0.32 * np.sin(2 * np.pi * 2 * freq * t)
        + 0.10 * np.sin(2 * np.pi * 3 * freq * t)
    )
    attack = np.clip(t / 0.015, 0, 1)
    decay = np.exp(-t / 1.4)
    tremolo = 1 + 0.07 * np.sin(2 * np.pi * 4.3 * t)
    return vel * 0.085 * tone * attack * decay * tremolo


def bass_note(freq, dur, vel):
    t = np.arange(int(dur * RATE)) / RATE
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
    attack = np.clip(t / 0.01, 0, 1)
    decay = np.exp(-t / 0.9)
    return vel * 0.15 * tone * attack * decay


def pad_note(freq, dur, vel):
    """Warme pad: licht ontstemde sinussen plus een octaaf eronder, met
    een trage attack en release."""
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    vibrato = 1 + 0.002 * np.sin(2 * np.pi * 0.25 * t)
    tone = (
        np.sin(2 * np.pi * freq * 0.9985 * t * vibrato)
        + np.sin(2 * np.pi * freq * 1.0015 * t)
        + 0.5 * np.sin(2 * np.pi * (freq / 2) * t)
    )
    attack = np.clip(t / 0.6, 0, 1)
    release = np.clip((dur - t) / 0.6, 0, 1)
    return vel * 0.075 * tone * attack * release


def shaker_hit(vel):
    n = int(0.07 * RATE)
    noise = rng.standard_normal(n)
    # Highpass (differentie) + lichte lowpass geeft een zachte shaker.
    noise = np.diff(noise, prepend=0.0)
    noise = lowpass(noise, 0.55)
    t = np.arange(n)
    # Mini-attack zodat een hit op de loopgrens niet klikt.
    env = np.exp(-t / (0.017 * RATE)) * np.clip(t / (0.003 * RATE), 0, 1)
    return vel * noise * env


def rim_click(vel):
    n = int(0.05 * RATE)
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * 1100 * t) * np.exp(-t / 0.02)
    tick = lowpass(rng.standard_normal(n), 0.5) * np.exp(-t / 0.004)
    return vel * (0.8 * body + 0.5 * tick)


def normalize(buf, peak):
    return buf / max(1e-9, np.max(np.abs(buf))) * peak


def write_wav(path, buf):
    data = (np.clip(buf, -1, 1) * 32767).astype("<i2").tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + len(data)))
        f.write(b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, RATE, RATE * 2, 2, 16))
        f.write(b"data")
        f.write(struct.pack("<I", len(data)))
        f.write(data)
    print(f"{path}: {len(buf) / RATE:.2f}s")


# ---------------------------------------------------------------------
# loop_main.wav: EP-akkoorden + bas + vinyl-sfeer.
# ---------------------------------------------------------------------
main = np.zeros(LOOP)
for bar, (bass, chord) in enumerate(CHORDS):
    bar_start = bar * 4 * BEAT
    # Akkoord op tel 1 (vol) en op de 'en' van 2 (zachter), licht gestrumd.
    for beat, vel in ((0.0, 1.0), (1.5, 0.5)):
        for i, note in enumerate(chord):
            start = bar_start + int(beat * BEAT) + int(0.012 * RATE) * i
            add_wrapped(main, start, ep_note(F[note], 3.2, vel))
    # Bas op tel 1 en de 'en' van 3.
    add_wrapped(main, bar_start, bass_note(F[bass], 2.2, 1.0))
    add_wrapped(main, bar_start + int(2.5 * BEAT), bass_note(F[bass], 1.6, 0.6))

# Vinylknisper: spaarzame, zachte tikjes plus een dun ruisbedje.
crackle = np.zeros(LOOP)
for _ in range(140):
    pos = rng.integers(0, LOOP)
    n = int(0.004 * RATE)
    tick = rng.standard_normal(n) * np.exp(-np.arange(n) / (0.0012 * RATE))
    add_wrapped(crackle, int(pos), rng.uniform(0.25, 1.0) * tick)
main += 0.012 * crackle + 0.0035 * lowpass(rng.standard_normal(LOOP), 0.12)
write_wav("assets/audio/loop_main_v2.wav", normalize(main, 0.60))

# ---------------------------------------------------------------------
# loop_perc.wav: shakers op achtsten, rim-klikjes op tel 2 en 4.
# ---------------------------------------------------------------------
perc = np.zeros(LOOP)
for eighth in range(BARS * 8):
    start = eighth * BEAT // 2
    offbeat = eighth % 2 == 1
    vel = (0.9 if offbeat else 0.55) * rng.uniform(0.85, 1.15)
    add_wrapped(perc, start, shaker_hit(vel))
for bar in range(BARS):
    for beat in (1, 3):
        add_wrapped(perc, (bar * 4 + beat) * BEAT, rim_click(1.0))
write_wav("assets/audio/loop_perc_v2.wav", normalize(perc, 0.45))

# ---------------------------------------------------------------------
# loop_synth_pads.wav: rustgevende melodielijn door de akkoordtonen,
# een noot per halve maat.
# ---------------------------------------------------------------------
pads = np.zeros(LOOP)
melody = ["E4", "G4", "A4", "E4", "G4", "E4", "D4", "B3"]
half_bar = 2 * BEAT
for i, note in enumerate(melody):
    # Iets langer dan een halve maat zodat de noten in elkaar overvloeien.
    add_wrapped(pads, i * half_bar, pad_note(F[note], half_bar / RATE + 0.7, 1.0))
write_wav("assets/audio/loop_synth_pads.wav", normalize(pads, 0.50))

# ---------------------------------------------------------------------
# sting_cassette_leeg.wav: zacht lo-fi bliepje, G4 -> C5.
# ---------------------------------------------------------------------
n = int(0.55 * RATE)
sting = np.zeros(n)
for start, note in ((0.0, "G4"), (0.14, "C5")):
    t = np.arange(int(0.35 * RATE)) / RATE
    blip = (
        np.sin(2 * np.pi * F[note] * t) + 0.15 * np.sin(2 * np.pi * 2 * F[note] * t)
    ) * np.exp(-t / 0.09) * np.clip(t / 0.006, 0, 1)
    s = int(start * RATE)
    sting[s : s + len(blip)] += blip[: n - s]
write_wav("assets/audio/sting_cassette_leeg_v2.wav", normalize(sting, 0.30))

# ---------------------------------------------------------------------
# sting_alert.wav: subtiel mechanisch dubbelklikje.
# ---------------------------------------------------------------------
n = int(0.3 * RATE)
alert = np.zeros(n)
for start, vel in ((0.0, 1.0), (0.09, 0.8)):
    m = int(0.05 * RATE)
    t = np.arange(m) / RATE
    click = (
        0.7 * np.sin(2 * np.pi * 1300 * t) * np.exp(-t / 0.008)
        + 0.4 * lowpass(rng.standard_normal(m), 0.45) * np.exp(-t / 0.003)
    )
    s = int(start * RATE)
    alert[s : s + m] += vel * click
write_wav("assets/audio/sting_alert.wav", normalize(alert, 0.28))
