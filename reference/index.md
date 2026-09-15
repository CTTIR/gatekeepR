# Package index

## Configuration

- [`gk_app()`](https://github.com/CTTIR/gatekeepR/reference/gk_app.md) :
  Launch the gatekeepR review application
- [`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md)
  **\[experimental\]** : Callability of markers per image
- [`gk_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_cellspec.md)
  **\[experimental\]** : Build a cell table in the cellspec 1.0 format
- [`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md)
  **\[experimental\]** : Classify cells with the configured ordered
  hierarchy
- [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md)
  **\[experimental\]** : Assemble a gating configuration
- [`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md)
  **\[experimental\]** : Canonical hash of a configuration
- [`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md)
  **\[experimental\]** : Correct prepared marker scores
- [`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md)
  : Decide one structure or bounding box
- [`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md)
  : Set a cell disposition
- [`gk_embed()`](https://github.com/CTTIR/gatekeepR/reference/gk_embed.md)
  **\[experimental\]** : Compute a reproducible marker embedding and
  density populations
- [`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md)
  **\[experimental\]** : Example configuration for a generic
  tumour-immune panel
- [`gk_example_path()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_path.md)
  **\[experimental\]** : Paths to bundled example data
- [`gk_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_export.md)
  : Write a locked review export
- [`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md)
  **\[experimental\]** : Declare a phenotype hierarchy
- [`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md)
  : Import identity-marker cuts without replacing other ledgers
- [`gk_ledgers()`](https://github.com/CTTIR/gatekeepR/reference/gk_ledgers.md)
  : Return the four review ledgers
- [`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md)
  : Load a review checkpoint and acquire its single-writer lock
- [`gk_lock()`](https://github.com/CTTIR/gatekeepR/reference/gk_lock.md)
  : Lock a review into an immutable snapshot
- [`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md)
  **\[experimental\]** : Callability rules for a marker
- [`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md)
  **\[experimental\]** : Declare a marker panel
- [`gk_plot_density()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_density.md)
  : Plot a threshold density and its evidence pools
- [`gk_plot_dotplot()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_dotplot.md)
  : Plot marker means by classified cell type
- [`gk_plot_embedding()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_embedding.md)
  : Plot an embedding coloured by population or classification
- [`gk_plot_map()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_map.md)
  : Plot cell centroids on an image map
- [`gk_plot_overview()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_overview.md)
  : Make a compact overview
- [`gk_plot_states()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_states.md)
  : Plot state calls for one image
- [`gk_plot_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_thresholds.md)
  : Plot thresholds for one image
- [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  **\[experimental\]** : Prepare marker signals for gating
- [`gk_read_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_read_export.md)
  : Read a verified export
- [`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md)
  : Replace selected review ledgers from a saved checkpoint
- [`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md)
  : Replay all effective review decisions
- [`gk_revert_last()`](https://github.com/CTTIR/gatekeepR/reference/gk_revert_last.md)
  : Append an inverse of the most recent review action
- [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md)
  **\[experimental\]** : Create an editable review state
- [`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md)
  : Save a review checkpoint atomically
- [`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md)
  : Set an identity or state threshold in the review ledger
- [`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
  : Enable, disable or set a parent-specific state call
- [`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md)
  **\[experimental\]** : Declare which measurement represents each
  marker
- [`gk_simulate()`](https://github.com/CTTIR/gatekeepR/reference/gk_simulate.md)
  **\[experimental\]** : Simulate a multiplexed tissue slide
- [`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md)
  **\[experimental\]** : Call state markers within configured parent
  sets
- [`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)
  **\[experimental\]** : Find epithelial structures for review
- [`gk_threshold_methods()`](https://github.com/CTTIR/gatekeepR/reference/gk_threshold_methods.md)
  **\[experimental\]** : Threshold methods available in gatekeepR
- [`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)
  **\[experimental\]** : Estimate per-image marker thresholds
- [`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md)
  **\[experimental\]** : Validate a gating configuration
- [`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md)
  : Verify manifest integrity, replay and reconciliation invariants
- [`gk_write_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md)
  [`gk_read_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md)
  **\[experimental\]** : Read and write cellspec directories
- [`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md)
  [`gk_read_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md)
  **\[experimental\]** : Read and write configuration files
- [`gk_rule()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  [`gk_flag()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  [`gk_refinement()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  [`gk_override()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  **\[experimental\]** : Hierarchy rules, flags, refinements and
  overrides
