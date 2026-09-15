# Callability of markers per image

**\[experimental\]**

Reports, for every image and marker, whether the marker can be called
and why not. Checks on the raw selected signal run in
[`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
before any correction or threshold; threshold estimation adds its own
outcomes.

|                              |                                            |
|------------------------------|--------------------------------------------|
| Status                       | Meaning                                    |
| `NOT_CALLABLE_ABSENT`        | constant or near-constant signal           |
| `NOT_CALLABLE_UNAVAILABLE`   | too many cells without usable signal       |
| `NOT_CALLABLE_UNDERPOWERED`  | too few cells, or too few in a pool        |
| `NOT_CALLABLE_NO_POPULATION` | the method finds no positive population    |
| `NOT_CALLABLE_NO_SEPARATION` | positive and negative are not separated    |
| `PENDING_THRESHOLD`          | supported; threshold not yet estimated     |
| `NOT_GATED`                  | context marker with usable signal          |
| `CALLABLE`                   | finite threshold, all checks passed        |
| `MANUAL`                     | cut set by a reviewer or the configuration |

A marker that is not callable never produces positive calls, and rules
requiring it are disabled and listed.

## Usage

``` r
gk_callability(x, ...)
```

## Arguments

- x:

  A `gk_prepared` object, or a later result carrying callability
  (thresholds, classification, review).

- ...:

  Unused.

## Value

A data frame with `image_id`, `marker`, `role`, `status`, `details` and
support statistics (`n_cells`, `n_available`, `fraction_unavailable`,
`sd`, `mad`, `fraction_mode`, `q01`, `q50`, `q99`).

## See also

Other preparation:
[`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
cb <- gk_callability(prep)
cb[cb$status != "PENDING_THRESHOLD", c("image_id", "marker", "status", "details")]
#>      image_id marker              status
#> 9  example-01   CD21 NOT_CALLABLE_ABSENT
#> 10 example-01    SMA           NOT_GATED
#>                                            details
#> 9                 Signal is constant across cells.
#> 10 Context marker: displayed, never used in rules.
```
