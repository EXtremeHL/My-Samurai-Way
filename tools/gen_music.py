"""Procedural music + ambience for My Samurai Way (feudal-Japan valley, HD-2D).

Everything is synthesised in code and seeded, so two runs give byte-identical
WAVs (16-bit PCM, 44.1 kHz, stereo) in assets/audio/music/.

    uv run --with numpy python tools/gen_music.py
    uv run --with numpy python tools/verify_music.py

Loop files are rendered *circularly*: every note / hit / reverb tail that runs
past the end of the buffer wraps around and is added to the beginning, noise
beds are shaped in the frequency domain over exactly one loop length (so they
are periodic), and sustained tones are snapped to an integer number of cycles
per loop. Finally the loop is rotated (by at most one beat for music) so the
seam sits in the quietest spot. No fades are applied to loops.

Scale: miyako-bushi ("in" scale) on D = D Eb G A Bb.
"""
from __future__ import annotations

import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")
TAU = 2.0 * np.pi


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def mtof(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def snap(f: float, n: int) -> float:
    """Snap frequency so an integer number of cycles fits n samples."""
    L = n / SR
    return max(1.0, round(f * L)) / L


def pan(sig: np.ndarray, p: float) -> np.ndarray:
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([sig * np.cos(a), sig * np.sin(a)], axis=1)


def rc_ramp(n: int) -> np.ndarray:
    """Raised-cosine 0 -> 1 over n samples."""
    if n <= 1:
        return np.ones(max(n, 0))
    return 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / (n - 1))


