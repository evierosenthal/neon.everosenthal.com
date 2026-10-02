#!/usr/bin/env python3
"""Composes the Cookie Quest music: an original, quirky, funky chiptune loop
in the spirit of a "strange arcade" tune, exactly 48 s at 120 BPM (24 bars),
seamless when looped.

Everything is synthesised here (pulse / triangle / noise voices, like an
8-bit sound chip) so the track can be re-rendered or tweaked by editing the
note tables below. Needs numpy; on macOS `afconvert` turns the WAV into the
AAC .m4a the game plays.

    python3 tools/compose-cookie-quest-music.py            # writes both files
    python3 tools/compose-cookie-quest-music.py --wav-only

Outputs: www/sounds/cookie-quest-music.m4a and
ios/NitroNebula/Resources/Sounds/cookie-quest-music.m4a (plus a WAV in /tmp).
"""
import math
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
BPM = 120
BARS = 24
STEPS_PER_BAR = 16                       # sixteenth notes
STEP = 60.0 / BPM / 4                    # seconds per sixteenth
LENGTH = BARS * STEPS_PER_BAR * STEP     # 48.0 s
N = int(round(LENGTH * SR))

# --- note helpers --------------------------------------------------------

def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)

E2, F2, G2, A2, Bb2, B2, C3, D3 = 40, 41, 43, 45, 46, 47, 48, 50
D4, E4, F4, Fs4, G4, A4, Bb4, B4 = 62, 64, 65, 66, 67, 69, 70, 71
C5, Cs5, D5, Ds5, E5, F5, Fs5, G5, A5, Bb5, B5, C6 = 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 84

# Chord per bar: (root midi for the bass, arpeggio tones)
CHORDS = {
    'Em': (E2, [E4, G4, B4, D5]),
    'G':  (G2, [G4, B4, D5, G5]),
    'A':  (A2, [A4, Cs5, E5, G5]),
    'Bb': (Bb2, [Bb4, D5, F5, Bb5]),
    'B7': (B2, [B4 - 12, Ds5 - 12, Fs5 - 12, A4]),
    'Am': (A2, [A4, C5, E5, G5]),
    'C':  (C3, [C5, E5, G5, B5]),
    'D':  (D3, [D4, Fs4, A4, C5]),
    'F':  (F2, [F4, A4, C5, E5]),
}
SECTION_A = ['Em', 'Em', 'G', 'A', 'Em', 'Em', 'Bb', 'B7']
SECTION_B = ['Am', 'Am', 'Em', 'Em', 'C', 'D', 'F', 'B7']
PROGRESSION = SECTION_A + SECTION_B + SECTION_A   # 24 bars

# Lead melody: per bar, a list of (step, length in steps, midi note).
# The "oddities" are the chromatic neighbours (A#, F, D#, C#) that keep
# landing where a plain minor tune would not.
THEME_A = [
    [(0, 2, E4), (2, 2, G4), (4, 2, B4), (7, 1, E5), (8, 2, D5), (10, 2, B4), (12, 1, Bb4), (13, 1, A4), (14, 2, G4)],
    [(0, 3, E4), (4, 1, G4), (5, 1, A4), (6, 1, Bb4), (7, 3, B4), (12, 2, E4), (14, 2, D4)],
    [(0, 2, G4), (2, 2, B4), (4, 2, D5), (6, 2, G5), (8, 1, Fs5), (9, 1, F5), (10, 2, E5), (12, 2, D5), (14, 2, B4)],
    [(0, 2, A4), (2, 2, Cs5), (4, 3, E5), (8, 1, A4), (9, 1, Bb4), (10, 2, B4), (14, 2, G4)],
    [(0, 2, E5), (2, 2, G5), (4, 2, B5), (7, 1, E5), (8, 2, D5), (10, 2, B4), (12, 1, Bb4), (13, 1, A4), (14, 2, G4)],
    [(0, 1, E4), (2, 1, E4), (4, 1, G4), (6, 2, B4), (8, 2, Bb4), (10, 2, A4), (12, 2, G4), (14, 2, Fs4)],
    [(0, 3, Bb4), (3, 3, D5), (6, 2, F5), (8, 2, Bb5), (11, 1, A5), (12, 1, Bb5), (14, 2, F5)],
    [(0, 2, B4), (2, 2, Ds5), (4, 2, Fs5), (6, 2, A5), (8, 3, B5), (12, 1, Fs5), (13, 1, Ds5), (14, 2, B4)],
]
THEME_B = [
    [(0, 2, A4), (2, 2, C5), (4, 2, E5), (7, 1, A5), (8, 2, G5), (10, 2, E5), (12, 1, Ds5), (13, 1, D5), (14, 2, C5)],
    [(0, 3, A4), (4, 1, C5), (5, 1, Cs5), (6, 1, D5), (7, 3, E5), (12, 2, A4), (14, 2, G4)],
    [(0, 2, E5), (2, 2, B4), (4, 2, G4), (6, 2, B4), (8, 1, E5), (9, 1, F5), (10, 2, E5), (12, 2, B4), (14, 2, G4)],
    [(0, 4, E4), (6, 2, Bb4), (8, 4, B4), (14, 2, D5)],
    [(0, 2, C5), (2, 2, E5), (4, 2, G5), (6, 2, C6), (8, 1, B5), (9, 1, Bb5), (10, 2, A5), (12, 2, G5), (14, 2, E5)],
    [(0, 2, D5), (2, 2, Fs5), (4, 3, A5), (8, 1, D5), (9, 1, Ds5), (10, 2, E5), (14, 2, C5)],
    [(0, 3, F5), (3, 3, A5), (6, 2, C6), (8, 2, F5), (11, 1, E5), (12, 1, F5), (14, 2, C5)],
    [(0, 2, B4), (2, 2, Ds5), (4, 2, Fs5), (6, 2, A5), (8, 2, B5), (10, 2, A5), (12, 2, Fs5), (14, 2, Ds5)],
]
# The reprise ends on a chromatic turnaround that walks back into bar 1.
THEME_A2 = THEME_A[:7] + [
    [(0, 2, B4), (3, 1, B4), (4, 2, Ds5), (6, 2, Fs5), (8, 1, A5), (9, 1, Bb5), (10, 2, B5), (14, 1, Ds5), (15, 1, D5)],
]
LEAD = THEME_A + THEME_B + THEME_A2

