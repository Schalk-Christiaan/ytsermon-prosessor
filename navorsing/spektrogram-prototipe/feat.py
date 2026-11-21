# Prototype: speech vs music from the spectrogram. Usage: feat.py a.raw captions.json3 out-prefix
import json, sys
import numpy as np

SR, HOP, WIN = 16000, 160, 400  # 10 ms hop, 25 ms window
raw, cap, out = sys.argv[1:4]
x = np.fromfile(raw, dtype=np.int16).astype(np.float32) / 32768
n = (len(x) - WIN) // HOP
frames = np.lib.stride_tricks.as_strided(x, (n, WIN), (x.strides[0] * HOP, x.strides[0]))
spec = np.abs(np.fft.rfft(frames * np.hanning(WIN), 512)).astype(np.float32)  # (n, 257), 31.25 Hz bins
freqs = np.fft.rfftfreq(512, 1 / SR)

rms = np.sqrt((frames**2).mean(1))
power = spec**2 + 1e-12
flat = np.exp(np.log(power[:, 3:128]).mean(1)) / power[:, 3:128].mean(1)  # 100-4000 Hz
low = power[:, (freqs >= 40) & (freqs < 150)].sum(1) / power[:, (freqs >= 40) & (freqs < 4000)].sum(1)
nspec = spec / (spec.sum(1, keepdims=True) + 1e-9)
flux = np.r_[0, (np.diff(nspec, axis=0).clip(0) ** 2).sum(1)]

# per-second features over a 2 s window (200 frames), centered
secs = n // 100
def win(i):
    a = max(0, i * 100 - 50); return slice(a, min(n, a + 200))
F = {k: np.zeros(secs) for k in ["lef", "mod4", "flux", "flat", "low", "db"]}
for i in range(secs):
    s = win(i); r = rms[s]
    F["db"][i] = 20 * np.log10(r.mean() + 1e-9)
    F["lef"][i] = (r < 0.5 * r.mean()).mean()  # low-energy frame ratio
    env = r - r.mean()
    m = np.abs(np.fft.rfft(env * np.hanning(len(env)))) ** 2
    mf = np.fft.rfftfreq(len(env), 0.01)
    F["mod4"][i] = m[(mf >= 2) & (mf <= 8)].sum() / (m[(mf > 0.5) & (mf <= 20)].sum() + 1e-12)
    F["flux"][i] = np.log10(flux[s].mean() + 1e-9)
    F["flat"][i] = flat[s].mean()
    F["low"][i] = low[s].mean()

# captions: words per second and YouTube's music tags
ev = json.load(open(cap))["events"]
words = np.zeros(secs); yt_music = np.zeros(secs)
for e in ev:
    if "segs" not in e: continue
    t0 = e["tStartMs"] / 1000
    txt = "".join(s.get("utf8", "") for s in e["segs"]).strip().lower()
    if not txt: continue
    if txt.startswith("[") and ("musiek" in txt or "sang" in txt):
        a, b = int(t0), int(t0 + e.get("dDurationMs", 0) / 1000)
        yt_music[a:min(b + 1, secs)] = 1
        continue
    for s in e["segs"]:
        t = int(t0 + s.get("tOffsetMs", 0) / 1000)
        if t < secs and s.get("utf8", "").strip(): words[t] += 1

np.savez(out + ".npz", words=words, yt_music=yt_music, **F)
# downsampled log spectrogram (1 col per second, 0-4 kHz) for the plot
S = np.log10(power[: secs * 100, :128].reshape(secs, 100, 128).mean(1)).T
np.save(out + "-spec.npy", S.astype(np.float32))
print("seconds", secs)