def fft_filter(x: np.ndarray, mask_fn) -> np.ndarray:
    """Zero-phase filter in frequency domain (circular over len(x))."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return np.fft.irfft(X * mask_fn(f), n=len(x))


def lp(fc, order=2):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def hp(fc, order=2):
    return lambda f: 1.0 - 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def bp_log(fc, octaves):
    def m(f):
        ff = np.maximum(f, 1.0)
        return np.exp(-0.5 * (np.log2(ff / fc) / octaves) ** 2)
    return m


def circ_smooth_noise(rng, n, fc):
    """Periodic smooth random control signal normalised to [-1, 1]."""
    s = fft_filter(rng.standard_normal(n), lp(fc, 4))
    s -= s.mean()
    return s / (np.abs(s).max() + 1e-12)


class Bus:
    """Stereo dry bus + reverb send bus, circular (loop) or linear."""

    def __init__(self, n: int, loop: bool):
        self.n, self.loop = n, loop
        self.dry = np.zeros((n, 2))
        self.send = np.zeros((n, 2))

    def _add(self, buf, start, sig):
        start = int(round(start))
        m = len(sig)
        if self.loop:
            s, pos = start % self.n, 0
            while pos < m:
                k = min(m - pos, self.n - s)
                buf[s:s + k] += sig[pos:pos + k]
                pos += k
                s = 0
        else:
            if start < 0:
                sig, start = sig[-start:], 0
            k = min(len(sig), self.n - start)
            if k > 0:
                buf[start:start + k] += sig[:k]

    def add(self, start_s: float, mono: np.ndarray, p: float = 0.0,
            gain: float = 1.0, send: float = 0.3):
        st = pan(mono * gain, p)
        self._add(self.dry, start_s * SR, st)
        if send:
            self._add(self.send, start_s * SR, st * send)

    def add_stereo(self, start_s, st, send=0.3):
        self._add(self.dry, start_s * SR, st)
        if send:
            self._add(self.send, start_s * SR, st * send)


def make_ir(rng, rt60=2.2, length=2.6, predelay=0.022, damp=3200.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    pd = int(predelay * SR)
    for c in range(2):
        dark = fft_filter(rng.standard_normal(n), lp(damp, 2))
        bright = fft_filter(rng.standard_normal(n), lp(9000.0, 2))
        tail = (0.8 * dark * np.exp(-6.9 * t / rt60)
                + 0.5 * bright * np.exp(-6.9 * t / (rt60 * 0.25)))
        tail[:pd] = 0.0
        tail[pd:pd + 256] *= rc_ramp(256)
        # a few early reflections, different per side for width
        for d, g in ((0.011, 0.5), (0.019, 0.35), (0.029, 0.28), (0.041, 0.2)):
            k = int((d + 0.004 * c) * SR)
            tail[k] += g * 6.0
        tail[-int(0.2 * n):] *= rc_ramp(int(0.2 * n))[::-1]
        ir[:, c] = tail / np.sqrt(np.sum(tail ** 2))
    return ir


def apply_reverb(bus: Bus, ir: np.ndarray, wet: float) -> np.ndarray:
    n = bus.n
    N = n if bus.loop else n + len(ir)
    out = bus.dry.copy()
    for c in range(2):
        X = np.fft.rfft(bus.send[:, c], N)
        H = np.fft.rfft(ir[:, c], N)
        y = np.fft.irfft(X * H, N)
        out[:, c] += wet * y[:n]  # loop: circular conv == wrapped tail
    return out


def seam_mad(x, r, w=1024):
    n = len(x)
    a = x[(np.arange(r - w, r)) % n]
    b = x[(np.arange(r, r + w)) % n]
    return np.abs(a - b).mean(axis=0).max()


def best_rotation(x, center=0, radius=None, step=128):
    n = len(x)
    if radius is None:
        cands = range(0, n, step)
    else:
        cands = [(center + d) % n for d in range(-radius, radius + 1, step)]
    best = min(cands, key=lambda r: (round(seam_mad(x, r), 6), r))
    return np.roll(x, -best, axis=0), best


def write_wav(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    pcm = np.round(x * 32767.0).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    pk = np.abs(x).max()
    rms = np.sqrt(np.mean(x ** 2))
    print(f"wrote {name:16s} {len(x) / SR:6.2f}s peak {pk:.3f} "
          f"rms {20 * np.log10(rms + 1e-12):6.1f} dBFS")


def finish_music(x, peak=0.5, drive=0.0):
    """Remove DC, optional gentle tanh peak compression, normalise peak."""
    x = x - x.mean(axis=0)
    x = x / np.abs(x).max()
    if drive > 0:
        x = np.tanh(drive * x) / np.tanh(drive)
    return x * (peak / np.abs(x).max())


def finish_amb(x, rms_db=-27.0, peak_max=0.45):
    x = x - x.mean(axis=0)
    rms = np.sqrt(np.mean(x ** 2))
    x = x * (10 ** (rms_db / 20) / rms)
    pk = np.abs(x).max()
    if pk > peak_max:
        x *= peak_max / pk
    return x


# --------------------------------------------------------------------------
# instruments (mono, start at exactly 0 amplitude)
# --------------------------------------------------------------------------
def koto(rng, f0, vel=0.7, bright=1.0, tau1=None, maxdur=5.5):
    """Plucked koto: inharmonic partials, per-partial exponential decay,
    small pitch drop after the pluck, soft pick noise."""
    if tau1 is None:
        tau1 = 1.5 * (220.0 / f0) ** 0.4
    dur = min(4.5 * tau1, maxdur)
    n = int(dur * SR)
    t = np.arange(n) / SR
    K = int(max(3, min(22, 8500.0 / f0)))
    k = np.arange(1, K + 1)[:, None]
    fk = f0 * k * np.sqrt(1.0 + 0.00025 * k * k)
    soft = 0.55 + 0.45 * vel * bright
    amp = np.abs(np.sin(np.pi * k * 0.21)) / k ** 1.15 * np.exp(-(k - 1) * 0.16 / soft)
    tau = tau1 / (1.0 + 0.5 * (k - 1) ** 1.1)
    pt = t + 0.004 * 0.04 * (1.0 - np.exp(-t / 0.04))  # pitch settles down
    ph0 = rng.uniform(0, TAU, (K, 1))
    s = (amp * np.exp(-t / tau) * np.sin(TAU * fk * pt + ph0)).sum(axis=0)
    nc = int(0.015 * SR)
    click = fft_filter(rng.standard_normal(nc), bp_log(2500.0, 1.0))
    click *= np.exp(-np.arange(nc) / SR / 0.003)
    s[:nc] += 0.25 * click * amp.sum() / K
    a = int(0.0025 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.06 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def shamisen(rng, f0, vel=0.8):
    """Bright, sharp, quickly decaying plucked string with sawari buzz."""
    dur = 0.9
    n = int(dur * SR)
    t = np.arange(n) / SR
    K = int(max(4, min(40, 11000.0 / f0)))
    k = np.arange(1, K + 1)[:, None]
    fk = f0 * k * np.sqrt(1.0 + 0.0001 * k * k)
    amp = np.abs(np.sin(np.pi * k * 0.08) + 0.15) / k ** 0.75
    tau = 0.32 / (1.0 + 0.55 * (k - 1))
    saw = np.where(k >= 5, 0.18, 0.0) * np.exp(-t / 0.22)   # sawari sustain
    env = np.exp(-t / tau) + saw
    ph0 = rng.uniform(0, TAU, (K, 1))
    pt = t + 0.008 * 0.02 * (1.0 - np.exp(-t / 0.02))
    s = (amp * env * np.sin(TAU * fk * pt + ph0)).sum(axis=0)
    nc = int(0.01 * SR)
    click = fft_filter(rng.standard_normal(nc), hp(2500.0))
    s[:nc] += 0.6 * click * np.exp(-np.arange(nc) / SR / 0.0015) * amp.sum() / K * 3
    a = int(0.001 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.05 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def shakuhachi(rng, f0, dur, vel=0.7, scoop=0.7, vib=0.28, breath=0.22,
               fall=0.0, dim=0.12, rel=0.22):
    """Breathy end-blown flute: soft harmonic tone with pitch scoop,
    delayed vibrato (+ correlated tremolo), filtered breath noise, chiff."""
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    vdepth = vib * np.clip((t - 0.32) / 0.55, 0.0, 1.0)
    vph = rng.uniform(0, TAU)
    vsin = np.sin(TAU * 5.1 * t + vph)
    semis = -scoop * np.exp(-t / 0.075) + vdepth * vsin
    if fall:
        semis -= fall * np.clip((t - (dur - 0.3)) / 0.45, 0.0, 1.0) ** 2
    f = f0 * 2.0 ** (semis / 12.0)
    ph = TAU * np.cumsum(f) / SR
    tone = (np.sin(ph) + 0.30 * np.sin(2 * ph + 0.3) + 0.10 * np.sin(3 * ph + 1.1)
            + 0.035 * np.sin(4 * ph))
    # amplitude envelope
    att = int(0.085 * SR)
    env = np.ones(n)
    env[:att] = rc_ramp(att)
    env *= 1.0 - dim * np.clip(t / max(dur, 1e-3), 0.0, 1.0)
    swell = 1.0 + 0.10 * np.sin(np.pi * np.clip(t / max(dur, 0.2), 0, 1))
    env *= swell
    env *= 1.0 + 0.35 * (vdepth / max(vib, 1e-6)) * 0.12 * vsin
    rn = n - int(dur * SR)
    env[-rn:] *= rc_ramp(rn)[::-1]
    # breath noise: broad airy band + narrow band at the pitch
    noise = rng.standard_normal(n)
    air = fft_filter(noise, lambda fr: 0.6 * bp_log(2.6 * f0, 1.3)(fr)
                     + 1.4 * bp_log(f0, 0.08)(fr))
    air /= np.abs(air).max() + 1e-12
    chiff = np.exp(-t / 0.045)
    chiff[:int(0.004 * SR)] *= rc_ramp(int(0.004 * SR))
    s = tone * env + breath * air * (0.9 * env + 0.8 * chiff)
    s[:att // 4] *= rc_ramp(att // 4)
    s[-rn:] *= rc_ramp(rn)[::-1] ** 0.5
    return vel * s / (np.abs(s).max() + 1e-12)


def taiko(rng, vel=1.0, f_hi=130.0, f_lo=52.0, decay=0.42):
    dur = 1.3
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.035)
    ph = TAU * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t / decay)
    body += 0.35 * np.sin(1.59 * ph + 0.5) * np.exp(-t / (decay * 0.35))
    body += 0.15 * np.sin(2.13 * ph + 1.2) * np.exp(-t / (decay * 0.2))
    nz = fft_filter(rng.standard_normal(n), lp(900.0, 2))
    nz /= np.abs(nz).max() + 1e-12
    s = body + 0.55 * nz * np.exp(-t / 0.018)
    s = np.tanh(1.3 * s)
    a = int(0.0015 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.08 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def shime(rng, vel=0.6):
    dur = 0.35
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 360.0 + 160.0 * np.exp(-t / 0.008)
    ph = TAU * np.cumsum(f) / SR
    body = (np.sin(ph) + 0.4 * np.sin(1.71 * ph)) * np.exp(-t / 0.065)
    nz = fft_filter(rng.standard_normal(n), bp_log(3200.0, 1.2))
    nz /= np.abs(nz).max() + 1e-12
    s = body + 0.7 * nz * np.exp(-t / 0.012)
    a = int(0.0008 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.03 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def hyoshigi(rng, vel=0.6):
    dur = 0.25
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for fr, g, d in ((1680, 1.0, 0.045), (2410, 0.6, 0.03), (3530, 0.45, 0.02),
                     (4870, 0.25, 0.012)):
        s += g * np.sin(TAU * fr * t + rng.uniform(0, TAU)) * np.exp(-t / d)
    nz = fft_filter(rng.standard_normal(n), hp(3000.0))
    s += 0.5 * nz / (np.abs(nz).max() + 1e-12) * np.exp(-t / 0.002)
    a = int(0.0006 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.02 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def temple_bell(rng, f0=146.83, vel=0.6, dur=9.0):
    """Bonshō-like bell: inharmonic partials, slow beating pairs, soft thud."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    parts = ((0.5, 0.7, 7.0), (1.0, 1.0, 5.0), (1.183, 0.45, 3.5), (1.506, 0.35, 2.8),
             (2.0, 0.3, 2.2), (2.514, 0.18, 1.6), (2.662, 0.14, 1.4), (3.011, 0.1, 1.0),
             (4.166, 0.05, 0.6))
    for r, g, d in parts:
        fr = f0 * r
        for det in (-0.18, 0.18):
            s += 0.5 * g * np.sin(TAU * (fr + det) * t + rng.uniform(0, TAU)) * np.exp(-t / d)
    nz = fft_filter(rng.standard_normal(n), lp(400.0, 2))
    s += 0.6 * nz / (np.abs(nz).max() + 1e-12) * np.exp(-t / 0.03)
    a = int(0.006 * SR)
    s[:a] *= rc_ramp(a)
    r = int(0.5 * SR)
    s[-r:] *= rc_ramp(r)[::-1]
    return vel * s / (np.abs(s).max() + 1e-12)