# Funky bass pattern per bar: (step, length, interval from the root);
# 'next-1' is the chromatic approach into the following bar's root.
BASS_PATTERN = [(0, 2, 0), (3, 1, 0), (4, 1, 12), (6, 2, 0), (8, 1, 7), (10, 2, 0), (12, 1, 0), (14, 2, 'next-1')]

# Drums per bar (step lists); every 8th bar gets a snare fill.
KICK = [0, 7, 10]
SNARE = [4, 12]
GHOST = [15]
HATS = list(range(0, 16, 2))
OPEN_HAT = [14]
BLIP_BARS = {1: 11, 5: 11, 9: 11, 13: 11, 17: 11, 21: 11}   # bar index -> step

# --- synthesis ------------------------------------------------------------

rng = np.random.default_rng(20261001)


def env(n, attack=0.002, decay=0.06, sustain=0.7, release=0.03):
    """Chip-style ADSR over n samples (release is inside the note length)."""
    t = np.arange(n) / SR
    total = n / SR
    a = np.clip(t / attack, 0, 1)
    d = np.where(t < attack + decay, 1 - (1 - sustain) * np.clip((t - attack) / decay, 0, 1), sustain)
    r = np.clip((total - t) / release, 0, 1)
    return a * d * r


def pulse(freq, n, duty=0.5, vibrato=0.0, slide_to=None):
    t = np.arange(n) / SR
    f = np.full(n, float(freq))
    if slide_to is not None:
        f = freq * (slide_to / freq) ** np.clip(t / (n / SR), 0, 1)
    if vibrato:
        f = f * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.08) / 0.1, 0, 1))
    phase = np.cumsum(f) / SR % 1.0
    return np.where(phase < duty, 1.0, -1.0)


def triangle(freq, n):
    t = np.arange(n) / SR
    phase = (t * freq) % 1.0
    return 2 * np.abs(2 * phase - 1) - 1


def noise(n):
    return rng.standard_normal(n)


def kick(n=int(0.2 * SR)):
    t = np.arange(n) / SR
    f = 45 + 130 * np.exp(-t / 0.045)
    phase = np.cumsum(f) / SR
    return np.sin(2 * np.pi * phase) * np.exp(-t / 0.07)


def snare(n=int(0.16 * SR), ghost=False):
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.03) * 0.6
    hiss = noise(n) * np.exp(-t / (0.035 if ghost else 0.06))
    return (body + hiss) * (0.45 if ghost else 1.0)


def hat(open_=False):
    n = int((0.14 if open_ else 0.035) * SR)
    t = np.arange(n) / SR
    x = noise(n)
    x = np.diff(x, prepend=0.0)          # crude high-pass
    return x * np.exp(-t / (0.05 if open_ else 0.012)) * 0.6


def blip():
    """The 'oddity': a high pulse that slides down, like a confused alien."""
    n = int(0.18 * SR)
    return pulse(1760, n, duty=0.125, slide_to=330) * env(n, decay=0.15, sustain=0.3, release=0.05)


