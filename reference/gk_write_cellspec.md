# Read and write cellspec directories

**\[experimental\]**

`gk_write_cellspec()` writes a `cellspec` object to the canonical
directory layout of the cellspec 1.0 specification: `cells.tsv.gz` (cell
columns then measurement columns), `cellspec.json` (spec version,
images, channels, dictionary, provenance), `MANIFEST.sha256` and `DONE`.
The directory is staged and renamed atomically. `gk_read_cellspec()`
reads it back and, with `verify = TRUE`, refuses a directory whose
manifest does not match.

These are interim implementations until cellspecR is released; they
write and read the same layout.

## Usage

``` r
gk_write_cellspec(x, dir, overwrite = FALSE)

gk_read_cellspec(dir, verify = TRUE)
```

## Arguments

- x:

  A `cellspec` object.

- dir:

  Directory path.

- overwrite:

  Replace an existing directory?

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
#> <cellspec> 1.0.0: 8,000 cells, 1 image, 12 markers, 20 features
#> Markers: "CD20", "CD21", "CD31", "CD3e", "CD45", "CD4", "CD68", "CD8", "FOXP3",
#> "Ki67", "PanCK", and "SMA"
out <- file.path(tempdir(), "copy-of-example")
gk_write_cellspec(x, out, overwrite = TRUE)
unlink(out, recursive = TRUE)
```