def drone_loop(n, notes, lfo_cycles=2, detune=0.35, phase=0.0, depth=0.25):
    """Sustained soft drone; every partial snapped to the loop length."""
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m, g in notes:
        f = mtof(m)
        for h, hg in ((1, 1.0), (2, 0.28), (3, 0.09)):
            for d in (-detune, detune):
                fr = snap(f * h + d, n)
                s += 0.5 * g * hg * np.sin(TAU * fr * t + 0.7 * h + d)
    lfo = 1.0 - depth + depth * np.sin(TAU * lfo_cycles * t / (n / SR) + phase)
    return s * lfo


def bird_chirp(rng, kind):
    if kind == 0:   # falling whistle
        dur = rng.uniform(0.06, 0.11)
        n = int(dur * SR); t = np.arange(n) / SR
        f0 = rng.uniform(4200, 5200); f1 = f0 * rng.uniform(0.55, 0.7)
        f = f0 * (f1 / f0) ** (t / dur)
    elif kind == 1:  # rising
        dur = rng.uniform(0.07, 0.12)
        n = int(dur * SR); t = np.arange(n) / SR
        f0 = rng.uniform(2600, 3200); f1 = f0 * rng.uniform(1.35, 1.6)
        f = f0 * (f1 / f0) ** (t / dur)
    else:            # warble / trill
        dur = rng.uniform(0.22, 0.38)
        n = int(dur * SR); t = np.arange(n) / SR
        f = rng.uniform(3500, 4200) + 550 * np.sin(TAU * rng.uniform(22, 32) * t)
    ph = TAU * np.cumsum(f) / SR
    env = np.sin(np.pi * t / dur) ** 2
    return (np.sin(ph) + 0.12 * np.sin(2 * ph)) * env


