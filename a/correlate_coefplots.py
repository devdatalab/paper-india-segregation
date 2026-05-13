# ------------------------------------------
# coefplot_generator.py
# ------------------------------------------
import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import textwrap
from pathlib import Path
from set_paths import OUT, TMP

# ----------- easy‑to‑tweak output names -----------
OUTFILE = {
    "raw_joint": OUT / "coefplot_raw_joint.pdf",
    "raw_bivar": OUT / "coefplot_raw_bivar.pdf",
    "std_joint": OUT / "coefplot_std_joint.pdf",
    "std_bivar": OUT / "coefplot_std_bivar.pdf",
}

# ----------- read data -----------
csv_path = TMP / "seg_corr_estimates.csv"
if not os.path.exists(csv_path):
    raise FileNotFoundError(csv_path)

cols = ["beta", "se", "p", "n",
        "specification_name", "seg_measure", "group", "xvar"]
df = pd.read_csv(csv_path, header=None, names=cols)

# enforce numeric types for known numeric columns
numeric_cols = ["beta", "se", "p", "n"]
df[numeric_cols] = df[numeric_cols].apply(pd.to_numeric, errors="coerce")

# helpful label for colour / legend
df["combo"] = df["seg_measure"] + "_" + df["group"]

# consistent colour palette for the 4 combos
palette = {
    "dissim_sc":      "C0",
    "dissim_muslim":  "C1",
    "iso_sc":   "C0",
    "iso_muslim":"C1",
}

# set marker types
markers = {
    "dissim_sc":      "x",
    "iso_sc":         "o",
    "dissim_muslim":  "x",
    "iso_muslim":     "o",
}

# set legend labels
legend_labels = {
    "dissim_sc": "SC Dissimilarity",
    "iso_sc": "SC Isolation",
    "dissim_muslim": "Muslim Dissimilarity",
    "iso_muslim": "Muslim Isolation",
}

# set variable labels
# pretty labels for y-axis
xvar_labels = {
    "ln_city_pop": "Log City Population",
    "ln_growth": "Log City Growth 1991-2011",
    "muslim_pop_share": "Muslim Share",
    "sc_pop_share": "SC Share",
    "city_origin_year": "City Origin Year",
    "ln_cons_pc": "Log Per Capita Consumption",
    "p25": "Upward Mobility (p25)",
    "any_event": "Any Violent Event",
    "town_cons_gini": "Town Consumption Gini",
    "rural_land_gini": "Rural District Land Gini",
    "ln_city_pop_std": "Log City Population",
    "ln_growth_std": "Log City Growth 1991-2011",
    "muslim_pop_share_std": "Muslim Share",
    "sc_pop_share_std": "SC Share",
    "city_origin_year_std": "City Origin Year",
    "ln_cons_pc_std": "Log Per Capita Consumption",
    "p25_std": "Upward Mobility (p25)",
    "any_event_std": "Any Violent Event",
    "town_cons_gini_std": "Town Consumption Gini",
    "rural_land_gini_std": "Rural District Land Gini",
}

def make_plot(dsub, outfile):
    # preserve x-var order
    xvars = list(dict.fromkeys(dsub["xvar"]))
    combos = ["dissim_sc", "iso_sc", "dissim_muslim", "iso_muslim"]

    rows = []
    for i, xv in enumerate(xvars):
        base = i * (len(combos) + 1)  # +1 blank row as separator
        for j, comb in enumerate(combos):
            r = dsub[(dsub["xvar"] == xv) & (dsub["combo"] == comb)]
            if r.empty:
                continue
            rec = r.iloc[0].copy()
            rec["ypos"] = base + j
            rows.append(rec)
    plot_df = pd.DataFrame(rows)
    if plot_df.empty:
        return

    yh = len(xvars) * (len(combos) + 1)
    fig_height = max(4, 0.22 * yh)

    # widen canvas so legend fits to the right
    fig, ax = plt.subplots(figsize=(8.0, fig_height))
    ax.axvline(0, color="black", linewidth=0.8, zorder=1)

    plotted_labels = set()
    for _, r in plot_df.iterrows():
        ci = 1.96 * r["se"]
        combo = r["combo"]
        label = legend_labels.get(combo, combo) if combo not in plotted_labels else None
        ax.errorbar(
            r["beta"], r["ypos"],
            xerr=ci,
            fmt=markers.get(combo, "o"),
            ms=4, capsize=3,
            color=palette.get(combo, "C7"),
            label=label, zorder=2
        )
        if label:
            plotted_labels.add(combo)

    # separators
    for i in range(1, len(xvars)):
        ax.axhline(i * (len(combos) + 1) - 0.5, ls="--", lw=0.6, color="lightgray", zorder=0)

    # wrapped y labels
    wrapped_labels = {
        k: textwrap.fill(v, width=22, break_long_words=False, break_on_hyphens=False)
        for k, v in xvar_labels.items()
    }
    label_locs = []
    label_vals = []
    for i, xv in enumerate(xvars):
        ypos = i * (len(combos) + 1)
        label_locs.append(ypos)
        label_vals.append(wrapped_labels.get(xv, xv))

    ax.set_yticks(label_locs)
    ax.set_yticklabels(label_vals, fontsize=12)

    ax.invert_yaxis()
    ax.set_xlabel("Coefficient", fontsize=10)
    ax.set_xlim(-0.08, 0.08)
    ax.set_xticks(np.arange(-0.08, 0.08 + 0.001, 0.04))

    # vertical gridlines
    for x in np.arange(-0.08, 0.08, 0.04):
        ax.axvline(x, ls="--", lw=0.6, color="lightgray", zorder=0)

    # legend outside
    leg = ax.legend(title="", bbox_to_anchor=(1.02, 1), loc="upper left", borderaxespad=0)

    # --- margins: ensure y-tick labels are fully visible and leave room for legend ---
    fig.canvas.draw()  # need a renderer for text extents
    renderer = fig.canvas.get_renderer()

    # left margin based on widest y-ticklabel
    tick_extents = [t.get_window_extent(renderer) for t in ax.get_yticklabels() if t.get_text()]
    if tick_extents:
        max_w_in = max(ext.width for ext in tick_extents) / fig.dpi
    else:
        max_w_in = 0.0

    fig_w_in = fig.get_size_inches()[0]
    left_pad = max(0.14, (max_w_in + 0.10) / fig_w_in)  # +0.10in buffer

    # right margin based on legend width
    leg_w_in = leg.get_window_extent(renderer).width / fig.dpi
    fig.subplots_adjust(left=left_pad, right=1.0 - (leg_w_in + 0.20) / fig_w_in)

    # save without tight layout cropping
    fig.savefig(outfile)
    plt.close(fig)

# ----------- generate the four plots -----------
for spec, outfile in OUTFILE.items():
    make_plot(df[df["specification_name"] == spec], outfile)
