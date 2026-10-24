"""Procedural sound effects for My Samurai Way.

    uv run --with numpy python tools/gen_sfx.py

Deterministic (seeded); mono 16-bit 44.1 kHz WAVs in assets/audio/sfx/.
Then verify with tools/verify_sfx.py.
"""
from __future__ import annotations

import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
RNG = np.random.default_rng(1234)


# ---------------------------------------------------------------------------
# building blocks
# ---------------------------------------------------------------------------
def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur, seed):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * dur))


def env_exp(dur, tau, attack=0.002):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    return a * np.exp(-t / tau)


def lowpass(x, cutoff):
    """One-pole lowpass; cutoff may be an array (sweeps)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    k = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k[i] * (x[i] - acc)
        y[i] = acc
    return y


def lowpass2(x, cutoff):
    """Two cascaded poles: 12 dB/oct, so noise really loses its hiss."""
    return lowpass(lowpass(x, cutoff), cutoff)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass2(highpass(highpass(x, lo), lo), hi)


def tone(freq, dur, phase=0.0):
    """Sine with a frequency curve (scalar or array)."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), (int(SR * dur),))
    return np.sin(2 * np.pi * np.cumsum(f) / SR + phase)


def modal(freqs, amps, taus, dur):
    """Sum of decaying partials: bells, metal, wood."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f, a, tau in zip(freqs, amps, taus):
        out += a * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) * np.exp(-t / tau)
    return out


def pluck(freq, dur, bright=0.6, decay=0.6):
    """Koto/shamisen-ish pluck: harmonics, higher ones decay faster."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for h in range(1, 12):
        f = freq * h * (1 + 0.0007 * h * h)
        if f > SR / 2.2:
            break
        amp = (bright ** (h - 1)) / h ** 0.3
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * h ** 0.8 / decay)
    out *= np.clip(t / 0.002, 0, 1)
    return out


def pad(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, delay, dur=None):
    """Shift x later by `delay` seconds."""
    y = np.concatenate([np.zeros(int(SR * delay)), x])
    return pad(y, dur) if dur else y


def finish(x, peak=0.708, fade_in=0.002, fade_out=0.02):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    fi = max(1, int(SR * fade_in))
    fo = max(1, int(SR * fade_out))
    x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
    x[-fo:] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fo, 0, -1) / fo)
    x[0] = 0.0
    x[-1] = 0.0
    return np.clip(x, -1, 1)


def write(name, x, **kw):
    x = finish(x, **kw)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


# ---------------------------------------------------------------------------
# combat
# ---------------------------------------------------------------------------
def swish(dur, f0, f1, seed, q=0.5):
    """Blade cutting air: band-limited noise sweeping from f0 to f1."""
    n = noise(dur, seed)
    t = t_axis(dur)
    sweep = f0 * (f1 / f0) ** (t / dur)
    body = bandpass(n, sweep * (1 - q), sweep * (1 + q))
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return body * e


def slash_light():
    return swish(0.22, 900, 4200, 11, 0.45)


def slash_heavy():
    s = swish(0.38, 350, 2600, 12, 0.55)
    low = tone(np.linspace(140, 70, int(SR * 0.38)), 0.38) * env_exp(0.38, 0.12, 0.05) * 0.4
    return s + low


def hit(heavy=False):
    """Cut + body impact: a pitched thud with a noisy crack on top."""
    dur = 0.5 if heavy else 0.3
    f = 95 if heavy else 170
    t = t_axis(dur)
    thud = tone(f * (0.5 + 0.5 * np.exp(-t / 0.03)), dur) * env_exp(dur, 0.12 if heavy else 0.06)
    crack = lowpass2(noise(dur, 21 if heavy else 22), 1400 if heavy else 3000) * env_exp(dur, 0.02)
    slice_ = bandpass(noise(dur, 23), 2500, 7000) * env_exp(dur, 0.035)
    return thud * (1.3 if heavy else 0.9) + crack * 1.2 + slice_ * (0.35 if heavy else 0.6)


def clash():
    """Steel on steel: inharmonic ringing partials + sharp noise burst."""
    dur = 1.1
    metal = modal([1180, 1715, 2490, 3320, 4630, 6020],
                  [1.0, 0.8, 0.6, 0.45, 0.35, 0.25],
                  [0.45, 0.35, 0.25, 0.18, 0.12, 0.08], dur)
    burst = highpass(noise(dur, 31), 2500) * env_exp(dur, 0.015)
    return metal * 0.7 + burst


def guard():
    """Blade braced: dull wooden/metal knock."""
    dur = 0.35
    knock = modal([420, 980, 1550], [1.0, 0.5, 0.25], [0.06, 0.04, 0.03], dur)
    tap = lowpass2(noise(dur, 41), 2200) * env_exp(dur, 0.01)
    return knock + tap * 0.6


def miss():
    return swish(0.3, 700, 2200, 51, 0.6) * 0.8