def cricket_pulse(fc, plen, rng):
    n = int(plen * SR)
    t = np.arange(n) / SR
    ph = rng.uniform(0, TAU)
    return (np.sin(TAU * fc * t + ph) + 0.18 * np.sin(TAU * 2 * fc * t)) * np.sin(np.pi * t / plen) ** 2


# --------------------------------------------------------------------------
# pieces
# --------------------------------------------------------------------------
# miyako-bushi on D:  D Eb G A Bb
D2, A2, D3, Eb3, G3, A3, Bb3 = 38, 45, 50, 51, 55, 57, 58
G2, Bb2 = 43, 46
D4, Eb4, G4, A4, Bb4 = 62, 63, 67, 69, 70
D5, Eb5, G5, A5, Bb5 = 74, 75, 79, 81, 82


def town_day():
    rng = np.random.default_rng(1101)
    bpm = 80.0
    beat = 60.0 / bpm
    bars = 8
    n = int(round(bars * 4 * beat * SR))
    bus = Bus(n, loop=True)

    chords = {"D": [D3, A3, D4, A4], "Bb": [Bb2, Bb3, D4, Eb4],
              "A": [A2, A3, D4, Eb4], "G": [G2, G3, D4, G4]}
    prog = ["D", "D", "Bb", "A", "D", "G", "Bb", "A"]
    pat = [0, 1, 2, 1, 3, 2, 1, 2]
    pvel = [0.85, 0.45, 0.6, 0.45, 0.7, 0.5, 0.55, 0.45]
    for b, ch in enumerate(prog):
        tones = chords[ch]
        for e in range(8):
            if ch == "A" and e in (6, 7) and b == 7:
                continue                      # breathe before the loop point
            if ch == "A" and e == 7:
                continue
            t0 = (b * 4 + e * 0.5) * beat + rng.uniform(-0.006, 0.006)
            m = tones[pat[e]]
            v = pvel[e] * rng.uniform(0.9, 1.05)
            p = -0.35 + 0.08 * pat[e]
            bus.add(t0, koto(rng, mtof(m), v), p, gain=0.55, send=0.25)
        if b >= 4:  # second half: high answering pluck
            t0 = (b * 4 + 2.5) * beat
            bus.add(t0, koto(rng, mtof(tones[3] + 12), 0.4), 0.45, gain=0.35, send=0.35)
    # soft warm drone (D3/A3), very low
    bus.add_stereo(0, pan(drone_loop(n, [(D3, 1.0), (A3, 0.6)], lfo_cycles=1), 0.0) * 0.035,
                   send=0.2)

    # shakuhachi melody (midi, start beat, beats, extra)
    mel = [
        (A4, 1.0, 1.0), (Bb4, 2.0, 0.5), (D5, 2.5, 1.5),
        (Eb5, 4.0, 1.0), (D5, 5.0, 0.5), (Bb4, 5.5, 0.5), (A4, 6.0, 2.0, 0.6),
        (G4, 8.5, 0.5), (A4, 9.0, 1.0), (Bb4, 10.0, 1.0), (A4, 11.0, 0.5), (G4, 11.5, 0.5),
        (D4, 12.0, 3.0, 0.0),
        (D5, 17.0, 1.0), (Eb5, 18.0, 0.5), (G5, 18.5, 1.5),
        (A5, 20.0, 1.5), (G5, 21.5, 0.5), (Eb5, 22.0, 1.0), (D5, 23.0, 1.0),
        (Bb4, 24.5, 0.5), (D5, 25.0, 1.0), (A4, 26.0, 2.0, 0.7),
        (A4, 28.0, 0.5), (G4, 28.5, 0.5), (D4, 29.0, 2.0, 0.0),
    ]
    for item in mel:
        m, sb, db = item[:3]
        fall = item[3] if len(item) > 3 else 0.0
        scoop = 0.8 if db >= 1.0 else 0.35
        sig = shakuhachi(rng, mtof(m), db * beat * 0.97, vel=0.62, scoop=scoop,
                         fall=fall, vib=0.3 if db >= 1.0 else 0.0)
        bus.add(sb * beat, sig, 0.18, gain=0.62, send=0.4)

    ir = make_ir(np.random.default_rng(77), rt60=2.0)
    x = apply_reverb(bus, ir, wet=0.55)
    x, r = best_rotation(x, center=0, radius=int(beat * SR), step=64)
    return finish_music(x), dict(bpm=bpm, rot=r)