# --- sequencing -----------------------------------------------------------

left = np.zeros(N)
right = np.zeros(N)


def place(sig, start_sec, gain, pan=0.0):
    """Mix `sig` at `start_sec`, wrapping past the end so the loop is seamless."""
    start = int(round(start_sec * SR)) % N
    idx = (np.arange(len(sig)) + start) % N
    l = gain * (1 - max(pan, 0))
    r = gain * (1 + min(pan, 0))
    np.add.at(left, idx, sig * l)
    np.add.at(right, idx, sig * r)


def step_time(bar, step):
    return (bar * STEPS_PER_BAR + step) * STEP


for bar, chord in enumerate(PROGRESSION):
    root, arp_tones = CHORDS[chord]
    next_root = CHORDS[PROGRESSION[(bar + 1) % BARS]][0]

    # Lead: 25% pulse, slight vibrato, staccato (a sixteenth gap at the end)
    for step, length, note in LEAD[bar]:
        n = int((length * STEP - 0.03) * SR)
        sig = pulse(midi_hz(note), n, duty=0.25, vibrato=0.006) * env(n, decay=0.05, sustain=0.65, release=0.02)
        place(sig, step_time(bar, step), 0.19)

    # Bass: triangle, syncopated, with the chromatic walk-up
    for step, length, interval in BASS_PATTERN:
        note = next_root - 1 if interval == 'next-1' else root + interval
        n = int((length * STEP - 0.01) * SR)
        sig = triangle(midi_hz(note), n) * env(n, attack=0.001, decay=0.04, sustain=0.8, release=0.01)
        place(sig, step_time(bar, step), 0.38)

    # Arpeggio: 50% pulse, quiet, ping-ponging left/right every sixteenth
    for step in range(STEPS_PER_BAR):
        note = arp_tones[step % 4] + (12 if (step // 4) % 2 == 1 else 0)
        n = int((STEP - 0.02) * SR)
        sig = pulse(midi_hz(note), n, duty=0.5) * env(n, decay=0.03, sustain=0.5, release=0.015)
        place(sig, step_time(bar, step), 0.055, pan=0.55 if step % 2 == 0 else -0.55)

    # Drums
    for step in KICK:
        place(kick(), step_time(bar, step), 0.52)
    for step in SNARE:
        place(snare(), step_time(bar, step), 0.22)
    if bar % 2 == 1:
        for step in GHOST:
            place(snare(ghost=True), step_time(bar, step), 0.22)
    for step in HATS:
        accent = 1.0 if step % 4 == 0 else 0.6
        place(hat(), step_time(bar, step), 0.085 * accent, pan=0.2)
    if bar % 4 == 3:
        for step in OPEN_HAT:
            place(hat(open_=True), step_time(bar, step), 0.07, pan=0.2)
    if bar % 8 == 7:
        for step in (12, 13, 14, 15):
            place(snare(ghost=(step % 2 == 1)), step_time(bar, step), 0.2)

    # Oddity blips
    if bar in BLIP_BARS:
        place(blip(), step_time(bar, BLIP_BARS[bar]), 0.11, pan=-0.3 if bar % 8 == 1 else 0.3)

# --- master ---------------------------------------------------------------

mix = np.stack([left, right], axis=1)
# Soften the naive pulse waves' top end with a gentle 2nd-order roll-off
# above 9 kHz (applied in the frequency domain), then a mild saturation /
# limiter.
spec = np.fft.rfft(mix, axis=0)
freqs = np.fft.rfftfreq(N, 1 / SR)
rolloff = 1 / np.sqrt(1 + (freqs / 9000) ** 4)
mix = np.fft.irfft(spec * rolloff[:, None], n=N, axis=0)
mix = np.tanh(mix * 1.35)
mix *= 0.89 / np.max(np.abs(mix))              # about -1 dBFS peak
pcm = (mix * 32767).astype('<i2')

out_dir = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(out_dir)
wav_path = '/tmp/cookie-quest-music.wav'
with wave.open(wav_path, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print(f'wrote {wav_path} ({LENGTH:.1f} s, {BARS} bars at {BPM} BPM)')

if '--wav-only' not in sys.argv:
    targets = [
        os.path.join(repo, 'www', 'sounds', 'cookie-quest-music.m4a'),
        os.path.join(repo, 'ios', 'NitroNebula', 'Resources', 'Sounds', 'cookie-quest-music.m4a'),
    ]
    first = targets[0]
    subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '160000', '-q', '127', '-s', '2',
                    wav_path, first], check=True)
    for t in targets[1:]:
        subprocess.run(['cp', first, t], check=True)
    for t in targets:
        print('wrote', t)
