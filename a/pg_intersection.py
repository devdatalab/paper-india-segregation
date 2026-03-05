# ------------------------------------------
# interaction_coefplots.py
# ------------------------------------------
import os, shutil
import io
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import textwrap
from set_paths import OUT, TMP

# ----------- config -----------
INFILE = TMP / "intersection_ests.csv"
OUTDIR = OUT
os.makedirs(OUTDIR, exist_ok=True)

# canonical service tokens and display names
SERVICE_ORDER = ["prim", "sec", "hosp", "water", "elec", "drain"]
SERVICE_LABELS = {
    "prim": "Primary School",
    "sec": "Secondary School",
    "hosp": "Health Clinic",
    "water": "Piped Water",
    "elec": "Electric Light",
    "drain": "Covered Sewerage",
}

GROUPS = ["muslim_share", "sc_share"]  # as present in CSV
GROUP_LABELS = {
    "muslim_share": "Muslim Share",
    "sc_share": "SC Share",
}

# ----------- load -----------
if not os.path.exists(INFILE):
    raise FileNotFoundError(INFILE)

# CSV schema: service, group, bin, beta, se (no header)
cols = ["service", "group", "bin", "beta", "se"]
df = pd.read_csv(INFILE, header=None, names=cols)

# coerce numeric
for c in ["bin", "beta", "se"]:
    df[c] = pd.to_numeric(df[c], errors="coerce")

# normalize service tokens just in case
df["service"] = df["service"].str.strip().str.lower()
df["group"] = df["group"].str.strip().str.lower()

# ----------- plotting helper -----------
def plot_one(dsub: pd.DataFrame, service: str, group: str):
    if dsub.empty:
        print(f"[WARN] Empty subset for service={service}, group={group}")
        return

    dsub = dsub.sort_values("bin")

    fig_h = max(3.5, 0.35 * max(10, dsub["bin"].nunique()))
    fig, ax = plt.subplots(figsize=(6.0, fig_h))

    ax.axvline(0, color="black", lw=0.8, zorder=1)

    ci = 1.96 * dsub["se"].to_numpy()
    ax.errorbar(
        dsub["beta"].to_numpy(),
        dsub["bin"].to_numpy(),
        xerr=ci,
        fmt="o",
        ms=4,
        capsize=3,
        color="C0",
        zorder=2,
    )

    # y axis: 1..10, top to bottom
    bins = sorted(dsub["bin"].unique())
    ax.set_yticks(bins)
    ax.set_yticklabels([str(b) for b in bins], fontsize=10)
    ax.invert_yaxis()

    # dynamic axis labels
    if group == "muslim_share":
        ax.set_xlabel("Muslim Share Coefficient", fontsize=11)
        ax.set_ylabel("SC Share Bin", fontsize=11)
    elif group == "sc_share":
        ax.set_xlabel("SC Share Coefficient", fontsize=11)
        ax.set_ylabel("Muslim Share Bin", fontsize=11)

    # x limits: padded
    xmin = np.nanmin(dsub["beta"].to_numpy() - ci)
    xmax = np.nanmax(dsub["beta"].to_numpy() + ci)
    pad = 0.08 * (xmax - xmin if np.isfinite(xmax - xmin) and xmax != xmin else 1.0)
    if not np.isfinite(xmin): xmin = -0.1
    if not np.isfinite(xmax): xmax = 0.1
    ax.set_xlim(xmin - pad, xmax + pad)

    # light vertical guides
    xr = ax.get_xlim()
    grid_step = (xr[1] - xr[0]) / 6.0
    ticks = np.arange(xr[0] + grid_step, xr[1], grid_step)
    for x in ticks:
        ax.axvline(x, ls="--", lw=0.6, color="lightgray", zorder=0)

    fig.tight_layout()

    out_path = OUTDIR / f"pg_interaction_coefplot_{service}_{group}.pdf"
    fig.savefig(out_path, bbox_inches="tight")

    plt.close(fig)


# ----------- generate 12 plots -----------
df = df[df["service"].isin(SERVICE_ORDER) & df["group"].isin(GROUPS)]

for service in SERVICE_ORDER:
    for group in GROUPS:
        sub = df[(df["service"] == service) & (df["group"] == group)]
        plot_one(sub, service, group)
