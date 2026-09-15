# gatekeepR: Reviewable Marker Gating and Phenotyping for Multiplexed Imaging

**\[experimental\]**

gatekeepR turns per-cell marker measurements from multiplexed tissue
images into cell types that a person has reviewed. It declares the
marker panel and the phenotype hierarchy as data, decides per image
which markers can be called at all, estimates thresholds with documented
methods, classifies cells with one classifier shared by batch code and
the review app, keeps reviewer decisions in append-only ledgers, and
locks a review into a verifiable export.

## Main functions

- Configuration:
  [`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
  [`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
  [`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
  [`gk_rule()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md),
  [`gk_flag()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md),
  [`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
  [`gk_refinement()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md),
  [`gk_override()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md),
  [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
  [`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
  [`gk_read_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
  [`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
  [`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
  [`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md).

- Cell tables:
  [`gk_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_cellspec.md),
  [`gk_read_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md),
  [`gk_write_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md).

- Preparation and callability:
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md),
  [`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md).

## See also

Useful links:

- <https://github.com/CTTIR/gatekeepR>

- Report bugs at <https://github.com/CTTIR/gatekeepR/issues>

## Author

**Maintainer**: R. Heller <raban.heller@uni-ulm.de>
([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]

Authors:

- R. Heller <raban.heller@uni-ulm.de>
  ([ORCID](https://orcid.org/0000-0001-8006-9742)) \[copyright holder\]
