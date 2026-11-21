# Plot spectrogram + per-second features + caption references. Usage: plot.py prefix [t0 t1 minutes]
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

p = sys.argv[1]
d = np.load(p + ".npz"); S = np.load(p + "-spec.npy")
t0, t1 = (float(sys.argv[2]) * 60, float(sys.argv[3]) * 60) if len(sys.argv) > 3 else (0, S.shape[1])
sl = slice(int(t0), int(t1)); t = np.arange(S.shape[1])[sl] / 60
med = lambda v, k=9: np.array([np.median(v[max(0, i - k // 2): i + k // 2 + 1]) for i in range(len(v))])

rows = [("lef", "lae-energie-rame"), ("mod4", "4 Hz-modulasie"), ("flux", "flux (log)"),
        ("flat", "platheid"), ("low", "40-150 Hz-aandeel"), ("db", "dB")]
fig, ax = plt.subplots(len(rows) + 2, 1, figsize=(22, 2 * (len(rows) + 2)), sharex=True)
ax[0].imshow(S[:, sl], aspect="auto", origin="lower", extent=[t[0], t[-1], 0, 4000], cmap="magma",
             vmin=np.percentile(S, 5), vmax=np.percentile(S, 99.5))
ax[0].set_ylabel("Hz")
ref = ax[1]
ref.fill_between(t, 0, d["yt_music"][sl], color="tab:orange", alpha=.5, step="mid", label="YT [musiek]")
ref.plot(t, np.minimum(d["words"][sl], 6) / 6, lw=.6, color="k", label="woorde/s (YT)")
ref.legend(loc="upper right"); ref.set_ylabel("verw.")
for a, (k, name) in zip(ax[2:], rows):
    a.plot(t, d[k][sl], lw=.4, color="0.6"); a.plot(t, med(d[k])[sl], lw=1.2, color="tab:blue")
    a.set_ylabel(name, fontsize=9)
for a in ax:
    a.grid(axis="x", alpha=.3)
ax[-1].set_xlabel("minute")
ax[-1].xaxis.set_major_locator(matplotlib.ticker.MultipleLocator(5 if t1 - t0 > 1200 else 1))
plt.tight_layout(); plt.savefig(p + (f"-{int(t0/60)}-{int(t1/60)}" if len(sys.argv) > 3 else "") + ".png", dpi=70)
