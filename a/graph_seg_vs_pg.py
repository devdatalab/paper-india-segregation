# ------------------------------------------
# quartile_coefplots.py
# ------------------------------------------
import pandas as pd
import matplotlib.pyplot as plt
import os
from set_paths import OUT, TMP

# ----------- config -----------
INFILE = TMP / "pg_by_seg.dta"
OUTDIR = OUT
os.makedirs(OUTDIR, exist_ok=True)

OUTFILES = {
    "quartiles_sc_dissim": OUTDIR / "quartiles_sc_dissim.pdf",
    "quartiles_sc_iso":    OUTDIR / "quartiles_sc_iso.pdf",
    "quartiles_muslim_dissim": OUTDIR / "quartiles_muslim_dissim.pdf",
    "quartiles_muslim_iso":    OUTDIR / "quartiles_muslim_iso.pdf",
}

# display names
SERVICE_LABELS = {
    "prim": "Primary School",
    "sec": "Secondary School",
    "hosp": "Health Clinic",
    "sewer": "Covered Drainage",
    "elec": "Electric Light",
    "water": "Clean Water",
}

# ----------- read and prep -----------
df = pd.read_stata(INFILE)

# clean types
df["beta"] = pd.to_numeric(df["beta"], errors="coerce")
df["se"] = pd.to_numeric(df["se"], errors="coerce")

# build a label for selection
df["key"] = df["group"] + "_" + df["measure"]  # e.g. "muslim_dissim"

# ----------- plotting -----------
def plot_quartiles(dfsub, title, outfile):
    services = list(SERVICE_LABELS.keys())
    service_labels = [SERVICE_LABELS[s] for s in services]
    n_services = len(services)

    fig, ax = plt.subplots(figsize=(6, n_services * 1.2))

    ypos_map = {s: (i * 6) for i, s in enumerate(services)}  # row spacing
    x_offsets = [-1.5, -0.5, 0.5, 1.5]                       # one per quartile
    labels = ["Q1", "Q2", "Q3", "Q4"]
    color = "C0"

    for _, row in dfsub.iterrows():
        service = row["pg"]
        q = int(row["quartile"]) - 1
        if service not in ypos_map or not pd.notna(row["beta"]):
            continue
        y = ypos_map[service] + x_offsets[q]
        ax.errorbar(row["beta"], y,
                    xerr=1.96 * row["se"],
                    fmt="o", color=color, capsize=3)

        ci = 1.96 * row["se"]
        label_x = row["beta"] + ci + 0.05  # 0.05 padding
        ax.text(label_x, y, labels[q],
                va="center", ha="left", fontsize=8)

    # y-ticks centered per service
    yticks = [ypos_map[s] + sum(x_offsets) / 4 for s in services]
    ax.set_yticks(yticks)
    ax.set_yticklabels(service_labels, fontsize=10)

    ax.set_xlim(-1.5, 1.5)
    ax.set_xticks([-1.0, -0.5, 0.0, 0.5, 1.0])
    ax.axvline(0, color="black", lw=0.8)

    # vertical gridlines
    for x in [-1.0, -0.5, 0.5, 1.0]:
        ax.axvline(x, color="lightgray", ls="--", lw=0.5)

    ax.set_xlabel("Group Disparity Coefficient", fontsize=10)
    ax.invert_yaxis()
    plt.tight_layout()
    fig.savefig(outfile, bbox_inches="tight")
    plt.close()

# ----------- generate all 4 plots -----------
for key, outfile in OUTFILES.items():
    _, group, measure = key.split("_")
    dfsub = df[(df["group"] == group) & (df["measure"] == measure)]
    plot_quartiles(dfsub, key, outfile)
