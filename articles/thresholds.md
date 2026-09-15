# Threshold methods and callability

Thresholds are estimates with evidence and status, not magic constants.
List the available methods with:

``` r

gk_threshold_methods()
#>                method                          role_allowed
#> 1              manual identity, conditional_identity, state
#> 2              valley identity, conditional_identity, state
#> 3                tail identity, conditional_identity, state
#> 4             mixture identity, conditional_identity, state
#> 5 population_crossing        identity, conditional_identity
#> 6     parent_crossing                                 state
#>                                                                                                                       arguments
#> 1                                                                                                            value = <required>
#> 2       min_relative_height = 0.03; grid_n = 4096; lower_quantile = 0.001; upper_quantile = 0.999; min_depth = 0.1; min_n = 100
#> 3                                peak_fraction = 0.1; grid_n = 4096; fallback_quantile = 0.99; min_tail_excess = 2; min_n = 100
#> 4                                                                   max_overlap = 0.2; max_iter = 500; tol = 1e-08; min_n = 100
#> 5 rule = max_crossing_q99; positive_z = 0.5; negative_z = 0; max_per_population = 1000; n_grid = 2048; negative_quantile = 0.99
#> 6                                                                                               reference = rest; n_grid = 2048
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        description
#> 1                                                                                                                                                                                                                                                                                                                                                                                                                                         Fixed cut from the configuration (`value`). Used as given; the status records that no estimate was made.
#> 2                                                                                                                                                                                                                                                                 Lowest density point between the two highest density modes (modes at least `min_relative_height` of the maximum; density on the `lower_quantile`-`upper_quantile` range). The valley must lie at least `min_depth` below the lower mode, otherwise the marker has no separation.
#> 3                                                                                                                                                                                                                                            First grid point after the main density peak with density at most `peak_fraction` of the peak height (fallback: `fallback_quantile`). The right tail above the cut must hold at least `min_tail_excess` times the mass of the mirrored left tail, so a symmetric unimodal distribution is not called.
#> 4                                                                                                                                                                                                                                                               Two-component Gaussian mixture fitted by EM; the cut is where the posterior probability of the upper component is 0.5. Not callable when one component fits better (BIC) or when the components overlap by more than `max_overlap` (misclassified share of the smaller component).
#> 5 Populations from gk_embed(). Populations whose mean score is more than `positive_z` SD above the population average form the positive pool, below `negative_z` the negative pool; up to `max_per_population` cells per population are sampled. Cut: first density crossing after the negative-pool peak (`rule = "crossing"`) or the larger of that crossing and the negative-pool quantile (`"max_crossing_q99"`). Requires an AUC of at least `min_auc`; the AUC describes the separation of internally selected pools and is not an accuracy.
#> 6                                                                                                                                                                                                                                                     State markers: positive pool = cells of the parent set, reference pool = `reference` ("rest": analysed cells outside the parent set, or a named parent set). Cut: first density crossing after the reference peak. Requires AUC >= `min_auc` and a parent median above the reference median.
```

The density valley, density tail, Gaussian mixture, embedding crossing,
and parent-specific crossing methods can be selected in a batch run. A
method may return an explicit insufficient-support or non-finite status;
callers should inspect status and callability before treating a marker
as usable.

``` r

thresholds <- gk_thresholds(
  corrected,
  method = "density_valley",
  marker = "marker_a"
)
gk_callability(thresholds)
gk_plot_thresholds(thresholds)
```

Manual corrections can replace an estimate through the review ledger.
The original estimate remains in the ledger, allowing the final result
to explain which cut was used and why.
