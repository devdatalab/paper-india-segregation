#!/usr/bin/env python

"""
Generate Appendix Figure A.3 segregation heatmaps.

Inputs:
- TMP/secc/segregation_citydata_urban_200.dta
- TMP/secc/segregation_citydata_rural_200.dta
- RAW/gis/pc11-{district,subdistrict,state}.{shp,shx,dbf,prj}

Outputs:
- OUT/india_segregation_muslim_urban.png
- OUT/india_segregation_sc_urban.png
- OUT/india_segregation_muslim_rural.png
- OUT/india_segregation_sc_rural.png
"""

from __future__ import annotations

from pathlib import Path

import geopandas as gpd
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from set_paths import OUT, RAW, TMP

# Keep rendering simple/reliable in replication environments.
mpl.rcParams["figure.dpi"] = 100
mpl.rcParams["savefig.dpi"] = 150
mpl.rcParams["text.usetex"] = False

OUTDIR = OUT
CITYDATA_URBAN_DTA = TMP / "secc" / "segregation_citydata_urban_200.dta"
CITYDATA_RURAL_DTA = TMP / "secc" / "segregation_citydata_rural_200.dta"
GIS_ROOT = RAW / "gis"

DISTRICT_SHP = GIS_ROOT / "pc11-district.shp"
SUBDISTRICT_SHP = GIS_ROOT / "pc11-subdistrict.shp"
STATE_SHP = GIS_ROOT / "pc11-state.shp"

REQUIRED_FILES = [
    CITYDATA_URBAN_DTA,
    CITYDATA_RURAL_DTA,
    DISTRICT_SHP,
    SUBDISTRICT_SHP,
    STATE_SHP,
]


def _check_inputs() -> None:
    missing = [path for path in REQUIRED_FILES if not path.exists()]
    if missing:
        msg = "\n".join(f"- {path}" for path in missing)
        raise FileNotFoundError(f"Missing required input files:\n{msg}")


def _weighted_mean(group: pd.DataFrame, value_col: str, weight_col: str) -> float:
    values = pd.to_numeric(group[value_col], errors="coerce")
    weights = pd.to_numeric(group[weight_col], errors="coerce")
    valid = values.notna() & weights.notna() & (weights > 0)
    if not valid.any():
        return np.nan
    return float(np.average(values[valid], weights=weights[valid]))


def _aggregate_dissim(df: pd.DataFrame, key_cols: list[str]) -> pd.DataFrame:
    rows = []
    for keys, group in df.groupby(key_cols, dropna=False):
        if not isinstance(keys, tuple):
            keys = (keys,)
        row = dict(zip(key_cols, keys))
        for col in ["city_dissim_muslim", "city_dissim_sc"]:
            if "city_pop" in group.columns:
                row[col] = _weighted_mean(group, col, "city_pop")
            else:
                row[col] = float(pd.to_numeric(group[col], errors="coerce").mean())
        rows.append(row)
    return pd.DataFrame(rows)


def _prep_urban_data() -> pd.DataFrame:
    df = pd.read_stata(CITYDATA_URBAN_DTA)
    df = df.dropna(
        subset=[
            "sc_share",
            "muslim_share",
            "city_dissim_muslim",
            "city_dissim_sc",
            "pc11_district_id",
        ]
    )
    df = df[(df["sc_share"] != 0) & (df["muslim_share"] != 0)]
    return _aggregate_dissim(df, ["pc11_state_id", "pc11_district_id"])


def _prep_rural_data() -> pd.DataFrame:
    df = pd.read_stata(CITYDATA_RURAL_DTA)
    df = df.dropna(
        subset=[
            "sc_share",
            "muslim_share",
            "city_dissim_muslim",
            "city_dissim_sc",
            "pc11_subdistrict_id",
        ]
    )
    df = df[(df["sc_share"] != 0) & (df["muslim_share"] != 0)]
    return _aggregate_dissim(
        df, ["pc11_state_id", "pc11_district_id", "pc11_subdistrict_id"]
    )


def _join_geometry(
    df: pd.DataFrame, shp_path: Path, left_on: list[str], right_on: list[str]
) -> gpd.GeoDataFrame:
    gdf = gpd.read_file(shp_path)
    merged = gdf.merge(df, left_on=left_on, right_on=right_on, how="left")
    return gpd.GeoDataFrame(merged, geometry="geometry")


def _value_range(series: pd.Series) -> tuple[float, float]:
    values = pd.to_numeric(series, errors="coerce").to_numpy()
    values = values[np.isfinite(values)]
    if values.size == 0:
        return 0.0, 1.0
    vmin = float(np.nanmin(values))
    vmax = float(np.nanmax(values))
    if vmin == vmax:
        vmax = vmin + 1e-6
    return vmin, vmax


def _plot_map(
    gdf: gpd.GeoDataFrame,
    states: gpd.GeoDataFrame,
    value_col: str,
    cmap: str,
    cbar_label: str,
    output_path: Path,
) -> None:
    fig, ax = plt.subplots(figsize=(10, 10))
    gdf.plot(
        ax=ax,
        column=value_col,
        cmap=cmap,
        linewidth=0,
        missing_kwds={"color": "whitesmoke"},
    )
    states.boundary.plot(ax=ax, color="black", linewidth=0.4, alpha=0.3)
    ax.set_axis_off()

    vmin, vmax = _value_range(gdf[value_col])
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(vmin=vmin, vmax=vmax))
    sm.set_array([])
    cbar = fig.colorbar(sm, ax=ax, fraction=0.03, pad=0.01)
    cbar.ax.set_ylabel(cbar_label, rotation=270, labelpad=16)

    fig.savefig(output_path, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {output_path}")


def main() -> None:
    OUTDIR.mkdir(parents=True, exist_ok=True)
    _check_inputs()

    states = gpd.read_file(STATE_SHP)

    urban = _prep_urban_data()
    urban_map = _join_geometry(
        urban,
        DISTRICT_SHP,
        left_on=["pc11_s_id", "pc11_d_id"],
        right_on=["pc11_state_id", "pc11_district_id"],
    )
    _plot_map(
        urban_map,
        states,
        value_col="city_dissim_muslim",
        cmap="Reds",
        cbar_label="City Dissimilarity Index (Muslim)",
        output_path=OUTDIR / "india_segregation_muslim_urban.png",
    )
    _plot_map(
        urban_map,
        states,
        value_col="city_dissim_sc",
        cmap="Blues",
        cbar_label="City Dissimilarity Index (SC)",
        output_path=OUTDIR / "india_segregation_sc_urban.png",
    )

    rural = _prep_rural_data()
    rural_map = _join_geometry(
        rural,
        SUBDISTRICT_SHP,
        left_on=["pc11_s_id", "pc11_d_id", "pc11_sd_id"],
        right_on=["pc11_state_id", "pc11_district_id", "pc11_subdistrict_id"],
    )
    _plot_map(
        rural_map,
        states,
        value_col="city_dissim_muslim",
        cmap="Reds",
        cbar_label="Subdistrict Dissimilarity Index (Muslim)",
        output_path=OUTDIR / "india_segregation_muslim_rural.png",
    )
    _plot_map(
        rural_map,
        states,
        value_col="city_dissim_sc",
        cmap="Blues",
        cbar_label="Subdistrict Dissimilarity Index (SC)",
        output_path=OUTDIR / "india_segregation_sc_rural.png",
    )


if __name__ == "__main__":
    main()
