# Paths to bundled example data

**\[experimental\]**

Returns the path of a file or directory shipped in `inst/extdata`:

- `"example-slide"`: a cellspec directory from `gk_simulate(seed = 1)`;

- `"example-config.json"`: [`gk_example_config()`](gk_example_config.md)
  written as JSON.

Review checkpoints and exports are created by the reviewer rather than
bundled as pre-reviewed decisions. Use [`gk_review()`](gk_review.md) and
[`gk_save_review()`](gk_save_review.md) to create a checkpoint, or
[`gk_lock()`](gk_lock.md) and [`gk_export()`](gk_export.md) for an
export.

## Usage

``` r
gk_example_path(name = c("example-slide", "example-config.json"))
```

## Arguments

- name:

  Which example to locate.

## Value

A single path.

## See also

Other example data: [`gk_example_config()`](gk_example_config.md),
[`gk_simulate()`](gk_simulate.md)

## Examples

``` r
gk_example_path("example-config.json")
#> [1] "/home/runner/work/_temp/Library/gatekeepR/extdata/example-config.json"
```