def ko():
    """A body hitting the ground + a low taiko boom."""
    dur = 1.2
    t = t_axis(dur)
    boom = tone(90 * (0.55 + 0.45 * np.exp(-t / 0.06)), dur) * env_exp(dur, 0.35)
    fall = lowpass2(noise(dur, 61), 700) * env_exp(dur, 0.08)
    return mix(boom, at(fall * 0.8, 0.05, dur))


def taiko(f=95, dur=0.9, seed=70):
    t = t_axis(dur)
    body = tone(f * (0.6 + 0.4 * np.exp(-t / 0.04)), dur) * env_exp(dur, 0.25)
    skin = lowpass2(noise(dur, seed), 1500) * env_exp(dur, 0.02)
    return body + skin * 0.5


def hyoshigi(seed=80):
    """Kabuki wooden clappers: a bright 'kan'."""
    dur = 0.4
    return modal([2050, 3180, 5100], [1.0, 0.6, 0.3], [0.05, 0.035, 0.02], dur) + \
        highpass(noise(dur, seed), 3000) * env_exp(dur, 0.006) * 0.8


def duel_start():
    """Kabuki opening: clappers accelerating into a taiko hit."""
    dur = 1.8
    parts = [at(hyoshigi(81), 0.0, dur), at(hyoshigi(82) * 0.9, 0.32, dur),
             at(hyoshigi(83) * 0.8, 0.52, dur), at(hyoshigi(84) * 0.75, 0.64, dur),
             at(taiko(82, 1.1, 85) * 1.6, 0.74, dur)]
    return mix(*parts)


def tech():
    """Lightning cut: rising charge then a cracking release."""
    dur = 0.9
    t = t_axis(dur)
    charge = tone(300 + 1500 * (t / dur) ** 2, dur) * np.clip(t / 0.5, 0, 1) * (t < 0.55) * 0.35
    zap = highpass(noise(dur, 91), 1500) * env_exp(dur, 0.08) * 0.9
    return mix(charge, at(zap, 0.55, dur), at(slash_heavy(), 0.5, dur) * 0.8)


# ---------------------------------------------------------------------------
# bocas / moods
# ---------------------------------------------------------------------------
# miyako-bushi scale on D: D Eb G A Bb
D4 = 293.66
SCALE = [D4, D4 * 2 ** (1 / 12), D4 * 2 ** (5 / 12), D4 * 2 ** (7 / 12), D4 * 2 ** (8 / 12)]


def note(semi_from_d4):
    return D4 * 2 ** (semi_from_d4 / 12)


def boca():
    """Shamisen 'chan!' stab: the hero opens his mouth."""
    dur = 0.6
    a = pluck(note(-5), dur, 0.75, 0.25)
    b = pluck(note(0), dur, 0.75, 0.25)
    return mix(a * 0.8, b)


def mood_good():
    """It landed: rising koto arpeggio."""
    dur = 1.2
    seq = [note(0), note(5), note(7), note(12)]
    return mix(*[at(pluck(f, 0.9, 0.55, 0.5), i * 0.08, dur) for i, f in enumerate(seq)])


def mood_bad():
    """It backfired: falling minor second, low."""
    dur = 1.3
    seq = [note(1), note(0), note(-5), note(-11)]
    return mix(*[at(pluck(f, 1.0, 0.5, 0.7), i * 0.12, dur) for i, f in enumerate(seq)])


def mood_none():
    dur = 0.6
    return pluck(note(-2), dur, 0.4, 0.3) * 0.7


def reveal():
    """Personality revealed: bell + koto."""
    dur = 2.0
    bell = modal([523, 1180, 1530, 2100, 2960], [1.0, 0.6, 0.45, 0.3, 0.2], [1.2, 0.8, 0.6, 0.4, 0.3], dur)
    return mix(bell * 0.6, at(pluck(note(7), 1.5, 0.5, 0.8), 0.05, dur))


def victory():
    dur = 3.0
    seq = [(0, 0.0), (5, 0.18), (7, 0.36), (12, 0.54), (7, 0.9), (12, 1.08), (17, 1.26)]
    parts = [at(pluck(note(s), 1.6, 0.6, 0.9), d, dur) for s, d in seq]
    parts.append(at(taiko(90, 1.4, 101), 0.0, dur) * 0.8)
    parts.append(at(taiko(90, 1.4, 102), 1.26, dur) * 0.9)
    return mix(*parts)


def defeat():
    dur = 3.0
    seq = [(1, 0.0), (0, 0.45), (-5, 0.9), (-7, 1.35)]
    parts = [at(pluck(note(s - 12), 1.8, 0.45, 1.2), d, dur) for s, d in seq]
    t = t_axis(dur)
    drone = tone(note(-24), dur) * np.clip(t / 0.4, 0, 1) * np.exp(-t / 1.5) * 0.4
    return mix(*parts, drone)