def town_night():
    rng = np.random.default_rng(2202)
    bpm = 64.0
    beat = 60.0 / bpm
    n = int(round(32 * beat * SR))
    bus = Bus(n, loop=True)
    # drone breathes twice per loop; its quietest point sits at the loop seam
    dr = drone_loop(n, [(D2, 1.0), (A2, 0.55), (D3, 0.25)], lfo_cycles=2, detune=0.25,
                    phase=-np.pi / 2, depth=0.4)
    dr2 = drone_loop(n, [(D2, 1.0), (A2, 0.55), (D3, 0.25)], lfo_cycles=2, detune=0.3,
                     phase=-np.pi / 2 + 0.3, depth=0.4)
    bus.add_stereo(0, np.stack([dr, dr2], axis=1) * 0.08, send=0.3)
    notes = [(D4, 0.5, 0.6), (A3, 3.0, 0.5), (Eb4, 6.0, 0.55), (D4, 7.0, 0.4),
             (G3, 10.0, 0.5), (Bb3, 13.0, 0.5), (A3, 14.5, 0.45),
             (D4, 18.5, 0.6), (Eb4, 20.0, 0.5), (A3, 23.0, 0.5),
             (Bb3, 26.0, 0.5), (A3, 27.5, 0.45), (G3, 29.0, 0.4)]
    for i, (m, sb, v) in enumerate(notes):
        p = -0.4 if i % 2 == 0 else 0.35
        bus.add(sb * beat, koto(rng, mtof(m), v, bright=0.7, tau1=2.0), p, gain=0.6, send=0.7)
        if i in (0, 7):  # fourth below as a quiet dyad
            bus.add(sb * beat + 0.03, koto(rng, mtof(m - 5), v * 0.6, bright=0.6, tau1=2.0),
                    -p, gain=0.5, send=0.7)
    for sb in (8.5, 24.5):
        bus.add(sb * beat, temple_bell(rng, mtof(D3), 0.55), 0.05, gain=0.5, send=0.6)
    # one distant breathy shakuhachi phrase
    for m, sb, db, fall in ((Bb4, 11.0, 2.5, 0.0), (A4, 13.5, 3.0, 0.5)):
        sig = shakuhachi(rng, mtof(m), db * beat, vel=0.5, scoop=0.9, breath=0.35, fall=fall)
        bus.add(sb * beat, sig, 0.3, gain=0.35, send=0.9)
    ir = make_ir(np.random.default_rng(78), rt60=3.2, length=3.6, damp=2400.0)
    x = apply_reverb(bus, ir, wet=0.65)
    x, r = best_rotation(x, center=0, radius=int(beat * SR), step=64)
    return finish_music(x, drive=1.6), dict(bpm=bpm, rot=r)


