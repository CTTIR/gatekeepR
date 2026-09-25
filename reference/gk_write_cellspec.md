# Read and write cellspec directories

**\[experimental\]**

`gk_write_cellspec()` writes a `cellspec` object to a selected directory
layout. The legacy layout uses `cells.tsv.gz` (cell columns then
measurement columns), `cellspec.json` (spec version, images, channels,
dictionary, provenance), `MANIFEST.sha256` and `DONE`. The directory is
staged and renamed atomically. `gk_read_cellspec()` reads it back and,
with `verify = TRUE`, refuses a directory whose manifest does not match.

The default `format = "legacy"` retains the original gatekeepR layout
for compatibility. It is not the canonical cellspecR disk schema and is
planned for retirement after migration is qualified. It does not
serialize adjacency or typed sidecar metadata. Select `"parquet"` or
`"tsv.gz"` explicitly for canonical storage owned by cellspecR. These
formats require cellspecR and a valid canonical object, including
declared positive pixel calibration; missing calibration is never
guessed. Canonical storage preserves adjacency, typed metadata and
additional columns.

Reading dispatches by the declared sidecar schema. Malformed or
unsupported canonical data never fall back to the legacy reader.
Canonical validation failures retain their `cellspec_error` condition
classes.

## Usage

``` r
gk_write_cellspec(
  x,
  dir,
  overwrite = FALSE,
  format = c("legacy", "parquet", "tsv.gz")
)

gk_read_cellspec(dir, verify = TRUE)
```

## Arguments

- x:

  A `cellspec` object.

- dir:

  Directory path.

- overwrite:

  Replace an existing directory?

- format:

  Output layout: `"legacy"` for compatibility, or canonical `"parquet"`
  or `"tsv.gz"` through cellspecR.

- verify:

  Check `DONE` and every manifest hash before reading?

## Value

`gk_write_cellspec()` returns `x` invisibly. `gk_read_cellspec()`
returns a `cellspec` object whose `provenance$manifest_sha256` holds the
SHA-256 of `MANIFEST.sha256`.

## See also

Other cell tables:
[`gk_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_cellspec.md)

## Examples

``` r
x <- gk_read_cellspec(gk_example_path("example-slide"))
x
#> <cellspec> spec 1.0.0
#>   cells     8,000 in 1 image (1 sample)
#>   features  20: 20 intensity
#>   markers   12: CD20, CD21, CD31, CD3e, CD45, CD4, CD68, CD8, FOXP3, Ki67, Pa...
#>   pixel     0.5 um/px
#>   adjacency none
#>   source    unknown (gatekeepR::gk_simulate 0.0.0.9000)
out <- file.path(tempdir(), "copy-of-example")
gk_write_cellspec(x, out, overwrite = TRUE)
unlink(out, recursive = TRUE)
```