# ---------------------------------------------------------------------------
# world / ui
# ---------------------------------------------------------------------------
def step(seed):
    """Sandal on packed dirt."""
    dur = 0.13
    scuff = bandpass(noise(dur, seed), 250, 1800) * env_exp(dur, 0.025, 0.004)
    thump = tone(85, dur) * env_exp(dur, 0.025) * 0.9
    return scuff + thump


def step_wood(seed):
    """Sandal on the bridge planks."""
    dur = 0.18
    knock = modal([260 + seed % 5 * 9, 610, 1130], [1.0, 0.5, 0.25], [0.05, 0.03, 0.02], dur)
    return knock + bandpass(noise(dur, seed), 400, 3000) * env_exp(dur, 0.01) * 0.5


def bell():
    """Temple bell: time passes."""
    dur = 4.0
    t = t_axis(dur)
    partials = [110, 232, 296, 413, 553, 705, 902]
    amps = [1.0, 0.7, 0.55, 0.4, 0.3, 0.2, 0.12]
    taus = [3.0, 2.2, 1.8, 1.2, 0.9, 0.6, 0.4]
    b = np.zeros_like(t)
    for f, a, tau in zip(partials, amps, taus):
        beat = 1 + 0.15 * np.sin(2 * np.pi * 0.9 * t)       # slow beating
        b += a * np.sin(2 * np.pi * f * t) * np.exp(-t / tau) * beat
    strike = lowpass2(noise(dur, 111), 900) * env_exp(dur, 0.02)
    return b + strike * 0.5


def ui_move():
    dur = 0.06
    return pluck(note(12), dur, 0.3, 0.05)


def ui_select():
    dur = 0.25
    return mix(pluck(note(7), dur, 0.5, 0.15), at(pluck(note(12), 0.2, 0.5, 0.12), 0.04, dur) * 0.7)


def ui_back():
    dur = 0.22
    return mix(pluck(note(7), dur, 0.5, 0.12) * 0.6, at(pluck(note(0), 0.18, 0.5, 0.12), 0.04, dur) * 0.6)


def blip():
    """Typewriter tick for dialogue text."""
    dur = 0.04
    return pluck(note(19), dur, 0.25, 0.02) * 0.6


def page():
    """Journal page turn."""
    dur = 0.45
    t = t_axis(dur)
    e = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return bandpass(noise(dur, 121), 1200, 7000) * e * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))


def choice():
    """A decision is offered: two soft shamisen notes."""
    dur = 0.8
    return mix(pluck(note(0), 0.7, 0.6, 0.4) * 0.7, at(pluck(note(8), 0.7, 0.6, 0.4), 0.14, dur) * 0.7)


def ending_gong():
    dur = 5.0
    t = t_axis(dur)
    g = np.zeros_like(t)
    for f, a, tau in [(70, 1.0, 3.5), (141, 0.6, 2.5), (199, 0.5, 2.0), (287, 0.3, 1.4), (433, 0.2, 0.9)]:
        g += a * np.sin(2 * np.pi * f * t * (1 + 0.004 * np.exp(-t / 0.5))) * np.exp(-t / tau)
    return g * np.clip(t / 0.01, 0, 1)


SFX = {
    "slash_light": (slash_light, {}),
    "slash_heavy": (slash_heavy, {}),
    "hit": (lambda: hit(False), {}),
    "hit_heavy": (lambda: hit(True), {}),
    "clash": (clash, {}),
    "guard": (guard, {}),
    "miss": (miss, {}),
    "ko": (ko, {}),
    "tech": (tech, {}),
    "duel_start": (duel_start, {}),
    "boca": (boca, {}),
    "mood_good": (mood_good, {}),
    "mood_bad": (mood_bad, {}),
    "mood_none": (mood_none, {}),
    "reveal": (reveal, {}),
    "victory": (victory, {"fade_out": 0.3}),
    "defeat": (defeat, {"fade_out": 0.4}),
    "step_1": (lambda: step(201), {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.5}),
    "step_2": (lambda: step(202), {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.5}),
    "step_3": (lambda: step(203), {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.5}),
    "step_wood_1": (lambda: step_wood(211), {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.5}),
    "step_wood_2": (lambda: step_wood(212), {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.5}),
    "bell": (bell, {"fade_out": 0.4}),
    "ui_move": (ui_move, {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.45}),
    "ui_select": (ui_select, {"peak": 0.55}),
    "ui_back": (ui_back, {"peak": 0.5}),
    "blip": (blip, {"fade_in": 0.001, "fade_out": 0.012, "peak": 0.3}),
    "page": (page, {"peak": 0.5}),
    "choice": (choice, {"peak": 0.55}),
    "ending_gong": (ending_gong, {"fade_out": 0.5}),
}


def main():
    for name, (fn, kw) in SFX.items():
        write(name, fn(), **kw)
    print("sfx generated:", len(SFX))


if __name__ == "__main__":
    main()
