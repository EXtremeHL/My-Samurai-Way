"""Verify the generated music/ambience WAVs and write _AUDIO_REPORT.txt.

    uv run --with numpy python tools/verify_music.py

Exit code 1 on any failure.
"""
from __future__ import annotations

import os
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "audio", "music")

# name: (is_loop, min_s, max_s, seam_limit, rms_lo, rms_hi)
SPEC = {
    "town_day.wav":   (True, 24, 32, 0.06, -22.0, -14.0),
    "town_night.wav": (True, 24, 32, 0.06, -26.0, -14.0),
    "duel.wav":       (True, 16, 24, 0.06, -22.0, -14.0),
    "ending.wav":     (False, 15, 25, None, -26.0, -14.0),
    "amb_day.wav":    (True, 19, 21, 0.03, -31.0, -23.0),
    "amb_night.wav":  (True, 19, 21, 0.03, -31.0, -23.0),
}


def read(path):
    with wave.open(path, "rb") as w:
        ch, sw, sr, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    return x.reshape(-1, ch), ch, sw, sr


def centroid(mono, sr, N=4096, hop=2048):
    win = np.hanning(N)
    freqs = np.fft.rfftfreq(N, 1.0 / sr)
    num = den = 0.0
    for i in range(0, len(mono) - N, hop):
        fr = mono[i:i + N]
        if np.sqrt(np.mean(fr ** 2)) < 1e-4:
            continue
        mag = np.abs(np.fft.rfft(fr * win))
        num += (freqs * mag).sum()
        den += mag.sum()
    return num / den if den else 0.0


def main():
    rows, fails = [], []
    hdr = (f"{'file':15s} {'dur_s':>6s} {'ch':>2s} {'peak':>6s} {'rms_dB':>7s} "
           f"{'|first|':>8s} {'|last|':>8s} {'clip':>4s} {'silent':>6s} "
           f"{'seamL':>7s} {'seamR':>7s} {'edgeL/R_dB':>11s} {'cent_Hz':>8s} {'MB':>5s} status")
    for name, (loop, lo, hi, seam_lim, rlo, rhi) in SPEC.items():
        path = os.path.join(DIR, name)
        if not os.path.exists(path):
            fails.append(f"{name}: missing")
            continue
        x, ch, sw, sr = read(path)
        dur = len(x) / sr
        peak = np.abs(x).max()
        rms_db = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
        first, last = np.abs(x[0]).max(), np.abs(x[-1]).max()
        clip, silent = peak > 0.99, peak < 0.05
        mb = os.path.getsize(path) / 1e6
        prob = []
        if ch != 2 or sw != 2 or sr != 44100:
            prob.append("format")
        if not (lo <= dur <= hi):
            prob.append("duration")
        if clip:
            prob.append("clipped")
        if silent:
            prob.append("silent")
        if not (rlo <= rms_db <= rhi):
            prob.append(f"rms outside {rlo}..{rhi}")
        if mb > 6.0:
            prob.append("size")
        seam = ("-", "-")
        edge = "-"
        if loop:
            w = 1024
            mad = np.abs(x[-w:] - x[:w]).mean(axis=0)
            seam = (f"{mad[0]:.4f}", f"{mad[1]:.4f}")
            if mad.max() > seam_lim:
                prob.append(f"seam>{seam_lim}")
            e1 = 20 * np.log10(np.sqrt(np.mean(x[-w:] ** 2)) + 1e-12)
            e2 = 20 * np.log10(np.sqrt(np.mean(x[:w] ** 2)) + 1e-12)
            edge = f"{e1:.0f}/{e2:.0f}"
        else:
            if first > 0.01 or last > 0.01:
                prob.append("non-zero ends")
        cent = centroid(x.mean(axis=1), sr)
        status = "OK" if not prob else "FAIL: " + ", ".join(prob)
        if prob:
            fails.append(f"{name}: {status}")
        rows.append(f"{name:15s} {dur:6.2f} {ch:2d} {peak:6.3f} {rms_db:7.1f} "
                    f"{first:8.4f} {last:8.4f} {str(clip)[0]:>4s} {str(silent)[0]:>6s} "
                    f"{seam[0]:>7s} {seam[1]:>7s} {edge:>11s} {cent:8.0f} {mb:5.2f} {status}")
    notes = ["", "seamL/R = mean |x[-1024+i] - x[i]| per channel (loop files; limit 0.06 music, "
             "0.03 ambience)", "edgeL/R_dB = RMS of last / first 1024 frames",
             "cent_Hz = spectral centroid, Hann 4096 frames hop 2048, mono mix"]
    report = "\n".join([hdr] + rows + notes + ([""] + fails if fails else ["", "ALL OK"]))
    print(report)
    with open(os.path.join(DIR, "_AUDIO_REPORT.txt"), "w", encoding="utf-8") as f:
        f.write(report + "\n")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
