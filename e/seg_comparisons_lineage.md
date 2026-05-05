# `seg_comparisons_*` lineage

## Bottom line

`a/graph_seg_comparisons.do` does not create `seg_comparisons_d.csv`, `seg_comparisons_i_raw.csv`, or `seg_comparisons_i_rescaled.csv`. In the current replicated repo, those files are treated as frozen raw inputs, and the prior download/Google Sheet creation logic was intentionally removed.

## What `a/graph_seg_comparisons.do` does

Active usage is in [a/graph_seg_comparisons.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/a/graph_seg_comparisons.do:3):

- Lines 3-12 import `seg_comparisons_d.csv`, keep `include == 1`, rename `neighborhoodblocksize -> mean_pop` and `value -> dissim`, and save `$tmp/seg_compare_dissim.dta`.
- Lines 18-27 import `seg_comparisons_i_raw.csv`, keep `include == 1`, rename `neighborhoodblocksize -> mean_pop` and `value -> iso`, and save `$tmp/seg_compare_iso.dta`.
- Lines 34-89 open the India-side dataset `$tmp/dissim_iso_block_groups.dta`, reshape it, append the external comparison datasets, and export the two Figure 2 graphs.

Important detail: the active script reads `seg_comparisons_i_raw.csv`, not `seg_comparisons_i_rescaled.csv`. I found no active code reference to `seg_comparisons_i_rescaled.csv` in this repo beyond the raw-dataset manifest.

## Where the India-side comparison series comes from

The master dataset for the India side of Figure 2 is `$tmp/dissim_iso_block_groups.dta`, created by [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:25).

That script does the following:

- Opens pooled neighborhood/block-group files such as `$tmp/secc/secc_ec_blockdata_urban_pooled_*.dta` and neighborhood-key files such as `$tmp/secc/block_to_nbd/secc_urban_block_to_nbd_*_key.dta` ([b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:42), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:57)).
- Loops over urban block-group aggregation thresholds from `0` to `10000` ([b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:32), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:35)).
- Reconstructs average neighborhood population using neighborhood block counts and the assumed mean urban EB size of `530` ([b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:38), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:63)).
- Drops blocks with excessive missing SC classification, computes city-level dissimilarity and isolation for SC and Muslim populations, and then takes cross-city weighted means ([b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:77), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:109), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:126)).
- Writes those summaries to `$tmp/block_group_seg.csv` and then saves the Stata version as `$tmp/dissim_iso_block_groups.dta` ([b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:145), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:152), [b/gen_seg_block_groups.do](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/b/gen_seg_block_groups.do:155)).

The repo manifest also records this producer/consumer relationship explicitly:

- `TMP/dissim_iso_block_groups.dta` is produced by `b/gen_seg_block_groups.do` and consumed by `a/graph_seg_comparisons.do` ([replication_notes/intermediate_datasets.csv](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/replication_notes/intermediate_datasets.csv:18)).

## Where the external comparison CSVs come from

Current repo evidence says:

- The three `seg_comparisons_*.csv` files are classified as raw inputs in the replication manifest ([replication_notes/raw_datasets.csv](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/replication_notes/raw_datasets.csv:32)).
- The replication notes state that `seg_comparisons_*.csv` are treated as raw inputs and that the download/Google Sheet lines were removed from `a/graph_seg_comparisons.do` ([replication_notes/replication_notes.txt](/dartfs-hpc/rc/home/m/f00858m/ddl/paper-india-segregation/replication_notes/replication_notes.txt:87)).

So, in this repo, there is no remaining tracked producer script for:

- `seg_comparisons_d.csv`
- `seg_comparisons_i_raw.csv`
- `seg_comparisons_i_rescaled.csv`

The strongest provenance clue left is the old source path recorded in the manifest:

- `/Users/f0018fb/Dropbox/tmp/stata/seg_comparisons_d.csv`
- `/Users/f0018fb/Dropbox/tmp/stata/seg_comparisons_i_raw.csv`
- `/Users/f0018fb/Dropbox/tmp/stata/seg_comparisons_i_rescaled.csv`

That suggests they were assembled outside the current replication repo, likely from a local spreadsheet/export workflow. The comment at line 14 of `a/graph_seg_comparisons.do` ("Download seg comparisons from the google sheet and save to a dataset") is now only a stale hint, not active code.

## Answer to the specific questions

Which script forms these CSVs?

- No active script in this repo forms them.
- Historically, there appears to have been Google Sheet download logic in `a/graph_seg_comparisons.do`, but it was removed during replication cleanup.

What is that script doing?

- The current `a/graph_seg_comparisons.do` only imports the CSVs, filters and renames columns, appends them to India segregation summaries, and plots Figure 2.

What is the master dataset from which these datasets originate?

- For the India comparison line series: `$tmp/dissim_iso_block_groups.dta`, produced by `b/gen_seg_block_groups.do`.
- For the external `seg_comparisons_*.csv` files: the repo does not preserve a master upstream dataset or producer script. They are frozen raw comparison inputs in the current build.
