# Example configuration for a generic tumour-immune panel

**\[experimental\]**

A study-neutral configuration used by examples, tests, vignettes and the
app, matching the data produced by
[`gk_simulate()`](https://github.com/CTTIR/gatekeepR/reference/gk_simulate.md).
It declares twelve markers:

- identity: `PanCK`, `CD45`, `CD3e`, `CD4`, `CD8`, `CD20`, `CD68`,
  `CD31`;

- conditional identity: `CD21` (optional; absent in the simulated
  slide);

- context: `SMA` (displayed only);

- state: `FOXP3` (nuclear, within CD4 T cells and tumour cells) and
  `Ki67` (nuclear, within tumour and immune cells), both with a
  nucleus/cytoplasm localisation rule.

The hierarchy contains a structure-review rule for PanCK-positive cells
(they stay "Unreviewed epithelial cells" until a tumour/benign
decision), a mixed-contact flag with policy `unresolved`, and two FOXP3
refinements. It is not a validated panel for any study.

## Usage

``` r
gk_example_config()
```

## Value

A
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md)
object.

## See also

Other example data:
[`gk_example_path()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_path.md),
[`gk_simulate()`](https://github.com/CTTIR/gatekeepR/reference/gk_simulate.md)

## Examples

``` r
cfg <- gk_example_config()
cfg$panel
#> <gk_panel> with 12 markers
#>  marker                 role transform cofactor threshold_method optional
#>   PanCK             identity     asinh        5          mixture    FALSE
#>    CD45             identity     asinh        5          mixture    FALSE
#>    CD3e             identity     asinh        5          mixture    FALSE
#>     CD4             identity     asinh        5          mixture    FALSE
#>     CD8             identity     asinh        5          mixture    FALSE
#>    CD20             identity     asinh        5          mixture    FALSE
#>    CD68             identity     asinh        5          mixture    FALSE
#>    CD31             identity     asinh        5          mixture    FALSE
#>    CD21 conditional_identity     asinh        5          mixture     TRUE
#>     SMA              context     asinh        5          mixture    FALSE
#>   FOXP3                state     asinh        5  parent_crossing    FALSE
#>    Ki67                state     asinh        5             tail    FALSE
#>             parents             localization
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>                                             
#>  CD4 T cells; Tumor nucleus/cytoplasm >= 1.5
#>       Tumor; Immune nucleus/cytoplasm >= 1.5
cfg$hierarchy
#> <gk_hierarchy> version "1.0.0": 9 rules, 1 flag
#>  rule_id              label          all_of any_of           none_of
#>     R010   Epithelial cells           PanCK                         
#>     R020        CD8 T cells CD45, CD3e, CD8                      CD4
#>     R030        CD4 T cells CD45, CD3e, CD4                      CD8
#>     R040      Other T cells      CD45, CD3e                         
#>     R050            B cells      CD45, CD20                     CD3e
#>     R060        Macrophages      CD45, CD68               CD3e, CD20
#>     R070 Other immune cells            CD45                         
#>     R080  Endothelial cells            CD31              CD45, PanCK
#>     R090     FDC-like cells            CD21        CD45, PanCK, CD20
#>  on_uncallable    review
#>   disable_rule structure
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#>   disable_rule          
#> Flag mixed_contact ("unresolved"): all_of "PanCK"; any_of "CD45" and "CD3e";
#> none_of
```
