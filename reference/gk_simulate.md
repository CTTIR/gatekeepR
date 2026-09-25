# Simulate a multiplexed tissue slide

**\[experimental\]**

Generates a synthetic slide matching
[`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md),
with known ground truth, for examples, tests and method checks. The
slide contains:

- lineage populations (epithelial nests, CD8 and CD4 T cells including
  FOXP3-positive regulatory cells, B cells, macrophages, other immune
  cells, endothelial and stromal cells);

- spatial epithelial nests (tumour-like and small benign-like ducts) and
  scattered single epithelial cells;

- epithelial-immune contact objects co-positive for PanCK and CD45;

- a rare CD4/CD8 double-positive T-cell population;

- nuclear state markers (FOXP3, Ki67) with nuclear and cytoplasmic
  measurements, including cytoplasmic FOXP3 artefacts that fail the
  localisation rule;

- a shared per-cell brightness component;

- an absent channel (all zeros) and a shuffled marker.

Intensities are raw arbitrary units rounded to two decimals, as tool
exports typically are. Ground truth is stored in the extra cell columns
`sim_population` and `sim_structure`.

## Usage

``` r
gk_simulate(
  n_cells = 8000L,
  markers = NULL,
  absent = "CD21",
  shuffled = "SMA",
  rare_fraction = 0.003,
  separation = 1,
  image_id = "sim-01",
  seed = 1L
)
```

## Arguments

- n_cells:

  Number of cells.

- markers:

  `NULL` for all twelve example markers, or a subset.

- absent:

  Markers whose channel is entirely zero.

- shuffled:

  Markers whose values are permuted across cells, destroying any
  relation to cell identity.

- rare_fraction:

  Fraction of cells in the rare double-positive population.

- separation:

  Multiplier of the positive-population signal on the log scale; values
  below 1 make gating harder.

- image_id:

  Image identifier.

- seed:

  Random seed. The caller's random number state is restored.

## Value

A `cellspec` object (see
[`gk_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_cellspec.md)).

## See also

Other example data:
[`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md),
[`gk_example_path()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_path.md)

## Examples

``` r
x <- gk_simulate(n_cells = 2000, seed = 3)
x
#> <cellspec> spec 1.0.0
#>   cells     2,000 in 1 image (1 sample)
#>   features  20: 20 intensity
#>   markers   12: CD20, CD21, CD31, CD3e, CD45, CD4, CD68, CD8, FOXP3, Ki67, Pa...
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    unknown (gatekeepR::gk_simulate 1.0.0)
table(x$cells$sim_population)
#> 
#>       b_cell        cd4_t        cd8_t      contact  endothelial   epithelial 
#>          120          200          160           20          100          560 
#>   macrophage other_immune    rare_dp_t      stromal 
#>          160           80            6          594 
```