def duel():
    rng = np.random.default_rng(3303)
    bpm = 132.0
    beat = 60.0 / bpm
    st = beat / 4.0
    bars = 12
    n = int(round(bars * 4 * beat * SR))
    bus = Bus(n, loop=True)

    def hit(bar, step, sig, p, g, send):
        t0 = (bar * 16 + step) * st + rng.uniform(-0.003, 0.003)
        bus.add(t0, sig, p, gain=g, send=send)

    for b in range(bars):
        fill = (b % 4 == 3)
        big = [(0, 1.0), (3, 0.6), (8, 0.9), (10, 0.7)]
        if fill:
            big = [(0, 1.0), (3, 0.6), (8, 0.85), (10, 0.7), (12, 0.6), (13, 0.7),
                   (14, 0.8), (15, 0.9)]
        for s_, v in big:
            hit(b, s_, taiko(rng, v * rng.uniform(0.92, 1.0)), 0.0, 0.9, 0.2)
        for s_ in range(0, 16, 2):
            v = 0.55 if s_ % 4 == 0 else 0.32
            hit(b, s_, shime(rng, v * rng.uniform(0.9, 1.05)), -0.35, 0.6, 0.12)
        for s_ in (7, 15):
            hit(b, s_, shime(rng, 0.18), -0.35, 0.6, 0.12)
        if b % 2 == 1:
            hit(b, 12, hyoshigi(rng, 0.55), 0.3, 0.45, 0.25)
        if b == bars - 1:
            hit(b, 14, hyoshigi(rng, 0.65), 0.3, 0.45, 0.25)

    rA = {0: D3, 3: D3, 4: Eb3, 6: D3, 8: A3, 10: Bb3, 11: A3, 12: G3, 14: A3}
    rA2 = {0: D3, 3: D3, 4: Eb3, 6: D3, 8: A3, 10: Bb3, 11: A3, 12: D4, 14: Eb4}
    rT = {0: D3, 2: Eb3, 4: G3, 6: A3, 8: Bb3, 10: A3, 12: Eb3, 14: D3}
    rB = {0: Bb3, 2: A3, 3: G3, 4: A3, 8: Eb3, 10: D3, 11: Eb3, 12: G3, 14: A3}
    up = lambda r: {k: v + 12 for k, v in r.items()}
    riffs = [rA, rA2, rA, rT, up(rA), up(rA2), rA, rT, rB, rB, up(rB), rT]
    for b, riff in enumerate(riffs):
        for s_, m in riff.items():
            acc = 0.9 if s_ in (0, 8) else 0.65
            hit(b, s_, shamisen(rng, mtof(m), acc * rng.uniform(0.9, 1.05)), 0.32, 0.5, 0.15)
    # low tension drone (D2 + Eb2 cluster rumble), very soft
    bus.add_stereo(0, pan(drone_loop(n, [(D2, 1.0), (A2, 0.4)], lfo_cycles=6), 0.0) * 0.04,
                   send=0.0)
    ir = make_ir(np.random.default_rng(79), rt60=1.2, length=1.6)
    x = apply_reverb(bus, ir, wet=0.45)
    x, r = best_rotation(x, center=0, radius=int(2 * beat * SR), step=32)
    return finish_music(x, drive=1.4), dict(bpm=bpm, rot=r)


