# Paths to bundled example data

**\[experimental\]**

Returns the path of a file or directory shipped in `inst/extdata`:

- `"example-slide"`: a cellspec directory from `gk_simulate(seed = 1)`;

- `"example-config.json"`:
  [`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md)
  written as JSON;

- `"example-review"`: a saved review working directory;

- `"example-export"`: a locked, verified export of that review.

## Usage

``` r
gk_example_path(
  name = c("example-slide", "example-config.json", "example-review", "example-export")
)
```

## Arguments

- name:

  Which example to locate.

## Value

A single path.

## See also

Other example data:
[`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md),
[`gk_simulate()`](https://github.com/CTTIR/gatekeepR/reference/gk_simulate.md)

## Examples

``` r
gk_example_path("example-config.json")
#> [1] "/home/runner/work/_temp/Library/gatekeepR/extdata/example-config.json"
```
