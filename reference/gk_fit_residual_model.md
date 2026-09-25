# Freeze and apply a fitted residual score space

**\[experimental\]**

Fits two numerical spaces from already transformed marker scores: an
identity common-score residual and a panel residual against the first
identity principal component. Robust centring uses medians and MAD with
constant 1.4826, with nonpositive MAD replaced by 1; standardized inputs
are clipped to `[-5, 5]`. Identity residuals are row-centred, then
centred and scaled per marker. Panel residuals subtract the row mean of
identity residuals before final per-marker centring and scaling. The
first principal component has a deterministic sign (largest absolute
loading positive).

At least 20 training rows are required. Panel regressions require 20
finite observations per marker; insufficient optional markers remain
unavailable. Final nonpositive or nonfinite standard deviations use 1.
Missing identity inputs and rank-deficient regression fits fail; they
are never imputed.

Application uses only stored parameters, so deleting, reordering or
changing another row cannot refit the scores of an unchanged row. The
exact ordered marker dictionary is required. Optional marker NA values
remain NA. The model contains no fitted per-cell matrix and can be saved
with [`base::saveRDS()`](https://rdrr.io/r/base/readRDS.html). Its
content hash binds parameters, dimensions, names, provenance and
bindings.

This is a numerical fit/apply contract, not raw-channel callability,
gate estimation or biological validation. The caller owns raw
measurement selection, any asinh cofactor, image-specific training scope
and downstream decisions. Constant raw channels may retain historical
residual artifacts; downstream callers must enforce raw support
independently. Reusing a fitted model on a different image or cohort
requires separate scientific qualification.

## Usage

``` r
gk_fit_residual_model(
  scores,
  identity_markers,
  provenance = list(),
  bindings = list()
)

gk_apply_residual_model(scores, model)
```

## Arguments

- scores:

  Numeric matrix of already transformed scores with unique, ordered
  marker column names. Identity columns must be finite. Other columns
  may contain NA, but neither NaN nor infinity is accepted.

- identity_markers:

  Unique ordered identity-marker names in `scores`.

- provenance:

  Named list recording the caller's training source, transformation and
  fit scope. Stored without interpretation.

- bindings:

  Named list of immutable configuration or threshold records to bind to
  this score space. No gate interpretation or transfer is performed.

- model:

  A `gk_frozen_residual_model` from `gk_fit_residual_model()`.

## Value

Fit returns a `gk_frozen_residual_model` with schema version,
parameters, source-score SHA-256, provenance, bindings and model
SHA-256. Apply returns a list with `identity` and `gate` matrices and
`model_sha256`.

## See also

Other corrections:
[`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md)

## Examples

``` r
scores <- cbind(A = seq_len(40), B = sin(seq_len(40)), C = cos(seq_len(40)))
model <- gk_fit_residual_model(scores, c("A", "B"),
  provenance = list(fit_scope = "synthetic input image", transform = "none"))
result <- gk_apply_residual_model(scores, model)
dim(result$gate)
#> [1] 40  3
```
