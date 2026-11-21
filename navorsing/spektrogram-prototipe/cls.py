# Classify each second: stilte / musiek / spraak / geraas, smooth, merge short runs, print segments.
import sys, numpy as np
d = np.load(sys.argv[1] + ".npz")
med = lambda v, k=9: np.array([np.median(v[max(0, i-k//2): i+k//2+1]) for i in range(len(v))])
lef, flat, db = med(d["lef"]), med(d["flat"]), med(d["db"])
lab = np.where(db < -60, "stilte", np.where(lef >= 0.15, "spraak", np.where(flat < 0.06, "musiek", "geraas")))
# merge runs shorter than 10 s into the previous run
runs = []
for i, l in enumerate(lab):
    if runs and runs[-1][2] == l: runs[-1][1] = i + 1
    else: runs.append([i, i + 1, l])
out = []
for r in runs:
    if out and (r[1] - r[0] < 10 or out[-1][2] == r[2]): out[-1][1] = r[1]
    else: out.append(r)
mm = lambda s: f"{s//60:2d}:{s%60:02d}"
for a, b, l in out:
    yt = d["yt_music"][a:b].mean(); w = d["words"][a:b].sum() / (b - a)
    print(f"{mm(a)}-{mm(b)}  {l:7s} {b-a:5d}s  YT-musiek {yt:4.0%}  woorde/s {w:.1f}")
np.save(sys.argv[1] + "-lab.npy", np.array([l for a, b, l in out for _ in range(b - a)]))
