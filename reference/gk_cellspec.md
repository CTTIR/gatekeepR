# Build a cell table in the cellspec 1.0 format

**\[experimental\]**

Assembles a `cellspec` object from a cell table and a measurement
matrix. This is an interim constructor that follows the cellspec 1.0
specification; once cellspecR is released, its readers produce the same
object from tool exports.

## Usage

``` r
gk_cellspec(
  cells,
  measurements,
  dictionary = NULL,
  images = NULL,
  channels = NULL,
  provenance = NULL
)
```

## Arguments

- cells:

  Data frame with one row per cell and at least the columns `cell_id`,
  `image_id`, `x` and `y` (centroids in um). `sample_id` defaults to
  `image_id`. Identifiers are coerced to character.

- measurements:

  Numeric matrix, cells x features, rows in the order of `cells`. Column
  names are feature IDs of the form
  `"<compartment>:<marker>:<statistic>"`, e.g. `"nucleus:FOXP3:mean"`.

- dictionary:

  Optional feature dictionary (columns `feature_id`, `kind`, `marker`,
  `compartment`, `statistic`, `unit`, `source_name`). Derived from the
  column names of `measurements` when `NULL`.

- images:

  Optional image table (`image_id`, `sample_id`, `pixel_size`). Derived
  from `cells` when `NULL`.

- channels:

  Optional channel table (`image_id`, `channel_index`, `channel_name`,
  `marker`). Derived from the dictionary when `NULL`.

- provenance:

  Optional list describing the origin of the data.

## Value

An object of class `cellspec`: a list with `spec_version`, `cells`,
`measurements`, `dictionary`, `images`, `channels`, `provenance` and
`adjacency` (`NULL`).

## See also

Other cell tables:
[`gk_write_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md)

## Examples

``` r
cells <- data.frame(
  cell_id = c("c1", "c2", "c3"), image_id = "img1",
  x = c(10, 20, 30), y = c(5, 5, 5)
)
m <- cbind("cell:CD3e:mean" = c(1, 50, 3), "nucleus:FOXP3:mean" = c(0, 12, 1))
x <- gk_cellspec(cells, m)
x
#> <cellspec> 1.0.0: 3 cells, 1 image, 2 markers, 2 features
#> Markers: "CD3e" and "FOXP3"
```