def ending():
    rng = np.random.default_rng(4404)
    bpm = 60.0
    beat = 60.0 / bpm
    total = 23.0
    n = int(total * SR)
    bus = Bus(n, loop=False)
    t = np.arange(n) / SR
    dr = np.zeros(n)
    for m, g in ((D2, 1.0), (A2, 0.5), (D3, 0.2)):
        for h, hg in ((1, 1.0), (2, 0.25), (3, 0.08)):
            for d in (-0.2, 0.2):
                dr += 0.5 * g * hg * np.sin(TAU * (mtof(m) * h + d) * t + h)
    denv = np.clip(t / 2.5, 0, 1) ** 2 * np.clip((20.5 - t) / 5.0, 0, 1) ** 1.5
    bus.add(0, dr * denv * 0.07, 0.0, send=0.3)
    for sb, chord in ((0.5, [D3, A3, D4]), (8.0, [Bb2, Bb3, D4]), (13.0, [G2, D4, G4]),
                      (16.5, [D3, A3, D4, A4])):
        for i, m in enumerate(chord):
            bus.add(sb * beat + i * 0.09, koto(rng, mtof(m), 0.45, bright=0.7, tau1=2.0),
                    -0.3 + 0.2 * i, gain=0.5, send=0.5)
    mel = [(A4, 1.5, 2.0, 0.0), (Bb4, 3.5, 0.75, 0.0), (A4, 4.25, 0.75, 0.0),
           (G4, 5.0, 1.6, 0.4),
           (D5, 7.0, 1.5, 0.0), (Eb5, 8.5, 0.5, 0.0), (D5, 9.0, 1.0, 0.0),
           (Bb4, 10.0, 1.0, 0.0), (A4, 11.0, 2.0, 0.6),
           (G4, 13.5, 1.0, 0.0), (A4, 14.5, 0.5, 0.0), (Eb4, 15.0, 1.5, 0.0),
           (D4, 16.5, 3.8, 0.0)]
    for m, sb, db, fall in mel:
        last = (m == D4 and sb > 16)
        sig = shakuhachi(rng, mtof(m), db * beat, vel=0.65, scoop=0.8 if db >= 1 else 0.4,
                         fall=fall, vib=0.32, dim=0.6 if last else 0.15,
                         rel=0.8 if last else 0.22)
        bus.add(sb * beat, sig, 0.12, gain=0.7, send=0.45)
    ir = make_ir(np.random.default_rng(80), rt60=2.6, length=3.0)
    x = apply_reverb(bus, ir, wet=0.55)
    x = x - x.mean(axis=0)
    fi = int(0.010 * SR)
    x[:fi] *= rc_ramp(fi)[:, None]
    fo = int(2.5 * SR)
    x[-fo:] *= (rc_ramp(fo)[::-1] ** 1.5)[:, None]
    return finish_music(x), dict(bpm=bpm)


def wind_bed(rng, n, level=1.0, gust_fc=0.12):
    ch = []
    g1 = circ_smooth_noise(rng, n, gust_fc)
    g2 = circ_smooth_noise(rng, n, gust_fc * 1.7)
    for c in range(2):
        low = fft_filter(rng.standard_normal(n), lambda f: lp(420.0, 2)(f) * hp(60.0, 2)(f))
        whis = fft_filter(rng.standard_normal(n), bp_log(780.0 + 120 * c, 0.35))
        low /= np.abs(low).std()
        whis /= np.abs(whis).std()
        e1 = (0.55 + 0.45 * g1) ** 1.6
        e2 = np.clip(0.45 + 0.55 * g2, 0, 1) ** 2.0
        ch.append(level * (0.8 * low * e1 + 0.25 * whis * e2))
    return np.stack(ch, axis=1)


