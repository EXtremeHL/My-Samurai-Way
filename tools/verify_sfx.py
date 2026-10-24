"""Measures every generated SFX and fails loudly on bad files.

    uv run --with numpy python tools/verify_sfx.py
"""
import glob
import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "audio", "sfx")


def load(path):
    with wave.open(path) as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float) / 32768
    return x.reshape(-1, ch).mean(axis=1), sr, ch


def centroid(x, sr):
    n = 4096
    if len(x) < n:
        x = np.pad(x, (0, n - len(x)))
    win = np.hanning(n)
    total, wsum = 0.0, 0.0
    for s in range(0, len(x) - n + 1, n // 2):
        fr = x[s:s + n] * win
        if np.max(np.abs(fr)) < 0.01:
            continue
        mag = np.abs(np.fft.rfft(fr)) ** 2          # power-weighted centroid
        f = np.fft.rfftfreq(n, 1 / sr)
        e = mag.sum()
        if e > 0:
            total += (mag * f).sum()
            wsum += e
    return total / wsum if wsum else 0.0


def main():
    rows, bad = [], []
    files = sorted(glob.glob(os.path.join(DIR, "*.wav")))
    for p in files:
        x, sr, ch = load(p)
        name = os.path.basename(p)[:-4]
        peak = float(np.max(np.abs(x)))
        rms = float(np.sqrt(np.mean(x ** 2)))
        rms_db = 20 * np.log10(rms + 1e-9)
        c = centroid(x, sr)
        row = (name, len(x) / sr, peak, rms_db, abs(x[0]), abs(x[-1]), c)
        rows.append(row)
        if peak > 0.99:
            bad.append(name + ": clipped")
        if peak < 0.05:
            bad.append(name + ": silent")
        if abs(x[0]) > 0.02 or abs(x[-1]) > 0.02:
            bad.append(name + ": click at the edges")
        if sr != 44100 or ch != 1:
            bad.append(name + ": format")
    d = {r[0]: r for r in rows}
    # sanity on timbre: heavy things must be darker than light ones
    pairs = [("slash_heavy", "slash_light"), ("hit_heavy", "hit"), ("ko", "clash"), ("bell", "ui_move"),
             ("step_1", "slash_light"), ("ko", "hit")]
    for dark, bright in pairs:
        if dark in d and bright in d and not d[dark][6] < d[bright][6]:
            bad.append(f"{dark} ({d[dark][6]:.0f} Hz) should be darker than {bright} ({d[bright][6]:.0f} Hz)")
    out = [f"{'file':14s} {'dur':>5s} {'peak':>5s} {'rmsdB':>6s} {'|first|':>7s} {'|last|':>6s} {'centroid':>8s}"]
    for r in rows:
        out.append(f"{r[0]:14s} {r[1]:5.2f} {r[2]:5.2f} {r[3]:6.1f} {r[4]:7.4f} {r[5]:6.4f} {r[6]:8.0f}")
    out.append(f"\n{len(rows)} files, {len(bad)} problems")
    out.extend("  PROBLEM: " + b for b in bad)
    text = "\n".join(out)
    print(text)
    with open(os.path.join(DIR, "_AUDIO_REPORT.txt"), "w", encoding="utf-8") as f:
        f.write(text + "\n")
    sys.exit(1 if bad or not rows else 0)


if __name__ == "__main__":
    main()