def stream_bed(rng, n, level=1.0, distant=True):
    ch = []
    for c in range(2):
        nz = rng.standard_normal(n)
        hi = fft_filter(nz, lambda f: bp_log(1500.0, 1.0)(f)
                        * (lp(2500.0, 2)(f) if distant else 1.0))
        bub = fft_filter(rng.standard_normal(n), bp_log(450.0, 0.6))
        hi /= hi.std(); bub /= bub.std()
        m1 = 0.6 + 0.4 * circ_smooth_noise(rng, n, 7.0)
        m2 = 0.5 + 0.5 * circ_smooth_noise(rng, n, 4.0)
        ch.append(level * (0.6 * hi * m1 + 0.4 * bub * m2))
    return np.stack(ch, axis=1)


def amb_day():
    rng = np.random.default_rng(5505)
    n = 20 * SR
    bus = Bus(n, loop=True)
    bus.add_stereo(0, wind_bed(rng, n, 1.0), send=0.0)
    bus.add_stereo(0, stream_bed(rng, n, 0.22, distant=True), send=0.0)
    nb = 8
    starts = np.sort(rng.uniform(0, 20, nb))
    for s0 in starts:
        kind = int(rng.integers(0, 3))
        p = rng.uniform(-0.8, 0.8)
        amp = rng.uniform(0.9, 2.2)
        tt = s0
        for _ in range(int(rng.integers(2, 6))):
            c = bird_chirp(rng, kind if rng.uniform() < 0.8 else int(rng.integers(0, 3)))
            bus.add(tt, c, p, gain=amp, send=0.5)
            tt += len(c) / SR + rng.uniform(0.06, 0.2)
    ir = make_ir(np.random.default_rng(81), rt60=0.9, length=1.2, damp=5000.0)
    x = apply_reverb(bus, ir, wet=0.35)
    x = finish_amb(x, -27.0)
    x, r = best_rotation(x, step=128)
    return x, dict(rot=r)


def amb_night():
    rng = np.random.default_rng(6606)
    n = 20 * SR
    L = n / SR
    bus = Bus(n, loop=True)
    bus.add_stereo(0, wind_bed(rng, n, 0.35, gust_fc=0.08), send=0.0)
    bus.add_stereo(0, stream_bed(rng, n, 0.30, distant=False), send=0.0)
    # insect A: 3-pulse chirps
    k = 36
    for i in range(k):
        t0 = i * L / k + rng.uniform(-0.01, 0.01)
        a = rng.uniform(0.7, 1.0)
        for j in range(3):
            bus.add(t0 + j * 0.032, cricket_pulse(4400.0, 0.014, rng), -0.5, gain=0.6 * a, send=0.3)
    # insect B: long trills with gaps
    k = 7
    for i in range(k):
        t0 = i * L / k + 0.4
        npul = int(1.6 / 0.022)
        for j in range(npul):
            sw = np.sin(np.pi * j / npul) ** 0.5
            bus.add(t0 + j * 0.022, cricket_pulse(5100.0, 0.010, rng), 0.45,
                    gain=0.32 * sw * rng.uniform(0.85, 1.0), send=0.3)
    # insect C: distant slow double chirps
    k = 22
    for i in range(k):
        t0 = i * L / k + 0.2 + rng.uniform(-0.015, 0.015)
        for j in range(2):
            bus.add(t0 + j * 0.045, cricket_pulse(3700.0, 0.02, rng), 0.1, gain=0.2, send=0.7)
    ir = make_ir(np.random.default_rng(82), rt60=1.4, length=1.8, damp=6000.0)
    x = apply_reverb(bus, ir, wet=0.4)
    x = finish_amb(x, -27.0)
    x, r = best_rotation(x, step=128)
    return x, dict(rot=r)


def main():
    for name, fn in (("town_day.wav", town_day), ("town_night.wav", town_night),
                     ("duel.wav", duel), ("ending.wav", ending),
                     ("amb_day.wav", amb_day), ("amb_night.wav", amb_night)):
        x, info = fn()
        write_wav(name, x)
        print("   ", info)


if __name__ == "__main__":
    main()
